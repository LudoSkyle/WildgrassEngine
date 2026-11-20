## Messages written in a box. Opens the box screen, queues what is said, and
## closes the box at the end of the frame in which the last message ended.
extends RefCounted

const Log := preload("res://addons/wildgrass/core/log/log.gd")
const ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")
const ScreenRegistry := preload("res://addons/wildgrass/core/screens/screen_registry.gd")
const Maps := preload("res://addons/wildgrass/maps/maps.gd")
const MessageTags := preload("res://addons/wildgrass/dialogue/message_tags.gd")

## The box was opened.
signal opened
## A page, or a line in `scroll` mode, starts being written.
signal page_shown
## The confirm action took the text on.
signal advanced
## A message ended.
signal message_finished
## The box was closed.
signal closed

const OPTIONS: Array[String] = [
	"speaker", "speaker_color", "portrait", "style", "place", "auto", "hold", "walk_away", "screen",
]
const PLACES: Array[String] = ["bottom", "top", "middle"]
const DIRECTIONS: Dictionary[String, Vector2i] = {
	"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT,
}

## A message waiting to be said, and how it ended.
class Request:
	signal finished
	var text: String
	var options: Dictionary
	var done := false
	var result := 0

	func finish(value: int) -> void:
		if done:
			return
		done = true
		result = value
		finished.emit()


@warning_ignore("shadowed_global_identifier")
var log: Log
## The box on screen, or null.
var box: WgMessageBox
## The frame style of messages that give none: a frame the player picks.
var style := ""
## Letters written per second; 0 writes each page at once. From the config
## until set.
var letters_per_second: float:
	get:
		if _letters_per_second < 0.0:
			_letters_per_second = config().letters_per_second
		return _letters_per_second
	set(value):
		_letters_per_second = maxf(value, 0.0)

var _config: ConfigRegistry
var _hooks: Hooks
var _screens: ScreenRegistry
var _maps: Maps
var _letters_per_second := -1.0
var _tags: Dictionary[String, Callable] = {}
var _queue: Array[Request] = []
var _current: Request
var _held_open := false
var _missing_actions: Array[String] = []


func _init(logger: Log, config_registry: ConfigRegistry, hook_registry: Hooks, screen_registry: ScreenRegistry, maps_service: Maps) -> void:
	log = logger
	_config = config_registry
	_hooks = hook_registry
	_screens = screen_registry
	_maps = maps_service
	_maps.map_changed.connect(_on_map_changed)


## Says `text`; returns once the player has read it. See the options in the
## dialogue design.
func say(text: String, options := {}) -> void:
	var request := _enqueue(text, options)
	if not request.done:
		await request.finished


## Closes the box at once. Pending messages return.
func close() -> void:
	_held_open = false
	if is_instance_valid(box) and not box.is_closed():
		box.close()
	else:
		box = null
		_drop_all()


## True while the box is open.
func is_open() -> bool:
	return is_instance_valid(box) and not box.is_closed()


## `text` with its `[` written `[lb]`, so that it never reads as a tag: for
## what a `message_text` handler puts into a message.
static func escape(text: String) -> String:
	return text.replace("[", "[lb]")


## Adds a tag a message may hold, `[name]` or `[name=value]`. `callable` gets
## the value as a String when writing reaches the tag; if it returns a signal,
## writing waits for it. False, logged, for a name of Godot's BBCode, of the
## engine's tags, or already taken.
func add_tag(tag_name: StringName, callable: Callable) -> bool:
	var key := str(tag_name)
	if not key.is_valid_ascii_identifier() or key in MessageTags.ENGINE_TAGS or key in MessageTags.BBCODE_TAGS or _tags.has(key):
		log.error(&"dialogue", "cannot add the tag [%s]: taken" % key)
		return false
	_tags[key] = callable
	return true


func remove_tag(tag_name: StringName) -> void:
	_tags.erase(str(tag_name))


func tag_names() -> Array:
	return _tags.keys()


func run_tag(tag_name: String, value: String) -> Variant:
	return _tags[tag_name].call(value)


func config() -> WgDialogueConfig:
	return _config.get_config(&"dialogue") as WgDialogueConfig


## True if `event` presses the action of `key` in the config. An action
## missing from the input map is logged once.
func is_action(event: InputEvent, key: String) -> bool:
	var action: String = config().actions[key]
	if not InputMap.has_action(action):
		if action not in _missing_actions:
			_missing_actions.append(action)
			log.warn(&"dialogue", "no input action '%s' (dialogue_config.json actions.%s)" % [action, key])
		return false
	return event.is_action_pressed(action)


## The walking direction `event` presses, or zero.
func direction_of(event: InputEvent) -> Vector2i:
	var movement := _config.get_config(&"movement") as WgMovementConfig if _config.is_registered(&"movement") else null
	if movement == null:
		return Vector2i.ZERO
	for key: String in DIRECTIONS:
		var action: String = movement.actions[key]
		if InputMap.has_action(action) and event.is_action_pressed(action):
			return DIRECTIONS[key]
	return Vector2i.ZERO


## The direction the traveller faces, or zero.
func facing() -> Vector2i:
	var walker := _maps.traveller as WgWalker
	return walker.facing if walker != null else Vector2i.ZERO


## Called by the box when the message under way ends.
func _message_done(result: int) -> void:
	var request := _current
	if request == null:
		return
	_current = null
	_held_open = request.options.get("hold", false)
	message_finished.emit()
	request.finish(result)
	if _current == null:
		if _queue.is_empty():
			_close_if_idle.call_deferred()
		else:
			_next()


func _enqueue(text: String, options: Dictionary) -> Request:
	var request := Request.new()
	request.text = text
	request.options = _checked(options)
	_queue.append(request)
	if _current == null:
		_next()
	return request


func _next() -> void:
	while _current == null and not _queue.is_empty():
		var request: Request = _queue.pop_front()
		if not _open_box(StringName(request.options.get("screen", &"message_box"))):
			request.finish(0)
			continue
		_current = request
		_held_open = false
		var text := str(TranslationServer.translate(request.text))
		text = str(_hooks.filter(&"message_text", text, [request.options]))
		box.show_message(text, request.options)


func _open_box(screen_name: StringName) -> bool:
	if is_open():
		if box.screen_name == screen_name:
			return true
		var old := box
		box = null
		old.close()
	var screen := _screens.open(screen_name, {"dialogue": self})
	if screen == null:
		return false
	if not screen is WgMessageBox:
		log.error(&"dialogue", "%s: the screen is not a WgMessageBox" % screen_name)
		screen.close()
		return false
	box = screen
	box.closed.connect(_on_box_closed.bind(box))
	opened.emit()
	return true


func _close_if_idle() -> void:
	if _current == null and _queue.is_empty() and not _held_open:
		close()


func _on_box_closed(which: WgMessageBox) -> void:
	if which != box:
		return
	box = null
	_held_open = false
	_drop_all()
	closed.emit()


## Every pending message returns.
func _drop_all() -> void:
	var pending: Array[Request] = []
	if _current != null:
		pending.append(_current)
	pending.append_array(_queue)
	_current = null
	_queue.clear()
	for request in pending:
		request.finish(0)


## A warp or a reload closes the box; crossing a seam does not.
func _on_map_changed(_map: WgMap) -> void:
	if not _maps.is_crossing and (is_open() or _current != null):
		close()


func _checked(options: Dictionary) -> Dictionary:
	var checked := options.duplicate()
	for key: Variant in options:
		if str(key) not in OPTIONS:
			log.warn(&"dialogue", "unknown message option '%s'" % key)
	if checked.has("place") and str(checked["place"]) not in PLACES:
		log.warn(&"dialogue", "unknown place '%s'; using bottom" % checked["place"])
		checked["place"] = "bottom"
	if not checked.has("style") and not style.is_empty():
		checked["style"] = style
	return checked
