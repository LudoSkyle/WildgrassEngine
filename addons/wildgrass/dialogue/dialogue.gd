## Messages written in a box, and questions. Opens the box screen, queues what
## is said, and closes the box at the end of the frame in which the last
## message ended.
extends RefCounted

const Log := preload("res://addons/wildgrass/core/log/log.gd")
const ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")
const ScreenRegistry := preload("res://addons/wildgrass/core/screens/screen_registry.gd")
const Maps := preload("res://addons/wildgrass/maps/maps.gd")
const Texts := preload("res://addons/wildgrass/texts/texts.gd")
const MessageTags := preload("res://addons/wildgrass/dialogue/message_tags.gd")

## The box was opened.
signal opened
## A page, or a line in `scroll` mode, starts being written.
signal page_shown
## The confirm action took the text on.
signal advanced
## A message ended.
signal message_finished
## The selection of a question moved to `index`.
signal choice_moved(index: int)
## The choice at `index` was taken.
signal choice_made(index: int)
## The choice at `index` is disabled: it was not taken.
signal choice_refused(index: int)
## The box was closed.
signal closed

const OPTIONS: Array[String] = [
	"speaker", "speaker_color", "portrait", "style", "place", "auto", "hold", "walk_away", "screen",
	"default", "cancel", "locked", "values", "min", "max",
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
	## Each `{"text", "disabled"}`; empty unless a question.
	var answers: Array[Dictionary] = []
	## `{"min", "max", "default"}`; empty unless a number is asked.
	var number: Dictionary = {}
	var done := false
	var result: Variant = 0

	## What a question answers when it is cut short.
	func cancelled() -> Variant:
		if not number.is_empty():
			return null
		return int(options["cancel"]) if not answers.is_empty() else 0

	func finish(value: Variant) -> void:
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
var _texts: Texts
var _letters_per_second := -1.0
var _tags: Dictionary[String, Callable] = {}
var _narrating: Dictionary[String, bool] = {}
var _queue: Array[Request] = []
var _current: Request
var _held_open := false
var _missing_actions: Array[String] = []


func _init(logger: Log, config_registry: ConfigRegistry, hook_registry: Hooks, screen_registry: ScreenRegistry, maps_service: Maps, texts_service: Texts) -> void:
	log = logger
	_texts = texts_service
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


## Asks `text`, then shows `choices`; returns the index of the choice taken.
## A choice is a String, or `{"text": …, "disabled": true}`: shown, never
## taken. Options as `say()`, and `default` (0), the choice selected first;
## `cancel` (the last), what the cancel action answers, `-1` for nothing.
func ask(text: String, choices: Array, options := {}) -> int:
	if choices.is_empty():
		log.error(&"dialogue", "a question needs choices: \"%s\"" % text)
		return -1
	var request := _enqueue(text, options, choices)
	if not request.done:
		await request.finished
	return int(request.result)


## Asks `text`, then a number between options `min` (0) and `max` (99),
## starting at `default` (`min`): up and down by one, left and right by ten,
## wrapping. Returns it, or null when cancelled, closed or cut by a warp.
func ask_number(text: String, options := {}) -> Variant:
	var low := int(options.get("min", 0))
	var high := int(options.get("max", 99))
	if high < low:
		log.warn(&"dialogue", "max %d is below min %d; using %d" % [high, low, low])
		high = low
	var asked := {"min": low, "max": high, "default": clampi(int(options.get("default", low)), low, high)}
	var request := _enqueue(text, options, [], asked)
	if not request.done:
		await request.finished
	return request.result


## Asks `text` with Yes and No; true for Yes. Cancel answers No.
func confirm(text: String, options := {}) -> bool:
	var checked := options.duplicate()
	checked["cancel"] = 1
	return await ask(text, ["Yes", "No"], checked) == 0


## Closes the box at once. Pending messages return; questions answer their
## `cancel`, or `-1`.
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
## writing waits for it. A tag that `narrates` is the game's voice: a message
## holding it shows no speaker. False, logged, for a name of Godot's BBCode,
## of the engine's tags, or already taken.
func add_tag(tag_name: StringName, callable: Callable, narrates := false) -> bool:
	var key := str(tag_name)
	if not key.is_valid_ascii_identifier() or key in MessageTags.ENGINE_TAGS or key in MessageTags.BBCODE_TAGS or _tags.has(key):
		log.error(&"dialogue", "cannot add the tag [%s]: taken" % key)
		return false
	_tags[key] = callable
	if narrates:
		_narrating[key] = true
	return true


func remove_tag(tag_name: StringName) -> void:
	_tags.erase(str(tag_name))
	_narrating.erase(str(tag_name))


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
			log.warn(&"dialogue", "no input action '%s' (dialogue config, actions.%s)" % [action, key])
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


## The message under way, once written, stays `seconds` then goes on by
## itself, the key not hurrying it.
func lock_current(seconds: float) -> void:
	if _current != null:
		_current.options["locked"] = true
		_current.options["auto"] = seconds


## Called by the box when the message under way ends.
func _message_done(result: Variant) -> void:
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


func _enqueue(text: String, options: Dictionary, choices := [], asked := {}) -> Request:
	var request := Request.new()
	request.text = text
	request.options = _checked(options)
	request.number = asked
	if not choices.is_empty():
		request.answers = _answers(choices, request.options)
	_queue.append(request)
	if _current == null:
		_next()
	return request


func _next() -> void:
	while _current == null and not _queue.is_empty():
		var request: Request = _queue.pop_front()
		if not _open_box(StringName(request.options.get("screen", &"message_box"))):
			request.finish(request.cancelled())
			continue
		_current = request
		_held_open = false
		var translated := _translated(request.text)
		if translated != request.text:
			_check_translation(request.text, translated)
		var values := {}
		for value_name: Variant in request.options.get("values", {}):
			values[str(value_name)] = _texts.label(str(request.options["values"][value_name]))
		var text := _texts.format(translated, true, values)
		if request.options.has("speaker"):
			request.options["speaker"] = _texts.format(_translated(str(request.options["speaker"])), false, values)
		for answer: Dictionary in request.answers:
			answer["text"] = _texts.format(_translated(answer["text"]), false, values)
		text = str(_hooks.filter(&"message_text", text, [request.options]))
		if _narrates(text):
			request.options["speaker"] = ""
		box.show_message(text, request.options, request.answers, request.number)


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


## A translation that loses a game tag of its source would act differently in
## that language only: logged.
func _check_translation(source: String, translated: String) -> void:
	var kept: Array[String] = []
	for tag: Dictionary in MessageTags.split(translated, tag_names(), [])["tags"]:
		if _tags.has(tag["name"]):
			kept.append("%s=%s" % [tag["name"], tag["value"]])
	for tag: Dictionary in MessageTags.split(source, tag_names(), [])["tags"]:
		var written := "%s=%s" % [tag["name"], tag["value"]]
		if not _tags.has(tag["name"]):
			continue
		if written in kept:
			kept.erase(written)
		else:
			log.error(&"dialogue", "the translation of \"%s\" loses [%s]" % [source, written.trim_suffix("=")])


func _narrates(text: String) -> bool:
	for tag: Dictionary in MessageTags.split(text, tag_names(), [])["tags"]:
		if _narrating.has(tag["name"]):
			return true
	return false


static func _translated(text: String) -> String:
	return str(TranslationServer.translate(text))


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
		request.finish(request.cancelled())


## A warp or a reload closes the box; crossing a seam does not.
func _on_map_changed(_map: WgMap) -> void:
	if not _maps.is_crossing and (is_open() or _current != null):
		close()


## The choices as `{"text", "disabled"}`; checks `default` and `cancel`.
func _answers(choices: Array, options: Dictionary) -> Array[Dictionary]:
	var answers: Array[Dictionary] = []
	for choice: Variant in choices:
		if choice is Dictionary:
			answers.append({"text": str(choice.get("text", "")), "disabled": bool(choice.get("disabled", false))})
		else:
			answers.append({"text": str(choice), "disabled": false})
	var last := answers.size() - 1
	var default := int(options.get("default", 0))
	if default < 0 or default > last:
		log.warn(&"dialogue", "default %d is not a choice; using 0" % default)
		default = 0
	options["default"] = default
	var cancel := int(options.get("cancel", last))
	if cancel < -1 or cancel > last:
		log.warn(&"dialogue", "cancel %d is not a choice; using %d" % [cancel, last])
		cancel = last
	options["cancel"] = cancel
	return answers


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
