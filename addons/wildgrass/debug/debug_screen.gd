## The debug tools' screen: a page at a time, its lines then Back, in a
## column against the top left corner that scrolls with the cursor. Up and
## down move round, confirm runs a tool or opens a page, cancel goes back a
## page, and from the first closes. The engine's scene uses Godot's default
## theme; a game points `wildgrass/screens/debug` to its own.
##
## Opened by `Wildgrass.debug`; arguments: `debug`, `dialogue`, `texts`.
class_name WgDebugScreen
extends WgScreen

const _Debug := preload("res://addons/wildgrass/debug/debug.gd")
const _Dialogue := preload("res://addons/wildgrass/dialogue/dialogue.gd")
const _Texts := preload("res://addons/wildgrass/texts/texts.gd")

@export_group("Nodes")
## The page's title.
@export var title: NodePath = ^"Panel/Margin/Column/Title"
## Scrolls the lines.
@export var scroll: NodePath = ^"Panel/Margin/Column/Scroll"
## The container the lines are added to.
@export var list: NodePath = ^"Panel/Margin/Column/Scroll/Lines"

## True once a tool closed the screen: what it asked runs over the game.
var closed_by_tool := false
var debug: _Debug
var dialogue: _Dialogue
var texts: _Texts
## The pages open, the last shown: each {"title", "page"} or {"title",
## "lines"} (a callable).
var pages: Array[Dictionary] = []
## The line under the cursor on the page shown.
var cursor := 0

var _shown: Array[Dictionary] = []
var _buttons: Array[Button] = []
var _busy := false


func _on_open(args: Dictionary) -> void:
	debug = args.get(&"debug") as _Debug
	dialogue = _service(args, &"dialogue")
	texts = _service(args, &"texts")
	if debug == null or dialogue == null or texts == null:
		push_error("debug screen: no debug, dialogue or texts service")
		close()
		return
	var first := debug.first_page()
	pages.append({"title": debug.title_of(first), "page": first})
	refresh()


func _on_input(event: InputEvent) -> bool:
	if _busy:
		return true
	if dialogue.is_action(event, "cancel"):
		back()
	elif dialogue.is_action(event, "confirm"):
		_run()
	elif dialogue.is_action(event, "up"):
		_move(-1)
	elif dialogue.is_action(event, "down"):
		_move(1)
	else:
		return false
	return true


## Back a page; from the first, closes.
func back() -> void:
	if pages.size() <= 1:
		close()
		return
	pages.pop_back()
	cursor = 0
	refresh()


## The labels of the lines shown, Back last.
func labels() -> Array[String]:
	var found: Array[String] = []
	for button in _buttons:
		found.append(button.text)
	return found


## Shows the page on top: its lines read again, then Back.
func refresh() -> void:
	var page: Dictionary = pages.back()
	_shown.clear()
	if page.has("page"):
		_shown.assign(debug.lines(page["page"]))
	else:
		var made: Variant = (page["lines"] as Callable).call()
		for line: Variant in made if made is Array else []:
			if line is Dictionary:
				_shown.append(line)
	_shown.append({"id": &"back", "label": "wg.back"})
	var heading := get_node_or_null(title) as Label
	if heading != null:
		heading.text = debug.label_of({"label": page["title"]}, texts)
	var box := get_node_or_null(list)
	for button in _buttons:
		button.queue_free()
		if button.get_parent() != null:
			button.get_parent().remove_child(button)
	_buttons.clear()
	for line in _shown:
		var button := Button.new()
		button.text = debug.label_of(line, texts)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_buttons.append(button)
		if box != null:
			box.add_child(button)
	cursor = clampi(cursor, 0, _shown.size() - 1)
	_show_cursor()


func _move(step: int) -> void:
	cursor = wrapi(cursor + step, 0, _shown.size())
	_show_cursor()


func _show_cursor() -> void:
	for index in _buttons.size():
		_buttons[index].set_pressed_no_signal(index == cursor)
	var scroller := get_node_or_null(scroll) as ScrollContainer
	if scroller != null and cursor < _buttons.size():
		_follow.call_deferred(scroller, _buttons[cursor])


## Scrolls the cursor's line into view, once the column is laid out.
func _follow(scroller: ScrollContainer, button: Button) -> void:
	if is_instance_valid(scroller) and is_instance_valid(button) and button.is_inside_tree():
		scroller.ensure_control_visible(button)


func _run() -> void:
	var line: Dictionary = _shown[cursor]
	if line.get("id") == &"back":
		back()
		return
	if not StringName(str(line.get("opens", ""))).is_empty():
		pages.append({"title": line["label"], "page": line["opens"]})
		cursor = 0
		refresh()
		return
	if line.get("lines") is Callable and (line["lines"] as Callable).is_valid() and not line.has("action"):
		pages.append({"title": line["label"], "lines": line["lines"]})
		cursor = 0
		refresh()
		return
	var action: Variant = line.get("action")
	if not action is Callable or not (action as Callable).is_valid():
		return
	_busy = true
	var stay: Variant = await (action as Callable).call()
	_busy = false
	if is_closed():
		return
	if stay is bool and stay:
		refresh()
	else:
		closed_by_tool = true
		close()


func _service(args: Dictionary, key: StringName) -> Variant:
	if args.has(key):
		return args[key]
	var engine := get_node_or_null(^"/root/Wildgrass")
	return engine.get(key) if engine != null else null
