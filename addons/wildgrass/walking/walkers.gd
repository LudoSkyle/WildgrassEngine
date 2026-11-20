## The walkers in the game: who stands or steps where, so that no two go to the
## same cell, and what they need to walk.
extends RefCounted

const Log := preload("res://addons/wildgrass/core/log/log.gd")
const ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")
const ScreenRegistry := preload("res://addons/wildgrass/core/screens/screen_registry.gd")
const Maps := preload("res://addons/wildgrass/maps/maps.gd")
const Tiles := preload("res://addons/wildgrass/tiles/tiles.gd")

@warning_ignore("shadowed_global_identifier")
var log: Log
var config: ConfigRegistry
var hooks: Hooks
var screens: ScreenRegistry
var maps: Maps
var tiles: Tiles

## Walker -> the [cell, level] pairs it holds: where it stands, and where its
## step goes.
var _held: Dictionary[WgWalker, Array] = {}
var _missing_actions: Array[String] = []


func _init(logger: Log, config_registry: ConfigRegistry, hook_registry: Hooks, screen_registry: ScreenRegistry, maps_service: Maps, tiles_service: Tiles) -> void:
	log = logger
	config = config_registry
	hooks = hook_registry
	screens = screen_registry
	maps = maps_service
	tiles = tiles_service
	hooks.add(&"can_step", &"wildgrass_walkers", _keep_walkers_apart)


## The walker standing or stepping into `cell` on `level`, or null. Walkers
## going `through` are never found.
func at(cell: Vector2i, level := 0) -> WgWalker:
	for walker: WgWalker in _held:
		if walker.through:
			continue
		for held: Array in _held[walker]:
			if held[0] == cell and held[1] == level:
				return walker
	return null


## `walker` now holds `cell` on `level`, as well as what it held.
func hold(walker: WgWalker, cell: Vector2i, level: int) -> void:
	if not _held.has(walker):
		_held[walker] = []
	_held[walker].append([cell, level])


## `walker` holds only `cell` on `level`.
func settle(walker: WgWalker, cell: Vector2i, level: int) -> void:
	_held[walker] = [[cell, level]]


## `walker` holds nothing any more.
func forget(walker: WgWalker) -> void:
	_held.erase(walker)


## The door standing in `cell` of the current map, or null.
func door_at(cell: Vector2i) -> WgDoor:
	if maps.current == null:
		return null
	return _door_in(maps.current, cell)


func _door_in(node: Node, cell: Vector2i) -> WgDoor:
	for child: Node in node.get_children():
		if child is WgDoor and tiles.cell_of((child as WgDoor).global_position) == cell:
			return child
		var found := _door_in(child, cell)
		if found != null:
			return found
	return null


func movement() -> WgMovementConfig:
	return config.get_config(&"movement") as WgMovementConfig


## True while an input action is held. An action missing from the input map is
## logged once and never held.
func is_held(action_key: String) -> bool:
	var action: String = movement().actions[action_key]
	if InputMap.has_action(action):
		return Input.is_action_pressed(action)
	if action not in _missing_actions:
		_missing_actions.append(action)
		log.warn(&"walking", "no input action '%s' (movement_config.json actions.%s)" % [action, action_key])
	return false


func _keep_walkers_apart(allowed: bool, cell: Vector2i, direction: Vector2i, level: int, walker: Node) -> bool:
	if not allowed or (walker is WgWalker and (walker as WgWalker).through):
		return allowed
	var other := at(cell + direction, tiles.level_after(cell, direction, level))
	return other == null or other == walker
