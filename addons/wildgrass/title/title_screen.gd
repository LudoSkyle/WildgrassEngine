## The title screen: black lifts and the game's arrival plays, a prompt blinks
## until a key, then the choices. Cancel comes back one step. A game's scene
## extends it, keeps its own pictures and animations, and overrides
## `_arrival()`; it points `wildgrass/screens/title` to it.
##
## Opened by `Wildgrass.title`; arguments: `title`, `dialogue`, `texts`, the
## services (the engine's).
class_name WgTitleScreen
extends WgScreen

const Title := preload("res://addons/wildgrass/title/title.gd")
const Dialogue := preload("res://addons/wildgrass/dialogue/dialogue.gd")
const Texts := preload("res://addons/wildgrass/texts/texts.gd")

enum Stage {
	## Black lifts, then the game's arrival plays.
	ARRIVAL,
	## Waiting for a key: the prompt blinks, if the config shows one.
	PROMPT,
	## The choices, taking keys after the config's `controls_delay`.
	CHOICES,
	## A choice runs.
	BUSY,
}

## Black lifts over this time, in seconds.
@export var fade_in_seconds := 0.5
## Then `_arrival()` plays over this time.
@export var arrival_seconds := 0.6
## The prompt shows this long, then hides `blink_off_seconds`.
@export var blink_on_seconds := 0.7
@export var blink_off_seconds := 0.4
## Hidden while a choice opens its screen above the title: the logo, the
## prompt.
@export var hidden_under_choice: Array[NodePath] = [^"Logo", ^"Name", ^"Prompt"]

@export_group("Nodes")
## The black over everything, lifted at the start.
@export var veil: NodePath = ^"Veil"
## A `TextureRect` showing the config's `background`.
@export var background: NodePath = ^"Background"
## A `TextureRect` showing the config's `logo`.
@export var logo: NodePath = ^"Logo"
## A `Label` showing the game's name when there is no logo.
@export var name_label: NodePath = ^"Name"
## A `Label` blinking while the title waits for a key.
@export var prompt: NodePath = ^"Prompt"
## Shown with the choices.
@export var choices_panel: NodePath = ^"Choices"
## The container the choices are added to.
@export var list: NodePath = ^"Choices/Margin/List"

@export_group("Texts")
@export var prompt_text := "Press {key:ui_accept}"

var title: Title
var dialogue: Dialogue
var texts: Texts
## Where the title stands.
var stage := Stage.ARRIVAL
## The choice under the cursor.
var cursor: StringName = &""

## Seconds into the current stage.
var _time := 0.0
## The config's `controls_delay` is waited once, the first time the choices
## show.
var _controls_ready := false
var _shown: Array[Dictionary] = []
var _buttons: Array[Button] = []


func _on_open(args: Dictionary) -> void:
	title = _service(args, &"title")
	dialogue = _service(args, &"dialogue")
	texts = _service(args, &"texts")
	if title == null or dialogue == null or texts == null:
		push_error("title screen: no title, dialogue or texts service")
		close()
		return
	_show_pictures()
	refresh()
	texts.language_changed.connect(_on_language_changed)
	_enter(Stage.ARRIVAL)


func _on_close() -> void:
	if texts != null and texts.language_changed.is_connected(_on_language_changed):
		texts.language_changed.disconnect(_on_language_changed)


func _process(delta: float) -> void:
	advance(delta)


## Moves the title on by `delta` seconds.
func advance(delta: float) -> void:
	if is_closed():
		return
	_time += delta
	match stage:
		Stage.ARRIVAL:
			_show_arrival()
			if _time >= fade_in_seconds + arrival_seconds:
				_after_arrival()
		Stage.PROMPT:
			_blink()
		Stage.CHOICES:
			if _time >= title.config().controls_delay:
				_controls_ready = true


func _on_input(event: InputEvent) -> bool:
	match stage:
		Stage.ARRIVAL:
			if dialogue.is_action(event, "confirm"):
				_after_arrival()
		Stage.PROMPT:
			if dialogue.is_action(event, "confirm"):
				_go_on()
		Stage.CHOICES:
			if not _controls_ready and _time < title.config().controls_delay:
				pass
			elif dialogue.is_action(event, "cancel"):
				if title.config().show_prompt:
					_enter(Stage.PROMPT)
			elif dialogue.is_action(event, "confirm"):
				_run(_cursor())
			elif dialogue.is_action(event, "up"):
				_move(-1)
			elif dialogue.is_action(event, "down"):
				_move(1)
	return true


## The id of the choice under the cursor.
func selected() -> StringName:
	var at := _cursor()
	return _shown[at]["id"] if at >= 0 else &""


## Shows the choices whose condition holds now.
func refresh() -> void:
	_shown = title.shown()
	var box := get_node_or_null(list)
	for button in _buttons:
		button.queue_free()
		if button.get_parent() != null:
			button.get_parent().remove_child(button)
	_buttons.clear()
	for entry in _shown:
		var button := Button.new()
		button.text = texts.label(entry["text"])
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_buttons.append(button)
		if box != null:
			box.add_child(button)
	if _cursor() < 0 and not _shown.is_empty():
		cursor = _shown[0]["id"]
	_show_cursor()
	var shown_prompt := get_node_or_null(prompt) as Label
	if shown_prompt != null:
		shown_prompt.text = texts.label(prompt_text)


## The game's arrival, `progress` from 0 to 1, once black has lifted; the
## engine's fades the logo or the name in.
func _arrival(progress: float) -> void:
	for path: NodePath in [logo, name_label]:
		var node := get_node_or_null(path) as CanvasItem
		if node != null:
			node.modulate.a = progress


func _enter(next: Stage) -> void:
	stage = next
	_time = 0.0
	var panel := get_node_or_null(choices_panel) as CanvasItem
	if panel != null:
		panel.visible = stage == Stage.CHOICES
	var shown_prompt := get_node_or_null(prompt) as CanvasItem
	if shown_prompt != null:
		shown_prompt.visible = stage == Stage.PROMPT and title.config().show_prompt
	if stage == Stage.ARRIVAL:
		_show_arrival()


func _show_arrival() -> void:
	var black := get_node_or_null(veil) as CanvasItem
	if black != null:
		black.modulate.a = 1.0 - clampf(_time / fade_in_seconds, 0.0, 1.0) if fade_in_seconds > 0.0 else 0.0
	if _time >= fade_in_seconds:
		_arrival(clampf((_time - fade_in_seconds) / arrival_seconds, 0.0, 1.0) if arrival_seconds > 0.0 else 1.0)
	else:
		_arrival(0.0)


## The arrival ends, or a key cut it short: black gone, the arrival whole.
func _after_arrival() -> void:
	var black := get_node_or_null(veil) as CanvasItem
	if black != null:
		black.modulate.a = 0.0
	_arrival(1.0)
	var settings := title.config()
	_enter(Stage.PROMPT if settings.show_prompt or not settings.show_choices else Stage.CHOICES)


## A key while the title waits: the choices, or straight to Play.
func _go_on() -> void:
	if title.config().show_choices:
		_enter(Stage.CHOICES)
	else:
		_run(_shown.find_custom(func(entry: Dictionary) -> bool: return entry["id"] == &"play"))


func _blink() -> void:
	var shown_prompt := get_node_or_null(prompt) as CanvasItem
	if shown_prompt != null and title.config().show_prompt:
		shown_prompt.visible = fmod(_time, blink_on_seconds + blink_off_seconds) < blink_on_seconds


func _cursor() -> int:
	for index in _shown.size():
		if _shown[index]["id"] == cursor:
			return index
	return -1


func _move(step: int) -> void:
	if _shown.is_empty():
		return
	cursor = _shown[wrapi(_cursor() + step, 0, _shown.size())]["id"]
	_show_cursor()


func _show_cursor() -> void:
	var at := _cursor()
	for index in _buttons.size():
		_buttons[index].set_pressed_no_signal(index == at)


## Runs the choice at `at`, the nodes of `hidden_under_choice` hidden; back to
## the stage it was run from unless it closes the title.
func _run(at: int) -> void:
	if at < 0 or not (_shown[at]["callable"] as Callable).is_valid():
		return
	var from := stage
	stage = Stage.BUSY
	var hidden := _hide_under_choice()
	var done: Variant = await (_shown[at]["callable"] as Callable).call()
	if is_closed():
		return
	for node in hidden:
		if is_instance_valid(node):
			node.visible = true
	if done is bool and done:
		close()
		return
	refresh()
	_enter(from)


## Hides the nodes of `hidden_under_choice` that show; returns them.
func _hide_under_choice() -> Array[CanvasItem]:
	var hidden: Array[CanvasItem] = []
	for path in hidden_under_choice:
		var node := get_node_or_null(path) as CanvasItem
		if node != null and node.visible:
			node.visible = false
			hidden.append(node)
	return hidden


## The config's background and logo; the name when there is no logo.
func _show_pictures() -> void:
	var settings := title.config()
	var shown_background := get_node_or_null(background) as TextureRect
	if shown_background != null and not settings.background.is_empty():
		shown_background.texture = title.load_image(settings.background, "title background")
	var shown_logo := get_node_or_null(logo) as TextureRect
	if shown_logo != null and not settings.logo.is_empty():
		shown_logo.texture = title.load_image(settings.logo, "title logo")
	var shown_name := get_node_or_null(name_label) as Label
	if shown_name != null:
		shown_name.text = settings.game_name()
		shown_name.visible = shown_logo == null or shown_logo.texture == null


func _on_language_changed(_code: String) -> void:
	refresh()


func _service(args: Dictionary, key: StringName) -> Variant:
	if args.has(key):
		return args[key]
	var engine := get_node_or_null(^"/root/Wildgrass")
	return engine.get(key) if engine != null else null
