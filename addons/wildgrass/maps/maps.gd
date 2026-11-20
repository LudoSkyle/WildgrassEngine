## Loads maps and moves the traveller between and within them.
extends RefCounted

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")
const ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")
const ScreenRegistry := preload("res://addons/wildgrass/core/screens/screen_registry.gd")

## The traveller was put on the new map, facing `direction`. `point` is the
## door or spawn point it arrived at, or null.
signal traveller_arrived(direction: Vector2i, point: Node2D)
## The zone changed with the map.
signal zone_changed(old_zone: StringName, new_zone: StringName)
## A warp or reload is over.
signal map_changed(map: WgMap)

## The map on screen, or null.
var current: WgMap
## Id of the map on screen.
var current_id: StringName = &""
## What moves from map to map: any Node2D, set by the game.
var traveller: Node2D
## Parent of the map on screen.
var host: Node
## True while a warp or reload runs; new requests are ignored.
var is_changing := false

var _paths: Paths
var _log: Log
var _config: ConfigRegistry
var _hooks: Hooks
var _screens: ScreenRegistry
var _zone: StringName = &""


func _init(paths: Paths, logger: Log, config: ConfigRegistry, hooks: Hooks, screens: ScreenRegistry, map_host: Node) -> void:
	_paths = paths
	_log = logger
	_config = config
	_hooks = hooks
	_screens = screens
	host = map_host


## Moves the traveller to `point` of map `map_id` (empty: this map), plus
## `offset` tiles, facing `direction` if not zero. Returns false if refused.
func warp(map_id: StringName, point: StringName, transition := &"fade", offset := Vector2i.ZERO, direction := Vector2i.ZERO) -> bool:
	if is_changing:
		return false
	var target_id := current_id if map_id.is_empty() else map_id
	var same_map := current != null and target_id == current_id
	var next: WgMap = null
	if not same_map:
		next = _instantiate(target_id)
		if next == null:
			return false
	is_changing = true
	var screen := await _cover(transition)
	if not same_map:
		_replace(next, target_id)
	var arrival := _arrival(current, point)
	_place(arrival["position"] + Vector2(offset * _tile_size()))
	traveller_arrived.emit(direction if direction != Vector2i.ZERO else arrival["direction"], arrival["point"])
	_announce_zone(next)
	await _uncover(screen)
	is_changing = false
	map_changed.emit(current)
	return true


## Warps through `door`, by the rules of the point it leads to.
func use(door: WgDoor) -> bool:
	return await warp(door.target_map, door.target_door, door.transition)


## Warps with no transition: new game, loaded game.
func go_to(map_id: StringName, point: StringName) -> bool:
	return await warp(map_id, point, &"none")


## Loads the current map again; the traveller keeps its place.
func reload(transition := &"fade") -> bool:
	if is_changing or current == null:
		return false
	var next := _instantiate(current_id)
	if next == null:
		return false
	is_changing = true
	var screen := await _cover(transition)
	var position := traveller.global_position if traveller != null else Vector2.ZERO
	_replace(next, current_id)
	_place(position)
	await _uncover(screen)
	is_changing = false
	map_changed.emit(current)
	return true


func _instantiate(map_id: StringName) -> WgMap:
	var path := _paths.resolve(&"maps", "%s.tscn" % map_id)
	if not ResourceLoader.exists(path):
		_log.error(&"maps", "unknown map '%s' (no %s)" % [map_id, path])
		return null
	var node := (load(path) as PackedScene).instantiate()
	if not node is WgMap:
		_log.error(&"maps", "%s: the root is not a WgMap" % path)
		node.free()
		return null
	return node


## Frees the current map (the traveller survives) and shows `next`.
func _replace(next: WgMap, next_id: StringName) -> void:
	if traveller != null and traveller.get_parent() != null:
		traveller.get_parent().remove_child(traveller)
	if current != null:
		_hooks.run(&"map_leaving", [current])
		current.get_parent().remove_child(current)
		current.free()
	current = next
	current_id = next_id
	host.add_child(next)
	_hooks.run(&"map_loaded", [next])


## {"position": global position, "direction": facing, "point": node or null}
func _arrival(map: WgMap, point_name: StringName) -> Dictionary:
	var point := map.find_point(point_name)
	if point == null:
		_log.warn(&"maps", "%s: no door or spawn point '%s'" % [current_id, point_name])
		point = map.first_spawn_point()
	if point == null:
		return {"position": map.global_position, "direction": Vector2i.DOWN, "point": null}
	if point is WgDoor:
		var door := point as WgDoor
		if door.kind == WgDoor.Kind.EXIT:
			return {"position": door.global_position, "direction": -door.direction, "point": door}
		var way := door.direction
		if way == Vector2i.ZERO:
			_log.warn(&"maps", "%s: contact door '%s' has no direction; using down" % [current_id, door.name])
			way = Vector2i.DOWN
		return {"position": door.global_position + Vector2(way * _tile_size()), "direction": way, "point": door}
	return {"position": point.global_position, "direction": (point as WgSpawnPoint).direction, "point": point}


func _place(global_position: Vector2) -> void:
	if traveller == null:
		return
	if traveller.get_parent() != current.entities_node():
		if traveller.get_parent() != null:
			traveller.get_parent().remove_child(traveller)
		current.entities_node().add_child(traveller)
	traveller.global_position = global_position


func _announce_zone(next: WgMap) -> void:
	if next == null or next.zone == _zone:
		return
	var old := _zone
	_zone = next.zone
	zone_changed.emit(old, _zone)


func _cover(transition: StringName) -> WgTransition:
	var screen := _screens.open(StringName("transition_" + transition), {"seconds": _fade_seconds()}) as WgTransition
	if screen != null:
		await screen.cover()
	return screen


func _uncover(screen: WgTransition) -> void:
	if screen == null:
		return
	await screen.uncover()
	screen.close()


func _tile_size() -> int:
	return (_config.get_config(&"map") as WgMapConfig).tile_size


func _fade_seconds() -> float:
	return (_config.get_config(&"map") as WgMapConfig).fade_seconds
