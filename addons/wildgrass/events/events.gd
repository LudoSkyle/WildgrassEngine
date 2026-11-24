## Runs the maps' events (feature 21): chooses each event's page as the
## story changes, starts events (the action key, a step onto or into one, by
## themselves), and runs their lists: one at a time holding the player, the
## parallel ones beside it. Lists run here, not in the events, so a list goes
## on after a warp frees its map.
extends RefCounted

const _Log := preload("res://addons/wildgrass/core/log/log.gd")
const _Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")
const _Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const _Maps := preload("res://addons/wildgrass/maps/maps.gd")
const _Story := preload("res://addons/wildgrass/story/story.gd")
const _Walkers := preload("res://addons/wildgrass/walking/walkers.gd")
const _Clock := preload("res://addons/wildgrass/core/clock/clock.gd")
const _Run := preload("res://addons/wildgrass/events/event_run.gd")
const _Mover := preload("res://addons/wildgrass/events/mover.gd")

## The group every event of the maps shown is in.
const GROUP := &"wildgrass_events"

## The list holding the player, running or not.
var main: _Run
var log: _Log
var maps: _Maps
var story: _Story
var walkers: _Walkers
var tiles: Object
## Set once the bag exists: money and items for conditions and variables.
var bag: Object
## Set once the audio exists: a route's sounds.
var audio: Object
## Set once the dialogue exists: messages and choices.
var dialogue: Object:
	set(value):
		dialogue = value
		if value != null:
			value.call(&"add_tag", &"look_to", _look_to_tag)
## Where messages show (`top`, `middle`, `bottom`) and whether with their
## frame, as a list's text options set them.
var message_place := "bottom"
var message_frame := true
var clock: _Clock

var _paths: _Paths
var _hooks: _Hooks
var _refresh_wanted := false
var _parallel: Dictionary[WgEvent, _Run] = {}
## Who moves each walker moving by itself or along a route imposed.
var _movers: Dictionary[WgWalker, _Mover] = {}
var _common_parallel: Dictionary[int, _Run] = {}
var _commons: Dictionary[int, WgCommonEvent] = {}
var _commons_listed := false
var _reported: Dictionary[String, bool] = {}
## The event the main list runs for, when the player started it.
var _locked: WgEvent
## The player's hold while the main list runs: [walker, number].
var _hold: Array = []


func _init(paths: _Paths, logger: _Log, hooks: _Hooks, maps_service: _Maps, story_service: _Story, walkers_service: _Walkers, clock_service: _Clock) -> void:
	_paths = paths
	log = logger
	_hooks = hooks
	maps = maps_service
	story = story_service
	walkers = walkers_service
	tiles = walkers_service.tiles
	clock = clock_service
	main = _Run.new(self)
	walkers.events = self
	_hooks.add(&"map_built", &"wildgrass_events", _on_map_built)
	story.changed.connect(_on_story_changed)
	story.restored.connect(_on_story_restored)
	maps.cleared.connect(_on_cleared)


## Each frame: pages chosen again if the story changed, events started by
## themselves, the parallel lists and the one holding the player advanced.
func advance(delta: float) -> void:
	if _refresh_wanted:
		_refresh_wanted = false
		for event in shown():
			refresh(event)
	_prune_movers()
	var current := events_of(maps.current)
	for event in current:
		_check_auto(event)
	for event in current:
		_run_parallel(event, delta)
	_run_common_parallel(delta)
	if not main.is_running():
		_start_next()
	if main.is_running():
		_hold_player()
		main.advance(delta)


## Every event of the maps shown.
func shown() -> Array[WgEvent]:
	var found: Array[WgEvent] = []
	for map: WgMap in [maps.current] + maps.neighbours:
		found.append_array(events_of(map))
	return found


## The events of `map`, by number.
func events_of(map: WgMap) -> Array[WgEvent]:
	var found: Array[WgEvent] = []
	if map == null or not is_instance_valid(map):
		return found
	_collect(map, found)
	found.sort_custom(func(a: WgEvent, b: WgEvent) -> bool: return a.event_id < b.event_id)
	return found


## Shows the last page of `event` whose condition holds; nothing changes when
## it is the page already shown.
func refresh(event: WgEvent) -> void:
	var chosen: WgEventPage = null
	if not event.erased:
		for index in range(event.pages.size() - 1, -1, -1):
			var page := event.pages[index]
			if page != null and story.check(page.condition, event):
				chosen = page
				break
	if chosen == event.page:
		return
	event.apply_page(chosen)
	_parallel.erase(event)
	_set_moves(event)


## Removes `event` until its map is built again.
func erase(event: WgEvent) -> void:
	event.erased = true
	refresh(event)


## Starts `event`: it runs once the list holding the player is free.
func start(event: WgEvent) -> void:
	if event.page == null or event.page.commands.is_empty():
		return
	event.starting = true
	_hold_player()


## The action key: the event the player faces (across a counter too), else
## one under the player that can be stepped on. True if one starts.
func start_by_action(walker: WgWalker) -> bool:
	if main.is_running():
		return false
	var cell := walker.cell + walker.facing
	for at: Vector2i in [cell, cell + walker.facing]:
		for event in _at(at):
			if event.page.trigger == WgEventPage.Trigger.ACTION and not event.is_stepped_on():
				start(event)
				return true
		if at == cell and tiles.data(cell, &"counter") != true:
			break
	for event in _at(walker.cell):
		if event.page.trigger == WgEventPage.Trigger.ACTION and event.is_stepped_on():
			start(event)
			return true
	return false


## A step of the traveller ends on its cell: an event stepped on there
## starts. True if one does.
func touch_here(walker: WgWalker) -> bool:
	if main.is_running():
		return false
	for event in _at(walker.cell):
		if _touched_by(event) and event.is_stepped_on():
			start(event)
			return true
	return false


## A step of the traveller toward `direction` failed: an event it bumps into
## there starts. True if one does.
func touch_there(walker: WgWalker, direction: Vector2i) -> bool:
	if main.is_running():
		return false
	for event in _at(walker.cell + direction):
		if _touched_by(event) and not event.is_stepped_on():
			start(event)
			return true
	return false


## Has `walker` (the player or an event) follow `route` now; its own way of
## moving waits until the route ends.
func force_route(walker: WgWalker, route: WgMoveRoute) -> void:
	var mover := _movers.get(walker) as _Mover
	if mover == null:
		mover = _Mover.new(self, walker)
		_movers[walker] = mover
	mover.force(route)
	walkers.drive(walker, mover.drive)


## True while a walker follows a route a command imposed.
func any_forced_route() -> bool:
	_prune_movers()
	for mover: _Mover in _movers.values():
		if mover.forced != null:
			return true
	return false


## Called by a mover as the route imposed on `walker` ends.
func route_ended(walker: WgWalker) -> void:
	var mover := _movers.get(walker) as _Mover
	if mover != null and not mover.is_needed():
		_movers.erase(walker)
		walkers.undrive(walker)


## Called by a mover as `walker` could not step toward `direction`: an
## event touch event walking into the player starts.
func bumped(walker: WgWalker, direction: Vector2i) -> void:
	if not walker is WgEvent or main.is_running():
		return
	var event := walker as WgEvent
	var player := maps.traveller as WgWalker
	if event.page != null and event.page.trigger == WgEventPage.Trigger.EVENT_TOUCH and player != null and player.cell == event.cell + direction \
			and not (event.is_jumping and event.is_stepped_on()):
		start(event)


## Called by a run as it ends.
func run_finished(run: _Run) -> void:
	if run != main:
		return
	if _locked != null and is_instance_valid(_locked):
		_locked.unlock()
	_locked = null
	_release_player()


## The character a command names, for a list run by `event`.
func character(number: int, event: WgEvent) -> WgWalker:
	if number < 0:
		return maps.traveller as WgWalker
	if number == 0:
		return event
	var map: WgMap = _map_of(event) if event != null else maps.current
	for other in events_of(map):
		if other.event_id == number:
			return other
	return null


## Common event `number`, or null (logged once).
func common_event(number: int) -> WgCommonEvent:
	if not _commons.has(number):
		var path := _paths.resolve(&"common_events", "%d.tres" % number)
		var loaded: Resource = load(path) if ResourceLoader.exists(path) else null
		if not loaded is WgCommonEvent:
			report_unsupported("common event %d (no %s)" % [number, path])
			return null
		_commons[number] = loaded
	return _commons[number]


## The options of a message a list shows.
func message_options() -> Dictionary:
	var options := {"place": message_place}
	if not message_frame:
		options["style"] = "transparent"
	return options


## What a command cannot do yet: logged once.
func report_unsupported(what: String) -> void:
	if _reported.has(what):
		return
	_reported[what] = true
	log.warn(&"events", "not handled yet: %s" % what)


func money() -> int:
	return int(bag.get(&"money")) if bag != null else 0


func has_item(item: StringName) -> bool:
	return bag != null and bool(bag.call(&"has", item))


func item_count(item: StringName) -> int:
	return int(bag.call(&"count", item)) if bag != null else 0


## The timer's seconds, or null while it is off.
func timer_seconds() -> Variant:
	report_unsupported("the timer")
	return null


## The cell of `walker`'s map's origin: commands count cells from it.
func map_origin_of(walker: WgWalker) -> Vector2i:
	var map := _map_of(walker)
	return tiles.call(&"cell_of", map.global_position) if map != null else Vector2i.ZERO


func terrain_tag(walker: WgWalker) -> int:
	var tag: Variant = tiles.call(&"data", walker.cell, &"terrain_tag")
	return int(tag) if tag != null else 0


func game_value(which: int) -> int:
	match which:
		WgEventSetVariables.Game.MAP_ID:
			var digits := String(maps.current_id).right(3)
			return int(digits) if digits.is_valid_int() else 0
		WgEventSetVariables.Game.MONEY:
			return money()
		WgEventSetVariables.Game.PLAY_TIME:
			return int(clock.seconds) if clock != null else 0
	report_unsupported("game value %s" % WgEventSetVariables.Game.keys()[which])
	return 0


## Moves `event` as its page says: a mover while it moves by itself,
## else its page's pace; a route imposed on it ends.
func _set_moves(event: WgEvent) -> void:
	var moved: WgWalker = event
	var mover := _movers.get(moved) as _Mover
	if event.page != null and event.page.move_type != WgEventPage.MoveType.FIXED:
		if mover == null:
			mover = _Mover.new(self, event)
			_movers[moved] = mover
		mover.set_page(event.page)
		walkers.drive(event, mover.drive)
		return
	if mover != null:
		_movers.erase(moved)
		walkers.undrive(event)
	event.pace = _Mover.pace_of(event.page.move_speed) if event.page != null else 0.0


## Forgets the movers of walkers freed with their map.
func _prune_movers() -> void:
	for walker: Variant in _movers.keys():
		if not is_instance_valid(walker):
			_movers.erase(walker)


func _on_map_built(map: Node, _map_id: StringName = &"") -> void:
	var found: Array[WgEvent] = []
	_collect(map, found)
	for event in found:
		event.erased = false
		event.page = null
		refresh(event)


## `[look_to=3]` in a message: the player turns toward event 3 of the map
## of the list holding it (0 does nothing, as Studio's).
func _look_to_tag(value: String) -> void:
	var number := value.to_int()
	var player := maps.traveller as WgWalker
	if number <= 0 or player == null:
		return
	var target := character(number, main.event)
	if target != null:
		player.turn_toward(target)


func _on_story_changed(_name: StringName) -> void:
	_refresh_wanted = true


func _on_story_restored() -> void:
	_refresh_wanted = true


func _on_cleared() -> void:
	_parallel.clear()
	_locked = null
	_release_player()


func _collect(node: Node, found: Array[WgEvent]) -> void:
	for child: Node in node.get_children():
		if child is WgEvent:
			found.append(child)
		_collect(child, found)


## The events showing on `cell`, on any map shown.
func _at(cell: Vector2i) -> Array[WgEvent]:
	var found: Array[WgEvent] = []
	for event in shown():
		if event.page != null and event.cell == cell:
			found.append(event)
	return found


static func _touched_by(event: WgEvent) -> bool:
	return event.page.trigger in [WgEventPage.Trigger.TOUCH, WgEventPage.Trigger.EVENT_TOUCH]


## An autorun page starts its event; an event touch one under the player,
## stepped on, does too.
func _check_auto(event: WgEvent) -> void:
	if event.page == null or event.starting:
		return
	if event.page.trigger == WgEventPage.Trigger.AUTORUN:
		event.starting = not event.page.commands.is_empty()
	elif event.page.trigger == WgEventPage.Trigger.EVENT_TOUCH and not maps.is_changing:
		var player := maps.traveller as WgWalker
		if player != null and player.cell == event.cell and event.is_stepped_on():
			event.starting = true


func _run_parallel(event: WgEvent, delta: float) -> void:
	if event.page == null or event.page.trigger != WgEventPage.Trigger.PARALLEL:
		return
	if not _parallel.has(event):
		_parallel[event] = _Run.new(self)
	var run := _parallel[event]
	if not run.is_running():
		run.setup(event.page.commands, event)
	run.advance(delta)


func _run_common_parallel(delta: float) -> void:
	for number in _common_numbers():
		var common := common_event(number)
		if common == null or common.trigger != WgCommonEvent.Trigger.PARALLEL or not story.has(common.switch):
			_common_parallel.erase(number)
			continue
		if not _common_parallel.has(number):
			_common_parallel[number] = _Run.new(self)
		var run := _common_parallel[number]
		if not run.is_running():
			run.setup(common.commands, null)
		run.advance(delta)


## The main list takes the first event starting on the map shown, by number;
## else a common event that runs by itself while its switch is on.
func _start_next() -> void:
	for event in events_of(maps.current):
		if not event.starting:
			continue
		event.starting = false
		if event.page == null:
			continue
		if event.page.trigger < WgEventPage.Trigger.AUTORUN:
			_locked = event
			event.lock(maps.traveller as Node2D)
		main.setup(event.page.commands, event)
		return
	for number in _common_numbers():
		var common := common_event(number)
		if common != null and common.trigger == WgCommonEvent.Trigger.AUTORUN and story.has(common.switch):
			main.setup(common.commands, null)
			return
	_release_player()


## The numbers of the common events the game has, in order.
func _common_numbers() -> Array[int]:
	if not _commons_listed:
		_commons_listed = true
		var folder := _paths.resolve(&"common_events", "")
		for file in DirAccess.get_files_at(folder) if DirAccess.dir_exists_absolute(folder) else PackedStringArray():
			var base := file.trim_suffix(".remap").get_basename()
			if file.trim_suffix(".remap").get_extension() == "tres" and base.is_valid_int():
				common_event(int(base))
	var numbers: Array[int] = []
	for number: int in _commons:
		if _commons[number] != null and _commons[number].trigger != WgCommonEvent.Trigger.NONE:
			numbers.append(number)
	numbers.sort()
	return numbers


func _hold_player() -> void:
	var player := maps.traveller as WgWalker
	if player == null or (not _hold.is_empty() and _hold[0] == player and walkers.is_busy(player)):
		return
	_hold = [player, walkers.occupy(player, self)]


func _release_player() -> void:
	if _hold.is_empty():
		return
	if is_instance_valid(_hold[0]):
		walkers.release(_hold[0], _hold[1])
	_hold = []


static func _map_of(node: Node) -> WgMap:
	var at := node
	while at != null and not at is WgMap:
		at = at.get_parent()
	return at as WgMap
