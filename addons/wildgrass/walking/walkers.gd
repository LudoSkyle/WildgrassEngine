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
const Story := preload("res://addons/wildgrass/story/story.gd")
const Bag := preload("res://addons/wildgrass/bag/bag.gd")
const Menu := preload("res://addons/wildgrass/menu/menu.gd")

@warning_ignore("shadowed_global_identifier")
var log: Log
var config: ConfigRegistry
var hooks: Hooks
var screens: ScreenRegistry
var maps: Maps
var tiles: Tiles
## Says the tile messages; set once the dialogue service exists.
var dialogue: Dialogue
## What characters say follows it; set once the story service exists.
var story: Story
## Item balls give through it; set once the bag service exists.
var bag: Bag
## The pause menu, opened by the player's `menu` action.
var menu: Menu

## Walker -> the [cell, level] pairs it holds: where it stands, and where its
## step goes.
var _held: Dictionary[WgWalker, Array] = {}
var _missing_actions: Array[String] = []
## Walker -> [what it interacts with, the interaction's number].
var _busy: Dictionary[WgWalker, Array] = {}
var _interactions := 0
var _scripts: Dictionary[WgWalker, Walk] = {}
var _still: Dictionary[WgWalker, bool] = {}
## True while a path is searched: characters do not block it, they move.
var _searching := false

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const WALK_OPTIONS: Array[String] = ["face", "run", "skip_blocked"]
## Cells a path search visits per frame.
const SEARCH_CELLS_PER_FRAME := 25


## A walk a script asked for, and how it ended.
class Walk:
	signal finished
	var steps: Array[Vector2i] = []
	var index := 0
	var face := true
	var run := false
	var skip_blocked := false
	var waited := 0.0
	var done := false
	var result := false

	func finish(value: bool) -> void:
		if done:
			return
		done = true
		result = value
		finished.emit()


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


## `walker` holds nothing any more; a walk it was on ends.
func forget(walker: WgWalker) -> void:
	_held.erase(walker)
	_still.erase(walker)
	_end_walk(walker, false)


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
		var holder := interactable.get_parent() as WgWalker
		var origin := holder.destination if holder != null else tiles.cell_of(interactable.global_position)
		if interactable.covers(origin, cell, level, direction):
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


## True if an interactable that blocks covers `cell` on `level`. One inside a
## walker does not: the walker holds its cell.
func _blocked(tree: SceneTree, cell: Vector2i, level: int) -> bool:
	for node: Node in tree.get_nodes_in_group(WgInteractable.GROUP):
		var blocking := node as WgInteractable
		if blocking.blocks and blocking.level == level and not blocking.get_parent() is WgWalker \
				and Rect2i(tiles.cell_of(blocking.global_position), blocking.size).has_point(cell):
			return true
	return false


## Runs the enabled trigger under `walker`, the traveller, after its own step:
## it is held at once, until the trigger returns. Not while a script walks it
## or it is held already.
func trigger_at(walker: WgWalker) -> void:
	if is_scripted(walker) or is_busy(walker) or not walker.is_inside_tree():
		return
	var found: WgTrigger = null
	for node: Node in walker.get_tree().get_nodes_in_group(WgTrigger.GROUP):
		var trigger := node as WgTrigger
		if trigger.enabled and trigger.covers(tiles.cell_of(trigger.global_position), walker.cell, walker.level):
			found = trigger
			break
	if found == null:
		return
	walker.is_sliding = false
	_interactions += 1
	var number := _interactions
	_busy[walker] = [found, number]
	await found.trigger(walker)
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


## Walks `walker` through `directions`, one step each; returns true once
## done, false if cut short: a warp or a reload, the walker freed, another walk
## for it, or a cell that stayed taken for `patience` seconds. Options: `face`
## (true; false backs away), `run`, `skip_blocked` (skips a taken cell instead
## of waiting).
func walk(walker: WgWalker, directions: Array, options := {}) -> bool:
	if not is_instance_valid(walker):
		return false
	for key: Variant in options:
		if str(key) not in WALK_OPTIONS:
			log.warn(&"walking", "unknown walk option '%s'" % key)
	_end_walk(walker, false)
	var request := Walk.new()
	for direction: Variant in directions:
		request.steps.append(direction)
	request.face = options.get("face", true)
	request.run = options.get("run", false)
	request.skip_blocked = options.get("skip_blocked", false)
	_scripts[walker] = request
	if not request.done:
		await request.finished
	return request.result


## Walks `walker` to the world cell `cell` by a path found through what
## `can_step` allows, over a few frames; false if there is none within
## `pathCells`, or as `walk()`.
func walk_to(walker: WgWalker, cell: Vector2i, options := {}) -> bool:
	var path: Variant = await _find_path(walker, cell)
	if path == null:
		return false
	return await walk(walker, path, options)


## True while a script walks `walker`: its controller waits.
func is_scripted(walker: WgWalker) -> bool:
	return _scripts.has(walker)


## Asked by a scripted walker free to step: its next step, or the end.
func drive_script(walker: WgWalker, delta: float) -> void:
	var request := _scripts[walker]
	while request.index < request.steps.size():
		var direction := request.steps[request.index]
		if walker.can_step(direction):
			request.index += 1
			request.waited = 0.0
			walker.step(direction, request.run, request.face)
			return
		if not request.skip_blocked:
			if request.face:
				walker.turn(direction)
			request.waited += delta
			if request.waited >= movement().patience:
				_end_walk(walker, false)
			return
		request.index += 1
	_end_walk(walker, true)


func _end_walk(walker: WgWalker, result: bool) -> void:
	if _scripts.has(walker):
		var request := _scripts[walker]
		_scripts.erase(walker)
		request.finish(result)


## The directions from `walker`'s cell to `target`, or null.
func _find_path(walker: WgWalker, target: Vector2i) -> Variant:
	if not is_instance_valid(walker) or not walker.is_inside_tree():
		return null
	var tree := walker.get_tree()
	var start := Vector3i(walker.cell.x, walker.cell.y, walker.level)
	var came_from: Dictionary[Vector3i, Array] = {start: []}
	var queue: Array[Vector3i] = [start]
	var visited := 0
	var budget := movement().path_cells
	while not queue.is_empty():
		if visited > 0 and visited % SEARCH_CELLS_PER_FRAME == 0:
			await tree.process_frame
			if not is_instance_valid(walker):
				return null
		var here: Vector3i = queue.pop_front()
		if Vector2i(here.x, here.y) == target:
			var path: Array[Vector2i] = []
			var key := here
			while key != start:
				path.push_front(came_from[key][1])
				key = came_from[key][0]
			return path
		visited += 1
		if visited > budget:
			return null
		_searching = true
		for next: Array in _moves_from(walker, here):
			if not came_from.has(next[0]):
				came_from[next[0]] = [here, next[1]]
				queue.append(next[0])
		_searching = false
	return null


## [cell and level after, direction] for each step `walker` could take from
## `here`, jumps included.
func _moves_from(walker: WgWalker, here: Vector3i) -> Array[Array]:
	var moves: Array[Array] = []
	var cell := Vector2i(here.x, here.y)
	for direction in DIRECTIONS:
		var after := cell + direction
		var level := here.z
		if tiles.can_step(cell, direction, here.z, walker):
			level = tiles.level_after(cell, direction, here.z)
		elif walker.jumps and tiles.data(after, &"jump") == direction and tiles.is_solid(after, here.z) \
				and not tiles.has_edge(cell, direction, here.z) and tiles.can_step(after, direction, here.z, walker):
			level = tiles.level_after(after, direction, here.z)
			after += direction
		else:
			continue
		moves.append([Vector3i(after.x, after.y, level), direction])
	return moves


## Keeps `walker`'s controller from acting, while it talks say.
func set_still(walker: WgWalker, still: bool) -> void:
	if still:
		_still[walker] = true
	else:
		_still.erase(walker)


## True if `walker`'s controller may act now: not while kept still. The
## traveller's otherwise always may: its input keeps track of the keys. Others
## stand still while a screen is open, a warp runs, or the player is held,
## unless the config says otherwise.
func may_act(walker: WgWalker) -> bool:
	if _still.has(walker):
		return false
	if walker == maps.traveller or not movement().still_during_dialogue:
		return true
	if maps.is_changing or not screens.stack().is_empty():
		return false
	var player := maps.traveller as WgWalker
	return player == null or not is_busy(player)


## The map `node` belongs to, or null.
static func map_of(node: Node) -> WgMap:
	var parent := node.get_parent()
	while parent != null and not parent is WgMap:
		parent = parent.get_parent()
	return parent as WgMap


## The world cell of `local`, a cell of `map`.
func world_cell(map: WgMap, local: Vector2i) -> Vector2i:
	return tiles.cell_of(maps.rect(map).position) + local


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


## The `map` part of a saved game: the current map, the traveller's cell,
## level and facing on it, and every walker's of that map, by its path in it.
## Cells are the map's own, from its corner. Empty with no map or traveller.
func map_state() -> Dictionary:
	var map := maps.current
	if map == null or maps.traveller == null:
		return {}
	var state := {"map": str(maps.current_id)}
	state.merge(_place_of(maps.traveller, map))
	var others := {}
	for walker: WgWalker in _held:
		if walker != maps.traveller and is_instance_valid(walker) and map.is_ancestor_of(walker):
			others[str(map.get_path_to(walker))] = _place_of(walker, map)
	state["walkers"] = others
	return state


## Refuses a game whose map no longer exists, unless the filter hook
## `save_lost_map(map_id, state)` names one that does: the traveller then
## starts at its first spawn point.
func check_map(state: Dictionary) -> bool:
	if state.is_empty() or maps.has_map(StringName(str(state.get("map", "")))):
		return true
	var lost := str(state.get("map", ""))
	var instead := StringName(str(hooks.filter(&"save_lost_map", &"", [lost, state])))
	if not maps.has_map(instead):
		log.error(&"walking", "the saved map '%s' no longer exists" % lost)
		return false
	state["map"] = str(instead)
	state.erase("cell")
	state.erase("walkers")
	return true


## Puts the traveller and the walkers back where `map_state()` saw them.
func restore_map(state: Dictionary) -> void:
	if state.is_empty():
		return
	var map_id := StringName(str(state["map"]))
	if not state.has("cell"):
		await maps.go_to(map_id, &"")
		return
	var place := _read_place(state)
	if not await maps.go_to_cell(map_id, place["cell"], place["facing"]):
		return
	var traveller := maps.traveller as WgWalker
	if traveller != null:
		traveller.place_at(place["cell"], place["level"], place["facing"])
	var others: Variant = state.get("walkers", {})
	if not others is Dictionary:
		return
	for path: Variant in others:
		var walker := maps.current.get_node_or_null(NodePath(str(path))) as WgWalker
		if walker != null and walker != traveller and others[path] is Dictionary:
			var at := _read_place(others[path])
			walker.place_at(at["cell"], at["level"], at["facing"])


## A new game: the game warps to its first map itself.
func reset_map() -> void:
	pass


## The `save_summary` hook: a game's card shows where it was left.
func map_summary(summary: Dictionary, _slot: int) -> Dictionary:
	summary["map"] = str(maps.current_id)
	summary["zone"] = str(maps.current.zone) if maps.current != null else ""
	return summary


func _place_of(node: Node2D, map: WgMap) -> Dictionary:
	var walker := node as WgWalker
	var cell := tiles.cell_of(node.global_position - map.global_position)
	if walker != null:
		cell = walker.cell - tiles.cell_of(map.global_position)
	var facing := walker.facing if walker != null else Vector2i.DOWN
	return {"cell": [cell.x, cell.y], "level": walker.level if walker != null else 0, "facing": [facing.x, facing.y]}


static func _read_place(saved: Dictionary) -> Dictionary:
	return {"cell": _read_cell(saved.get("cell")), "level": int(saved.get("level", 0)), "facing": _read_cell(saved.get("facing"))}


static func _read_cell(value: Variant) -> Vector2i:
	if value is Array and value.size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO


## A warp or a reload ends every interaction and scripted walk; crossing a
## seam does not.
func _on_map_changed(_map: WgMap) -> void:
	if maps.is_crossing:
		return
	_busy.clear()
	for walker: WgWalker in _scripts.keys():
		_end_walk(walker, false)


## Walkers block each other, except going through, or stepping into a cell
## another is leaving; an interactable that blocks blocks them all.
func _keep_walkers_apart(allowed: bool, cell: Vector2i, direction: Vector2i, level: int, walker: Node) -> bool:
	if not allowed:
		return false
	if walker != null and walker.is_inside_tree() and _blocked(walker.get_tree(), cell + direction, tiles.level_after(cell, direction, level)):
		return false
	if _searching or (walker is WgWalker and (walker as WgWalker).through):
		return allowed
	var other := at(cell + direction, tiles.level_after(cell, direction, level))
	return other == null or other == walker or (other.is_moving and other.cell == cell + direction)
