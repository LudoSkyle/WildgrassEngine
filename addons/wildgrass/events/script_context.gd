## The words an event's scripts use (feature 22): the engine's own, for any
## game. A script runs as a class extending the project's script context
## (the setting `wildgrass/events/script_context`, this one by default); a
## module or a game extends it with words of its own.
class_name WgScriptContext
extends RefCounted

## The project setting naming the script context: a script extending this
## one; empty for this one.
const SETTING := "wildgrass/events/script_context"
## RPG Maker's fade, as a transfer's: 20 ticks.
const DISSOLVE_SECONDS := 20.0 / 60.0

## The event running the script, or null (a common event; its map left).
var this: WgEvent
## Kept for the whole list: what a script leaves for the next to read.
var memory: Dictionary = {}
## The player, null before a game starts.
var player: WgWalker:
	get:
		return _events().get(&"maps").get(&"traveller") as WgWalker if _events() != null else null
## Wildgrass, every service, for what has no word yet; null outside the
## game (in tests).
var engine: Node:
	get:
		var tree := Engine.get_main_loop() as SceneTree
		return tree.root.get_node_or_null(^"Wildgrass") if tree != null else null

var _events_ref: WeakRef
var _run_ref: WeakRef


## Ties the context to the events service and the list running it (none
## for a route's step). Called by the engine.
func bind(events: Object, run: RefCounted, event: WgEvent, kept: Dictionary) -> void:
	_events_ref = weakref(events)
	_run_ref = weakref(run) if run != null else null
	this = event
	memory = kept


## A character as commands name them: -1 the player, 0 this event, else an
## event of its map (the map shown for a common event); null if none.
func character(number: int) -> WgWalker:
	return _events().call(&"character", number, this) if _events() != null else null


## True if story flag `flag_name` is on (feature 7).
func flag(flag_name: StringName) -> bool:
	return _story().has(flag_name)


func set_flag(flag_name: StringName, on := true) -> void:
	if on:
		_story().set_flag(flag_name)
	else:
		_story().clear_flag(flag_name)


## Story value `value_name`, 0 if never set.
func value(value_name: StringName) -> Variant:
	return _story().value(value_name)


func set_value(value_name: StringName, new_value: Variant) -> void:
	_story().set_value(value_name, new_value)


## Local switch `letter` of this event, or of event `event` of `map` (empty:
## the map the list started on).
func local(letter: String, event := 0, map := &"") -> bool:
	var name := _local(letter, event, map)
	return not name.is_empty() and _story().has(name)


func set_local(letter: String, on := true, event := 0, map := &"") -> void:
	var name := _local(letter, event, map)
	if not name.is_empty():
		set_flag(name, on)


## Shows `text` (a text or a key) and waits until it is read.
func say(text: String) -> void:
	var dialogue: Object = _events().get(&"dialogue")
	if dialogue == null:
		_unsupported("messages (no dialogue)")
		return
	await dialogue.call(&"say", text, _events().call(&"message_options"))


## Asks `question` with `choices`; returns the index of the one taken.
func ask(question: String, choices: Array) -> int:
	var dialogue: Object = _events().get(&"dialogue")
	if dialogue == null:
		_unsupported("messages (no dialogue)")
		return -1
	return int(await dialogue.call(&"ask", question, choices, _events().call(&"message_options")))


## Gives `count` of item `id`; false if the bag cannot take them.
func give_item(id: StringName, count := 1) -> bool:
	var bag: Object = _events().get(&"bag")
	return bag != null and bool(bag.call(&"add", id, count))


## Takes `count` of item `id`; false if the bag has fewer.
func take_item(id: StringName, count := 1) -> bool:
	var bag: Object = _events().get(&"bag")
	return bag != null and bool(bag.call(&"remove", id, count))


func has_item(id: StringName, at_least := 1) -> bool:
	var bag: Object = _events().get(&"bag")
	return bag != null and bool(bag.call(&"has", id, at_least))


func item_count(id: StringName) -> int:
	return int(_events().call(&"item_count", id))


## True if `watcher` (this event by default) sees the player within `reach`
## cells ahead, nothing between them; `side`: in a band that wide.
func sees_player(reach: int, side := 0, watcher: WgWalker = null) -> bool:
	return bool(_events().call(&"sees_player", _watcher(watcher), reach, side))


## True if the player is on the line `direction` from `watcher` (this event
## by default), at most `reach` cells, whatever stands between.
func player_in_line(reach: int, direction: Vector2i, watcher: WgWalker = null) -> bool:
	return bool(_events().call(&"player_in_line", _watcher(watcher), reach, direction))


## True if the player is at most `size.x` cells across and `size.y` along.
func player_in_rect(size: Vector2i, watcher: WgWalker = null) -> bool:
	return bool(_events().call(&"player_in_rect", _watcher(watcher), size))


## True if the player's distance, squared, is at most `distance_squared`.
func player_in_circle(distance_squared: int, watcher: WgWalker = null) -> bool:
	return bool(_events().call(&"player_in_circle", _watcher(watcher), distance_squared))


## Waits `seconds` of the game's time.
func wait(seconds: float) -> void:
	var clock: Object = _events().get(&"clock")
	var tree := Engine.get_main_loop() as SceneTree
	if clock == null or tree == null:
		return
	var until := int(clock.call(&"msec")) + roundi(seconds * 1000.0)
	while int(clock.call(&"msec")) < until:
		await tree.process_frame


## Takes the player to `cell` of `map` (empty: the map shown), facing
## `facing` (zero: as it faces), through RPG Maker's fade; waits until it
## has arrived.
func transfer(map: StringName, cell: Vector2i, facing := Vector2i.ZERO) -> void:
	await _events().get(&"maps").call(&"transfer", map, cell, facing, &"dissolve", DISSOLVE_SECONDS)


## Removes this event (or `event`) until its map is built again.
func erase(event: WgEvent = null) -> void:
	var erased := event if event != null else this
	if erased != null:
		_events().call(&"erase", erased)


## Removes this event (or `event`) for good: its map, built again, leaves
## it out too.
func erase_forever(event: WgEvent = null) -> void:
	var erased := event if event != null else this
	if erased != null:
		_events().call(&"erase_forever", erased)


## Runs common event `number` as soon as no list holds the player.
func start_common(number: int) -> void:
	_events().call(&"start_common", number)


## Plays sound effect `sound_name`.
func play_effect(sound_name: StringName, volume := 1.0, pitch := 1.0) -> void:
	var audio: Object = _events().get(&"audio")
	if audio != null:
		audio.call(&"effect", sound_name, volume, pitch)


func _events() -> Object:
	return _events_ref.get_ref() if _events_ref != null else null


func _story() -> Object:
	return _events().get(&"story")


func _run() -> Object:
	return _run_ref.get_ref() if _run_ref != null else null


func _watcher(watcher: WgWalker) -> WgWalker:
	return watcher if watcher != null else this


func _local(letter: String, event: int, map: StringName) -> StringName:
	var run := _run()
	if run != null:
		return run.call(&"local_switch", letter, event, map)
	if this != null and event <= 0 and map.is_empty():
		return _story().local(this, StringName(letter))
	return &""


func _unsupported(what: String) -> void:
	_events().call(&"report_unsupported", what)
