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
## A warp, reload or crossing is over.
signal map_changed(map: WgMap)
## Every neighbour of the current map is shown, after a crossing.
signal neighbours_loaded

## The map on screen, or null.
var current: WgMap
## Id of the map on screen.
var current_id: StringName = &""
## Maps shown against the sides of the current one.
var neighbours: Array[WgMap] = []
## What moves from map to map: any Node2D, set by the game.
var traveller: Node2D
## Parent of the maps on screen.
var host: Node
## True while a warp or reload runs; new requests are ignored.
var is_changing := false
## True while neighbours load after a crossing.
var is_loading_neighbours := false
## True while `map_changed` announces a crossing, not a warp or a reload.
var is_crossing := false

var _paths: Paths
var _log: Log
var _config: ConfigRegistry
var _hooks: Hooks
var _screens: ScreenRegistry
var _zone: StringName = &""
var _neighbour_ids: Dictionary[WgMap, StringName] = {}
## Every map built and not freed yet -> its id.
var _ids: Dictionary[WgMap, StringName] = {}
## Bumped whenever the maps on screen are replaced: older loads are dropped.
var _generation := 0
## Background loads asked for and not collected yet: path -> requests.
var _requested: Dictionary[String, int] = {}


func _init(paths: Paths, logger: Log, config: ConfigRegistry, hooks: Hooks, screens: ScreenRegistry, map_host: Node) -> void:
	_paths = paths
	_log = logger
	_config = config
	_hooks = hooks
	_screens = screens
	host = map_host


## Dropped mid-load, the loading coroutine never resumes: collect what it
## waited for, or Godot keeps it until the game quits. No method of this
## object can run here.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for path: String in _requested:
			for _request in _requested[path]:
				ResourceLoader.load_threaded_get(path)


## Moves the traveller to `point` of map `map_id` (empty: this map), plus
## `offset` tiles, facing `direction` if not zero. An empty `point` is the
## map's first spawn point. Returns false if refused.
func warp(map_id: StringName, point: StringName, transition := &"fade", offset := Vector2i.ZERO, direction := Vector2i.ZERO) -> bool:
	return await _warp(map_id, point, transition, offset, direction, false)


## Moves the traveller to `cell` of map `map_id`, with no transition, facing
## `direction` (down if zero): a loaded game.
func go_to_cell(map_id: StringName, cell: Vector2i, direction := Vector2i.ZERO) -> bool:
	return await _warp(map_id, &"", &"none", cell, direction, true)


## True if map `map_id` has a scene.
func has_map(map_id: StringName) -> bool:
	return not map_id.is_empty() and ResourceLoader.exists(_map_path(map_id))


func _warp(map_id: StringName, point: StringName, transition: StringName, offset: Vector2i, direction: Vector2i, at_cell: bool) -> bool:
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
		_replace(next, target_id, Vector2.ZERO)
	var half := Vector2(_tile_size(), _tile_size()) * 0.5
	var arrival := {"position": current.global_position + half, "direction": Vector2i.DOWN, "point": null} if at_cell else _arrival(current, point)
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


## Loads the current map and its neighbours again, in place; the traveller
## keeps its place.
func reload(transition := &"fade") -> bool:
	if is_changing or current == null:
		return false
	var next := _instantiate(current_id)
	if next == null:
		return false
	is_changing = true
	var screen := await _cover(transition)
	var position := traveller.global_position if traveller != null else Vector2.ZERO
	_replace(next, current_id, current.position)
	_place(position)
	await _uncover(screen)
	is_changing = false
	map_changed.emit(current)
	return true


## If the traveller stands in a neighbour, makes it the current map, with no
## transition. Feature 3 calls it when the traveller lands on a tile.
func cross() -> bool:
	if is_changing or traveller == null or current == null:
		return false
	var at := traveller.global_position
	var next := map_at(at)
	if next == null or next == current:
		return false
	var unused: Dictionary[WgMap, StringName] = _neighbour_ids.duplicate()
	unused.erase(next)
	unused[current] = current_id
	current = next
	current_id = _neighbour_ids[next]
	neighbours.clear()
	_neighbour_ids.clear()
	var missing: Array[WgMapLink] = []
	for link: WgMapLink in _valid_links(current, current_id):
		var shown: WgMap = unused.find_key(link.map)
		if shown == null:
			missing.append(link)
			continue
		unused.erase(shown)
		neighbours.append(shown)
		_neighbour_ids[shown] = link.map
	_place(at)
	_announce_zone(next)
	is_crossing = true
	map_changed.emit(current)
	is_crossing = false
	for map: WgMap in unused.keys():
		_free_map(map)
	_load_neighbours(missing)
	return true


## The map shown at `global_position`: the current one or a neighbour, or
## null. A map with no size covers everything.
func map_at(global_position: Vector2) -> WgMap:
	if current == null:
		return null
	if current.size == Vector2i.ZERO or rect(current).has_point(global_position):
		return current
	for map: WgMap in neighbours:
		if rect(map).has_point(global_position):
			return map
	return null


## The global rectangle of `map`, from its size.
## The id of a map built from its scene, on screen or about to be; empty for
## another.
func id_of(map: WgMap) -> StringName:
	return _ids.get(map, &"")


func rect(map: WgMap) -> Rect2:
	return Rect2(map.global_position, Vector2(map.size * _tile_size()))


func _map_path(map_id: StringName) -> String:
	return _paths.resolve(&"maps", "%s.tscn" % map_id)


func _instantiate(map_id: StringName) -> WgMap:
	var path := _map_path(map_id)
	if not ResourceLoader.exists(path):
		_log.error(&"maps", "unknown map '%s' (no %s)" % [map_id, path])
		return null
	return _instantiate_scene(load(path) as PackedScene, path, map_id)


## Builds a map from its scene; the `map_built` hook sees it before it enters
## the tree.
func _instantiate_scene(packed: PackedScene, path: String, map_id: StringName) -> WgMap:
	if packed == null:
		_log.error(&"maps", "%s could not be loaded" % path)
		return null
	var node := packed.instantiate()
	if not node is WgMap:
		_log.error(&"maps", "%s: the root is not a WgMap" % path)
		node.free()
		return null
	var map := node as WgMap
	_ids[map] = map_id
	_hooks.run(&"map_built", [map, map_id])
	return map


## Frees every map on screen (the traveller survives), shows `next` at `at`
## and its neighbours around it.
func _replace(next: WgMap, next_id: StringName, at: Vector2) -> void:
	_generation += 1
	is_loading_neighbours = false
	if traveller != null and traveller.get_parent() != null:
		traveller.get_parent().remove_child(traveller)
	if current != null:
		_free_map(current)
	for map: WgMap in neighbours:
		_free_map(map)
	neighbours.clear()
	_neighbour_ids.clear()
	current = next
	current_id = next_id
	next.position = at
	host.add_child(next)
	_hooks.run(&"map_loaded", [next])
	for link: WgMapLink in _valid_links(next, next_id):
		var neighbour := _instantiate(link.map)
		if neighbour != null:
			_show_neighbour(neighbour, link)


func _free_map(map: WgMap) -> void:
	_hooks.run(&"map_leaving", [map])
	_ids.erase(map)
	map.get_parent().remove_child(map)
	map.free()


## The links of `map` that can be shown; the others are logged.
func _valid_links(map: WgMap, map_id: StringName) -> Array[WgMapLink]:
	var result: Array[WgMapLink] = []
	if map.links.is_empty():
		return result
	if map.size == Vector2i.ZERO:
		_log.error(&"maps", "%s: links need a size; shown alone" % map_id)
		return result
	var seen: Array[StringName] = []
	for link: WgMapLink in map.links:
		if link == null:
			_log.error(&"maps", "%s: empty link ignored" % map_id)
		elif link.map == map_id:
			_log.error(&"maps", "%s: linked to itself; link ignored" % map_id)
		elif link.map in seen:
			_log.error(&"maps", "%s: '%s' linked twice; first link kept" % [map_id, link.map])
		else:
			seen.append(link.map)
			result.append(link)
	return result


## Places `neighbour` against the current map, along `link`.
func _show_neighbour(neighbour: WgMap, link: WgMapLink) -> void:
	if neighbour.size == Vector2i.ZERO:
		_log.error(&"maps", "%s: no size; not shown next to %s" % [link.map, current_id])
		_ids.erase(neighbour)
		neighbour.free()
		return
	_check_link_back(neighbour, link)
	neighbour.position = current.position + Vector2(_link_tiles(current.size, neighbour.size, link) * _tile_size())
	host.add_child(neighbour)
	for other: WgMap in neighbours:
		if rect(other).intersects(rect(neighbour)):
			_log.warn(&"maps", "%s overlaps %s next to %s" % [link.map, _neighbour_ids[other], current_id])
	neighbours.append(neighbour)
	_neighbour_ids[neighbour] = link.map
	_hooks.run(&"map_loaded", [neighbour])


## Top-left tile of a map of `other` size linked to a map of `own` size.
static func _link_tiles(own: Vector2i, other: Vector2i, link: WgMapLink) -> Vector2i:
	match link.side:
		WgMapLink.Side.NORTH:
			return Vector2i(link.offset, -other.y)
		WgMapLink.Side.SOUTH:
			return Vector2i(link.offset, own.y)
		WgMapLink.Side.EAST:
			return Vector2i(own.x, link.offset)
		_:
			return Vector2i(-other.x, link.offset)


func _check_link_back(neighbour: WgMap, link: WgMapLink) -> void:
	var opposite := (link.side + 2) % 4
	for back: WgMapLink in neighbour.links:
		if back != null and back.map == current_id and back.side == opposite:
			if back.offset != -link.offset:
				_log.warn(&"maps", "%s and %s disagree on their offset" % [current_id, link.map])
			return
	_log.warn(&"maps", "%s links to %s, which does not link back" % [current_id, link.map])


## Loads `links` in the background, showing each map as soon as it is ready.
func _load_neighbours(links: Array[WgMapLink]) -> void:
	_generation += 1
	var generation := _generation
	is_loading_neighbours = true
	var waiting: Dictionary[WgMapLink, String] = {}
	for link: WgMapLink in links:
		var path := _map_path(link.map)
		if not ResourceLoader.exists(path):
			_log.error(&"maps", "unknown map '%s' (no %s)" % [link.map, path])
			continue
		ResourceLoader.load_threaded_request(path)
		_requested[path] = _requested.get(path, 0) + 1
		waiting[link] = path
	while not waiting.is_empty():
		if not _host_alive():
			for path: String in waiting.values():
				_collect(path)
			if generation == _generation:
				is_loading_neighbours = false
			return
		await host.get_tree().process_frame
		for link: WgMapLink in waiting.keys():
			var path := waiting[link]
			if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				continue
			waiting.erase(link)
			var packed := _collect(path)
			if generation != _generation or not _host_alive():
				continue
			var neighbour := _instantiate_scene(packed, path, link.map)
			if neighbour != null:
				_show_neighbour(neighbour, link)
	if generation == _generation and _host_alive():
		is_loading_neighbours = false
		neighbours_loaded.emit()


## Ends one background load of `path`, waiting for it if needed.
func _collect(path: String) -> PackedScene:
	_requested[path] -= 1
	if _requested[path] == 0:
		_requested.erase(path)
	return ResourceLoader.load_threaded_get(path) as PackedScene


## False once the host has left the game: loads still finish, unused.
func _host_alive() -> bool:
	return is_instance_valid(host) and host.is_inside_tree()


## {"position": global position, "direction": facing, "point": node or null}
func _arrival(map: WgMap, point_name: StringName) -> Dictionary:
	var point := map.find_point(point_name) if not point_name.is_empty() else null
	if point == null:
		if not point_name.is_empty():
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
	_steady_cameras(traveller)


## A Camera2D that changes parent shows a stale view for one frame: catch up.
static func _steady_cameras(node: Node) -> void:
	if node is Camera2D and node.is_inside_tree():
		(node as Camera2D).force_update_scroll()
	for child: Node in node.get_children():
		_steady_cameras(child)


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
