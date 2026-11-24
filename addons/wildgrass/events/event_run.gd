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
## The map shown when it started: on another map, it forgets its event.
var _started_on: WgMap
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
	wait_left = 0.0
	waiting = false
	child = null
	_branches.clear()
	_running = true


func is_running() -> bool:
	return _running


## Runs commands until one waits, the list ends, or MAX_COMMANDS ran.
func advance(delta: float) -> void:
	for _count in MAX_COMMANDS:
		if not _running:
			return
		if event != null and (not is_instance_valid(event) or events.get(&"maps").get(&"current") != _started_on):
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


func set_local_switch(letter: String, on: bool) -> void:
	if event == null:
		return
	var flag := story.local(event, StringName(letter))
	if on:
		story.set_flag(flag)
	else:
		story.clear_flag(flag)


## The character a command names: -1 the player, 0 the event running the
## list, else the event of that number on its map (the map shown, for a
## common event). Null if none.
func character(number: int) -> WgWalker:
	return events.call(&"character", number, event)


## A command the engine cannot run yet: logged once.
func unsupported(what: String) -> void:
	events.call(&"report_unsupported", what)


static func _map_of(node: Node) -> WgMap:
	var at := node
	while at != null and not at is WgMap:
		at = at.get_parent()
	return at as WgMap
