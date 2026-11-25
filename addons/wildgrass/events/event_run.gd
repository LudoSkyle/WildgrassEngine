## A list of commands running (feature 21): where it is, what it waits for,
## the branches taken. The events service owns it and advances it each
## frame, so it goes on after its event's map is freed by a warp.
extends RefCounted

const _Story := preload("res://addons/wildgrass/story/story.gd")
const _Log := preload("res://addons/wildgrass/core/log/log.gd")

## Commands run in one frame at most before the run gives the frame back:
## a loop that never waits cannot hold the game.
const MAX_COMMANDS := 100
## Common events calling each other deeper than this: the call is refused.
const MAX_DEPTH := 100

var list: Array[WgEventCommand] = []
var index := 0
## The event running it, or null (a common event; its map left).
var event: WgEvent
## Seconds still to wait.
var wait_left := 0.0
## Set while the run waits for something to end (a message, a walk).
var waiting := false
## The list of a common event it called, running first.
var child: RefCounted
var depth := 0

## The services commands use. The events service, held weakly: it holds
## its runs.
var events: Object:
	get:
		return _events.get_ref() if _events != null else null
var story: _Story
var log: _Log

var _running := false
## The answer of the last choice at each indent.
var _answers: Dictionary[int, int] = {}
## Numbers each wait for a message: one cut short never ends a later one.
var _wait_number := 0
## The map shown when it started: on another map, it forgets its event.
var _started_on: WgMap
## The id of its event's map, else of the map shown, when it started: the
## map whose events it names by number for their local switches.
var _map_id: StringName
## The result of the last condition at each indent.
var _branches: Dictionary[int, bool] = {}
var _map: WgMap


var _events: WeakRef


func _init(service: Object, run_depth := 0) -> void:
	_events = weakref(service)
	story = service.get(&"story")
	log = service.get(&"log")
	depth = run_depth


## Starts `commands`, for `by` (an event, or null).
func setup(commands: Array[WgEventCommand], by: WgEvent) -> void:
	list = commands
	index = 0
	event = by
	_map = _map_of(by)
	_started_on = events.get(&"maps").get(&"current")
	var maps: Object = events.get(&"maps")
	_map_id = maps.call(&"id_of", _map) if _map != null else maps.get(&"current_id")
	wait_left = 0.0
	waiting = false
	child = null
	_branches.clear()
	_answers.clear()
	_wait_number += 1
	_running = true


func is_running() -> bool:
	return _running


## Runs commands until one waits, the list ends, or MAX_COMMANDS ran.
func advance(delta: float) -> void:
	for _count in MAX_COMMANDS:
		if not _running:
			return
		# A freed event compares equal to null: only is_instance_valid() tells.
		if not is_instance_valid(event) or events.get(&"maps").get(&"current") != _started_on:
			event = null
		if child != null:
			child.call(&"advance", delta)
			if child.call(&"is_running"):
				return
			child = null
		if waiting:
			return
		if wait_left > 0.0:
			wait_left -= delta
			return
		if index >= list.size():
			finish()
			return
		var command := list[index]
		if command == null or command.run(self):
			index += 1
		else:
			return


## Ends the list.
func finish() -> void:
	_running = false
	list = []
	events.call(&"run_finished", self)


## Skips the block after the command at `index`: up to the next command at
## its indent.
func skip_block() -> void:
	var at := list[index].indent
	while index + 1 < list.size() and list[index + 1].indent != at:
		index += 1


## Records the condition at this indent; true goes into its block, false
## skips it. Returns true (the run goes on).
func branch(result: bool) -> bool:
	var at := list[index].indent
	_branches[at] = result
	if result:
		_branches.erase(at)
	else:
		skip_block()
	return true


## An else: runs its block when the condition before it failed.
func take_branch(want: bool) -> bool:
	var at := list[index].indent
	if _branches.get(at, not want) == want:
		_branches.erase(at)
		return true
	skip_block()
	return true


## Goes back to the loop's start at `at` (the command before its body).
func back_to_loop(at: int) -> void:
	while index > 0:
		index -= 1
		if list[index].indent == at:
			return


## Leaves the loop holding the command at `at`: on to its repeat.
func leave_loop(at: int) -> void:
	var look := index
	while look + 1 < list.size():
		look += 1
		if list[look] is WgEventRepeat and list[look].indent < at:
			index = look
			return
	index = list.size()


func jump_to(label: String) -> void:
	for look in list.size():
		if list[look] is WgEventLabel and (list[look] as WgEventLabel).label == label:
			index = look
			return


func call_common(number: int) -> void:
	if depth >= MAX_DEPTH:
		log.error(&"events", "common event %d: calls nested deeper than %d" % [number, MAX_DEPTH])
		return
	var common: WgCommonEvent = events.call(&"common_event", number)
	if common == null:
		return
	child = (get_script() as GDScript).new(events, depth + 1)
	child.call(&"setup", common.commands, event)


func erase_event() -> void:
	if event != null:
		events.call(&"erase", event)


## Turns local switch `letter` of event `number` of map `map` on or off: 0
## the event running the list, an empty map the one it started on.
func set_local_switch(letter: String, on: bool, number := 0, map := &"") -> void:
	var flag: StringName
	if number <= 0 and map.is_empty():
		if event == null:
			return
		flag = story.local(event, StringName(letter))
	else:
		var own := number if number > 0 else (event.event_id if event != null else 0)
		var map_id := map if not map.is_empty() else _map_id
		if own <= 0 or map_id.is_empty():
			return
		flag = _Story.local_on(map_id, WgEvent.local_place_of(own), StringName(letter))
	if on:
		story.set_flag(flag)
	else:
		story.clear_flag(flag)


## The character a command names: -1 the player, 0 the event running the
## list, else the event of that number on its map (the map shown, for a
## common event). Null if none.
func character(number: int) -> WgWalker:
	return events.call(&"character", number, event)


## Takes the player to `cell` of `map` (empty: the map shown), facing
## `direction` (zero: as it faces), through `transition` for `seconds`; the
## list waits until it has arrived.
func transfer(map: StringName, cell: Vector2i, direction: Vector2i, transition: StringName, seconds: float) -> void:
	var mine := _start_wait()
	await events.get(&"maps").call(&"transfer", map, cell, direction, transition, seconds)
	_end_wait(mine)


## True while a message or a question is under way, this list's or another's.
func message_busy() -> bool:
	var dialogue: Object = events.get(&"dialogue")
	return dialogue != null and bool(dialogue.call(&"is_busy"))


## Says `text`; the list waits until it is read.
func say(text: String) -> void:
	var dialogue: Object = events.get(&"dialogue")
	if dialogue == null:
		unsupported("messages (no dialogue)")
		return
	var mine := _start_wait()
	await dialogue.call(&"say", text, events.call(&"message_options"))
	_end_wait(mine)


## Asks `question` and `choices`; the answer is kept for the `WgEventWhen`
## at `at`. `cancel_answer`: what cancel answers, -1 nothing.
func ask(question: String, choices: Array[String], cancel_answer: int, at: int) -> void:
	var dialogue: Object = events.get(&"dialogue")
	if dialogue == null:
		unsupported("messages (no dialogue)")
		return
	var options: Dictionary = events.call(&"message_options")
	options["cancel"] = cancel_answer if cancel_answer < choices.size() else choices.size()
	var mine := _start_wait()
	var answer := int(await dialogue.call(&"ask", question, choices, options))
	if answer == choices.size():
		answer = cancel_answer
	if mine == _wait_number:
		_answers[at] = answer
	_end_wait(mine)


## Asks a number from 0 to `top` into variable `variable`.
func ask_number(question: String, variable: int, top: int) -> void:
	var dialogue: Object = events.get(&"dialogue")
	if dialogue == null:
		unsupported("messages (no dialogue)")
		return
	var options: Dictionary = events.call(&"message_options")
	options.merge({"min": 0, "max": top, "default": 0, "can_cancel": false})
	var mine := _start_wait()
	var number: Variant = await dialogue.call(&"ask_number", question, options)
	if mine == _wait_number and number != null:
		story.set_value(StringName("variable_%d" % variable), int(number))
	_end_wait(mine)


## A `WgEventWhen` for `answer`: runs its block when the choice before it at
## its indent answered it, else skips it.
func take_answer(answer: int) -> bool:
	var at := list[index].indent
	if _answers.get(at, -1) == answer:
		_answers.erase(at)
		return true
	skip_block()
	return true


func _start_wait() -> int:
	_wait_number += 1
	waiting = true
	return _wait_number


func _end_wait(mine: int) -> void:
	if mine == _wait_number:
		waiting = false


## A command the engine cannot run yet: logged once.
func unsupported(what: String) -> void:
	events.call(&"report_unsupported", what)


static func _map_of(node: Node) -> WgMap:
	var at := node
	while at != null and not at is WgMap:
		at = at.get_parent()
	return at as WgMap
