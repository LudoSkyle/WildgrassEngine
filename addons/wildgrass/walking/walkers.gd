## The walkers in the game: who stands or steps where, so that no two go to the
## same cell, and what they need to walk.
extends RefCounted

const Log := preload("res://addons/wildgrass/core/log/log.gd")
const ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")
const ScreenRegistry := preload("res://addons/wildgrass/core/screens/screen_registry.gd")
const Maps := preload("res://addons/wildgrass/maps/maps.gd")
const Tiles := preload("res://addons/wildgrass/tiles/tiles.gd")
const Dialogue := preload("res://addons/wildgrass/dialogue/dialogue.gd")

@warning_ignore("shadowed_global_identifier")
var log: Log
var config: ConfigRegistry
var hooks: Hooks
var screens: ScreenRegistry
var maps: Maps
var tiles: Tiles
## Says the tile messages; set once the dialogue service exists.
var dialogue: Dialogue

## Walker -> the [cell, level] pairs it holds: where it stands, and where its
## step goes.
var _held: Dictionary[WgWalker, Array] = {}
var _missing_actions: Array[String] = []
## Walker -> [what it interacts with, the interaction's number].
var _busy: Dictionary[WgWalker, Array] = {}
var _interactions := 0


func _init(logger: Log, config_registry: ConfigRegistry, hook_registry: Hooks, screen_registry: ScreenRegistry, maps_service: Maps, tiles_service: Tiles) -> void:
	log = logger
	config = config_registry
	hooks = hook_registry
	screens = screen_registry
	maps = maps_service
	tiles = tiles_service
	hooks.add(&"can_step", &"wildgrass_walkers", _keep_walkers_apart)
	maps.map_changed.connect(_on_map_changed)


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


## The interactable covering `cell` on `level`, faced in `direction`, or null.
func interactable_at(tree: SceneTree, cell: Vector2i, level: int, direction: Vector2i) -> WgInteractable:
	for node: Node in tree.get_nodes_in_group(WgInteractable.GROUP):
		var interactable := node as WgInteractable
		if interactable.covers(tiles.cell_of(interactable.global_position), cell, level, direction):
			return interactable
	return null


## `walker` interacts with what it faces: an interactable, through a counter,
## then a tile's `message` data; then the `interact` filter hook. Returns once
## the interaction ended.
func interact(walker: WgWalker) -> void:
	var cell := walker.cell + walker.facing
	var target := interactable_at(walker.get_tree(), cell, walker.level, walker.facing)
	if target == null and tiles.data(cell, &"counter") == true:
		cell += walker.facing
		target = interactable_at(walker.get_tree(), cell, walker.level, walker.facing)
	_interactions += 1
	var number := _interactions
	_busy[walker] = [target if target != null else walker, number]
	var handled := false
	if target != null:
		await target.interact(walker)
		handled = true
	else:
		var message: Variant = tiles.data(cell, &"message")
		if message is String and not (message as String).is_empty() and dialogue != null:
			await dialogue.say(message)
			handled = true
	hooks.filter(&"interact", handled, [cell, walker])
	if _busy.has(walker) and _busy[walker][1] == number:
		_busy.erase(walker)


## True while `walker` interacts: until the interaction returns, what it
## interacts with is freed, or the map changes.
func is_busy(walker: WgWalker) -> bool:
	if not _busy.has(walker):
		return false
	if not is_instance_valid(_busy[walker][0]):
		_busy.erase(walker)
		return false
	return true


func movement() -> WgMovementConfig:
	return config.get_config(&"movement") as WgMovementConfig


## True while an input action is held. An action missing from the input map is
## logged once and never held.
func is_held(action_key: String) -> bool:
	return _known(action_key) and Input.is_action_pressed(movement().actions[action_key])


## True in the frame an input action is pressed.
func is_pressed(action_key: String) -> bool:
	return _known(action_key) and Input.is_action_just_pressed(movement().actions[action_key])


func _known(action_key: String) -> bool:
	var action: String = movement().actions[action_key]
	if InputMap.has_action(action):
		return true
	if action not in _missing_actions:
		_missing_actions.append(action)
		log.warn(&"walking", "no input action '%s' (movement_config.json actions.%s)" % [action, action_key])
	return false


## A warp or a reload ends every interaction; crossing a seam does not.
func _on_map_changed(_map: WgMap) -> void:
	if not maps.is_crossing:
		_busy.clear()


func _keep_walkers_apart(allowed: bool, cell: Vector2i, direction: Vector2i, level: int, walker: Node) -> bool:
	if not allowed or (walker is WgWalker and (walker as WgWalker).through):
		return allowed
	var other := at(cell + direction, tiles.level_after(cell, direction, level))
	return other == null or other == walker
