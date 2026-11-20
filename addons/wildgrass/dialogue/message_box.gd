## The box messages are written in, letter by letter, page by page. The
## engine's scene uses Godot's default theme; a game inherits it, restyles it,
## and points `wildgrass/screens/message_box` to its own.
class_name WgMessageBox
extends WgScreen

const MessageTags := preload("res://addons/wildgrass/dialogue/message_tags.gd")

enum State { IDLE, WRITING, WAITING_KEY, PAGE_WRITTEN, SCROLLING, WRITTEN, HELD, CHOOSING, NUMBER }

@export_group("Nodes")
## The box's frame; `style` sets its `theme_type_variation`.
@export var frame: NodePath = ^"Frame"
## The `RichTextLabel` the text is written in.
@export var text: NodePath = ^"Frame/Margin/Text"
## Shown with the speaker's name; optional.
@export var speaker: NodePath = ^"Speaker"
## The `Label` of the speaker's name.
@export var speaker_name: NodePath = ^"Speaker/Name"
## A `TextureRect` showing the portrait; optional.
@export var portrait: NodePath = ^"Portrait"
## Shown while a written page waits for the key; optional.
@export var waiting: NodePath = ^"Waiting"
## A container of the choices of a question, holding one Button as a model;
## optional.
@export var choices: NodePath = ^"Choices"
## Shown with the number asked by `ask_number()`; optional.
@export var number: NodePath = ^"Number"
## The `Label` of that number.
@export var number_value: NodePath = ^"Number/Value"
@export_group("")
## Places the frame by `place`, and the speaker, portrait and marker around
## it. Off: the scene's own layout is kept.
@export var arrange := true
## Gap between the frame and the edge of the screen, in game pixels.
@export var margin := 4.0

## The dialogue service that opened the box.
var dialogue: RefCounted
var state := State.IDLE

var _frame: Control
var _text: RichTextLabel
var _speaker: Control
var _number: Control
var _number_value: Label
## `{"min", "max", "default"}` while a number is asked.
var _range: Dictionary = {}
var _value := 0
var _speaker_name: Label
var _portrait: TextureRect
var _waiting: CanvasItem
var _frame_height := 0.0
var _options: Dictionary = {}
var _choices: Control
var _model: Button
var _buttons: Array[Button] = []
## Each `{"text", "disabled"}`.
var _answers: Array[Dictionary] = []
var _selected := 0
var _first_shown := 0
## Choices shown at once.
var _room := 1
## Each `{"at": character, "name", "value"}`, in order.
var _tags: Array[Dictionary] = []
var _tag_index := 0
## Characters where `[page]` starts a page.
var _breaks: Array[int] = []
var _total := 0
var _lines := 0
var _shown := 0
var _carry := 0.0
var _pause := 0.0
var _speed := 1.0
var _blocked := false
## Set when a tag changes how fast writing goes, so the time left is counted again.
var _retimed := false
var _auto_left := 0.0
var _top := 0
var _bottom := 0
var _page_end := 0
var _scroll_target := 0.0
var _scroll_position := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame = get_node_or_null(frame) as Control
	_text = get_node_or_null(text) as RichTextLabel
	_speaker = get_node_or_null(speaker) as Control
	_speaker_name = get_node_or_null(speaker_name) as Label
	_portrait = get_node_or_null(portrait) as TextureRect
	_waiting = get_node_or_null(waiting) as CanvasItem
	_choices = get_node_or_null(choices) as Control
	_number = get_node_or_null(number) as Control
	_number_value = get_node_or_null(number_value) as Label
	if _number != null:
		_number.hide()
	if _choices != null:
		for child: Node in _choices.get_children():
			if child is Button:
				_model = child
				break
		if _model != null:
			_choices.remove_child(_model)
		_choices.hide()
	if _frame == null or _text == null:
		push_error("%s: a message box needs a frame and a RichTextLabel" % name)
		return
	_frame_height = _frame.size.y
	_frame.gui_input.connect(_on_frame_input)
	_text.bbcode_enabled = true
	_text.scroll_active = false
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_text.mouse_filter = Control.MOUSE_FILTER_PASS
	for optional: CanvasItem in [_speaker, _portrait, _waiting]:
		if optional != null:
			optional.hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_model):
		_model.free()


func _on_open(args: Dictionary) -> void:
	dialogue = args.get("dialogue")


func _process(delta: float) -> void:
	advance(delta)


## Starts writing `message`, with the options of `say()`. `answers`, each
## `{"text", "disabled"}`, are shown once it is written: a question. Texts come
## translated and formatted.
func show_message(message: String, options: Dictionary, answers: Array[Dictionary] = [], asked: Dictionary = {}) -> void:
	if _text == null:
		dialogue._message_done(null if not asked.is_empty() else (int(options.get("cancel", -1)) if not answers.is_empty() else 0))
		return
	_options = options
	_answers = answers
	_range = asked
	_close_choices()
	if _number != null:
		_number.hide()
	_dress()
	var split := MessageTags.split(message, dialogue.tag_names(), _effect_tags())
	for tag_name: String in split["unknown"]:
		dialogue.log.warn(&"dialogue", "unknown tag [%s] in \"%s\"" % [tag_name, message])
	_tags.clear()
	_breaks.clear()
	var counter := RichTextLabel.new()
	counter.bbcode_enabled = true
	for tag: Dictionary in split["tags"]:
		counter.text = (split["text"] as String).left(tag["index"])
		var at := counter.get_total_character_count()
		_tags.append({"at": at, "name": tag["name"], "value": tag["value"]})
		if tag["name"] == "page" and at > 0:
			_breaks.append(at)
	counter.free()
	_text.text = split["text"]
	_total = _text.get_total_character_count()
	_lines = 0 if _total == 0 else _text.get_character_line(_total - 1) + 1
	# Blank lines below the text, so that its last line can scroll to the top.
	_text.text = split["text"] + "\n".repeat(_padding())
	_tag_index = 0
	_shown = 0
	_carry = 0.0
	_pause = 0.0
	_speed = 1.0
	_blocked = false
	_top = 0
	_show_waiting(false)
	_open_window()
	state = State.WRITING
	dialogue.page_shown.emit()
	_write(0.0)


## Moves writing on by `delta` seconds.
func advance(delta: float) -> void:
	match state:
		State.WRITING:
			_write(delta)
		State.SCROLLING:
			_scroll(delta)
		State.WRITTEN:
			if _auto_left > 0.0:
				_auto_left -= delta
				if _auto_left <= 0.0:
					_end()


## The confirm action, or a click on the box.
func confirm() -> void:
	match state:
		State.WRITING:
			if not _blocked:
				_carry = 0.0
				_pause = 0.0
				_run(_total, true)
		State.WAITING_KEY:
			_show_waiting(false)
			state = State.WRITING
			dialogue.advanced.emit()
			_write(0.0)
		State.PAGE_WRITTEN:
			_show_waiting(false)
			dialogue.advanced.emit()
			_next_page()
		State.WRITTEN:
			if _options.get("locked", false):
				return
			dialogue.advanced.emit()
			_end()


## The text as the player sees it: the characters written, on the lines shown.
func shown_text() -> String:
	if _text == null or _lines == 0:
		return ""
	var from := _text.get_line_range(_top).x
	return _text.get_parsed_text().substr(from, maxi(_shown - from, 0)).strip_edges()


func _on_input(event: InputEvent) -> bool:
	if dialogue == null:
		return false
	if state == State.NUMBER:
		if dialogue.is_action(event, "confirm"):
			_answer_number(_value)
		elif dialogue.is_action(event, "cancel"):
			_answer_number(null)
		elif dialogue.is_action(event, "up"):
			_set_value(_value + 1)
		elif dialogue.is_action(event, "down"):
			_set_value(_value - 1)
		elif dialogue.is_action(event, "right"):
			_set_value(_value + 10)
		elif dialogue.is_action(event, "left"):
			_set_value(_value - 10)
		else:
			return false
		return true
	if state == State.CHOOSING:
		if dialogue.is_action(event, "confirm"):
			_pick(_selected)
		elif dialogue.is_action(event, "cancel"):
			if int(_options["cancel"]) >= 0:
				_answer(int(_options["cancel"]))
		elif dialogue.is_action(event, "up"):
			_select(posmod(_selected - 1, _answers.size()))
		elif dialogue.is_action(event, "down"):
			_select(posmod(_selected + 1, _answers.size()))
		else:
			return false
		return true
	if dialogue.is_action(event, "confirm"):
		confirm()
		return true
	if _options.get("walk_away", false) and state != State.IDLE:
		var direction: Vector2i = dialogue.direction_of(event)
		if direction != Vector2i.ZERO:
			if direction != dialogue.facing():
				_end()
			return true
	return false


func _on_frame_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		confirm()
		accept_event()


func _write(delta: float) -> void:
	var left := delta
	for _round in 1000:
		if state != State.WRITING or _blocked:
			return
		if _pause > 0.0:
			if left < _pause:
				_pause -= left
				return
			left -= _pause
			_pause = 0.0
		var rate: float = dialogue.letters_per_second * _speed
		if rate <= 0.0:
			_run(_total, true)
			continue
		_carry += left * rate
		left = 0.0
		var before := _shown
		_retimed = false
		_run(_shown + floori(_carry), false)
		_carry -= _shown - before
		if not _retimed:
			if state != State.WRITING:
				_carry = 0.0
			return
		# A pause or a new speed: the letters not written give their time back.
		left = _carry / rate
		_carry = 0.0


## Writes up to `limit` characters, acting on the tags met on the way; stops
## at a tag that holds writing, or at the end of the lines shown.
func _run(limit: int, skipping: bool) -> void:
	while true:
		while _tag_index < _tags.size():
			var tag := _tags[_tag_index]
			if tag["at"] > _shown or (tag["at"] >= _page_end and _bottom < _lines - 1):
				break
			_tag_index += 1
			if _act(tag, skipping):
				return
		if _shown >= _page_end:
			_page_written()
			return
		if _shown >= limit:
			return
		_shown += 1
		_text.visible_characters = _shown


## Acts on a tag. True if writing stops there.
func _act(tag: Dictionary, skipping: bool) -> bool:
	var value: String = tag["value"]
	match tag["name"]:
		"page":
			return false
		"pause":
			if skipping:
				return false
			_pause = maxf(value.to_float(), 0.0)
			_retimed = _pause > 0.0
			return _retimed
		"speed":
			_speed = value.to_float() if value.to_float() > 0.0 else 1.0
			_retimed = not skipping
			return _retimed
		"wait":
			state = State.WAITING_KEY
			_show_waiting(true)
			return true
	var result: Variant = dialogue.run_tag(tag["name"], value)
	if result is Signal and not (result as Signal).is_null():
		_blocked = true
		(result as Signal).connect(_on_tag_done, CONNECT_ONE_SHOT)
		return true
	return false


func _on_tag_done(..._args: Array) -> void:
	_blocked = false
	_write(0.0)


func _page_written() -> void:
	if _bottom < _lines - 1:
		state = State.PAGE_WRITTEN
		_show_waiting(true)
		return
	if not _answers.is_empty():
		state = State.CHOOSING
		_open_choices()
		return
	if not _range.is_empty():
		_open_number()
		return
	if _options.get("hold", false):
		state = State.HELD
		dialogue._message_done(0)
		return
	state = State.WRITTEN
	_auto_left = float(_options.get("auto", 0.0))
	_show_waiting(_auto_left <= 0.0)


func _end() -> void:
	state = State.IDLE
	_show_waiting(false)
	dialogue._message_done(0)


func _open_choices() -> void:
	if _choices == null or _model == null:
		dialogue.log.error(&"dialogue", "%s: no choices to show a question in" % name)
		_answer(int(_options["cancel"]))
		return
	for index in _answers.size():
		var button := _model.duplicate() as Button
		button.text = _answers[index]["text"]
		button.disabled = _answers[index]["disabled"]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.pressed.connect(_pick.bind(index))
		_choices.add_child(button)
		_buttons.append(button)
	_choices.show()
	_room = dialogue.config().max_choices
	if arrange:
		_room = mini(_room, _rows_that_fit())
	_first_shown = 0
	_select(clampi(int(_options.get("default", 0)), 0, _answers.size() - 1), false)
	if arrange:
		_place_choices()


func _close_choices() -> void:
	for button in _buttons:
		button.queue_free()
		_choices.remove_child(button)
	_buttons.clear()
	if _choices != null:
		_choices.hide()


## Selects a choice, keeping it among those shown.
func _select(index: int, announce := true) -> void:
	_selected = index
	var room := _room
	if _selected < _first_shown:
		_first_shown = _selected
	elif _selected >= _first_shown + room:
		_first_shown = _selected - room + 1
	for i in _buttons.size():
		_buttons[i].visible = i >= _first_shown and i < _first_shown + room
		_buttons[i].set_pressed_no_signal(i == _selected)
	if announce:
		dialogue.choice_moved.emit(_selected)


func _pick(index: int) -> void:
	if state != State.CHOOSING:
		return
	if _answers[index]["disabled"]:
		_buttons[index].set_pressed_no_signal(index == _selected)
		dialogue.choice_refused.emit(index)
		return
	dialogue.choice_made.emit(index)
	_answer(index)


func _answer(index: int) -> void:
	state = State.IDLE
	_close_choices()
	dialogue._message_done(index)


## Rows of choices between the frame and the edge of the screen, at least one.
func _rows_that_fit() -> int:
	var row := _buttons[0].get_combined_minimum_size().y
	var gap := float(_choices.get_theme_constant(&"separation")) if _choices is BoxContainer else 0.0
	var area := _frame.get_rect()
	var below := str(_options.get("place", "bottom")) == "top"
	var space := (size.y - area.end.y if below else area.position.y) - margin
	return maxi(1, floori((space + gap) / (row + gap)))


## Against the frame's right edge: above it, below when the box is at the top.
func _place_choices() -> void:
	_place_beside(_choices)


func _place_beside(node: Control) -> void:
	node.reset_size()
	var area := _frame.get_rect()
	var below := str(_options.get("place", "bottom")) == "top"
	node.position = Vector2(area.end.x - node.size.x, area.end.y if below else area.position.y - node.size.y)


func _open_number() -> void:
	if _number == null or _number_value == null:
		dialogue.log.error(&"dialogue", "%s: no number to ask in" % name)
		_answer_number(null)
		return
	state = State.NUMBER
	_value = _range["default"]
	_number_value.text = str(_value)
	_number.show()
	if arrange:
		_place_beside(_number)


## Moves the number, wrapping round its range.
func _set_value(wanted: int) -> void:
	var low: int = _range["min"]
	_value = low + posmod(wanted - low, int(_range["max"]) - low + 1)
	_number_value.text = str(_value)


func _answer_number(value: Variant) -> void:
	state = State.IDLE
	if _number != null:
		_number.hide()
	dialogue._message_done(value)


func _next_page() -> void:
	var next := _bottom + 1
	if dialogue.config().advance == WgDialogueConfig.Advance.SCROLL and _line_start(next) not in _breaks:
		state = State.SCROLLING
		_scroll_position = _text.get_line_offset(_top)
		_scroll_target = _text.get_line_offset(_top + 1)
		return
	_top = next
	_open_window()
	state = State.WRITING
	dialogue.page_shown.emit()
	_write(0.0)


## Slides the lines up; the scrollbar keeps whole pixels, the position its
## fraction.
func _scroll(delta: float) -> void:
	_scroll_position = move_toward(_scroll_position, _scroll_target, dialogue.config().scroll_speed * delta)
	_text.get_v_scroll_bar().value = _scroll_position
	if _scroll_position < _scroll_target:
		return
	_top += 1
	_fit_window()
	state = State.WRITING
	dialogue.page_shown.emit()
	_write(0.0)


## Shows the lines from `_top` on, scrolled to the top of the text.
func _open_window() -> void:
	_fit_window()
	if _lines > 0:
		_text.scroll_to_line(_top)


## The lines from `_top` that fit, up to a `[page]`.
func _fit_window() -> void:
	_bottom = _top
	if _lines == 0:
		_page_end = 0
		return
	var room := _text.get_v_scroll_bar().page
	var start := _text.get_line_offset(_top)
	while _bottom + 1 < _lines:
		var next := _bottom + 1
		if _line_start(next) in _breaks or _text.get_line_offset(next) + _text.get_line_height(next) - start > room + 0.5:
			break
		_bottom = next
	_page_end = _total if _bottom == _lines - 1 else _text.get_line_range(_bottom).y
	_shown = maxi(_shown, _line_start(_top))
	_text.visible_characters = _shown


func _line_start(line: int) -> int:
	return _text.get_line_range(line).x


## Blank lines enough to fill the box below the last line.
func _padding() -> int:
	var line_height := maxf(_text.get_line_height(0), 1.0) if _lines > 0 else 1.0
	return ceili(_text.get_v_scroll_bar().page / line_height) + 1


## Speaker, portrait, style and place, then the layout, so that lines are
## counted at the box's real size.
func _dress() -> void:
	var speaker_text := str(_options.get("speaker", ""))
	if _speaker != null:
		_speaker.visible = not speaker_text.is_empty()
	if _speaker_name != null:
		_speaker_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_speaker_name.text = speaker_text
		if _options.has("speaker_color"):
			_speaker_name.add_theme_color_override(&"font_color", _options["speaker_color"])
		else:
			_speaker_name.remove_theme_color_override(&"font_color")
	if _portrait != null:
		_portrait.texture = _options.get("portrait") as Texture2D
		_portrait.visible = _portrait.texture != null
	var style := str(_options.get("style", ""))
	_frame.theme_type_variation = StringName("MessageFrame_" + style) if not style.is_empty() else &""
	if arrange:
		_arrange(str(_options.get("place", "bottom")))
	var node: Node = _text.get_parent()
	var containers: Array[Container] = []
	while node != null and node != self:
		if node is Container:
			containers.push_front(node)
		node = node.get_parent()
	for container in containers:
		container.notification(Container.NOTIFICATION_SORT_CHILDREN)


func _arrange(place: String) -> void:
	_frame.anchor_left = 0.0
	_frame.anchor_right = 1.0
	_frame.offset_left = margin
	_frame.offset_right = -margin
	match place:
		"top":
			_frame.anchor_top = 0.0
			_frame.anchor_bottom = 0.0
			_frame.offset_top = margin
			_frame.offset_bottom = margin + _frame_height
		"middle":
			_frame.anchor_top = 0.5
			_frame.anchor_bottom = 0.5
			_frame.offset_top = -_frame_height / 2.0
			_frame.offset_bottom = _frame_height / 2.0
		_:
			_frame.anchor_top = 1.0
			_frame.anchor_bottom = 1.0
			_frame.offset_top = -margin - _frame_height
			_frame.offset_bottom = -margin
	var area := _frame.get_rect()
	var below := place == "top"
	var x := area.position.x + margin
	if _portrait != null and _portrait.visible:
		_portrait.position = Vector2(x, area.end.y if below else area.position.y - _portrait.size.y)
		x += _portrait.size.x + margin
	if _speaker != null and _speaker.visible:
		_speaker.reset_size()
		_speaker.position = Vector2(x, area.end.y if below else area.position.y - _speaker.size.y)
	if _waiting is Control:
		var marker := _waiting as Control
		marker.position = area.end - marker.size - Vector2(margin, margin)


func _show_waiting(shown: bool) -> void:
	if _waiting != null:
		_waiting.visible = shown


func _effect_tags() -> Array:
	var names := []
	for effect: Variant in _text.custom_effects:
		if effect is RichTextEffect and effect.get(&"bbcode") != null:
			names.append(str(effect.get(&"bbcode")))
	return names
