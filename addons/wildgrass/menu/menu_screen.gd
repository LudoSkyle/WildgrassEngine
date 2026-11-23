## The pause menu's screen: a column of the entries shown, against the top
## right corner. Up and down move round, confirm runs the entry, cancel closes
## it. The engine's scene uses Godot's default theme; a game points
## `wildgrass/screens/menu` to its own.
##
## Opened by `Wildgrass.menu.open()`; arguments: `menu`, `dialogue`, `texts`,
## the services (the engine's).
class_name WgMenuScreen
extends WgScreen

const _Menu := preload("res://addons/wildgrass/menu/menu.gd")
const _Dialogue := preload("res://addons/wildgrass/dialogue/dialogue.gd")
const _Texts := preload("res://addons/wildgrass/texts/texts.gd")

@export_group("Nodes")
## The container the entries are added to.
@export var list: NodePath = ^"Panel/Margin/Entries"

var menu: _Menu
var dialogue: _Dialogue
var texts: _Texts

## The entries shown, in order.
var _shown: Array[Dictionary] = []
var _buttons: Array[Button] = []
var _busy := false


func _on_open(args: Dictionary) -> void:
	menu = _service(args, &"menu")
	dialogue = _service(args, &"dialogue")
	texts = _service(args, &"texts")
	if menu == null or dialogue == null or texts == null:
		push_error("menu screen: no menu, dialogue or texts service")
		close()
		return
	refresh()
	texts.language_changed.connect(_on_language_changed)


func _on_close() -> void:
	if texts != null and texts.language_changed.is_connected(_on_language_changed):
		texts.language_changed.disconnect(_on_language_changed)


func _on_input(event: InputEvent) -> bool:
	if _busy:
		return true
	if dialogue.is_action(event, "cancel"):
		close()
	elif dialogue.is_action(event, "confirm"):
		_run()
	elif dialogue.is_action(event, "up"):
		_move(-1)
	elif dialogue.is_action(event, "down"):
		_move(1)
	else:
		return false
	return true


## The id of the entry under the cursor.
func selected() -> StringName:
	var at := _cursor()
	return _shown[at]["id"] if at >= 0 else &""


## Shows the entries whose condition holds now.
func refresh() -> void:
	_shown = menu.shown()
	var box := get_node_or_null(list)
	for button in _buttons:
		button.queue_free()
		if button.get_parent() != null:
			button.get_parent().remove_child(button)
	_buttons.clear()
	# A scene without a list shows its choices its own way: no button left
	# without a parent.
	for entry in _shown if box != null else []:
		var button := Button.new()
		button.text = texts.label(entry["text"])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_buttons.append(button)
		box.add_child(button)
	if _cursor() < 0 and not _shown.is_empty():
		menu.cursor = _shown[0]["id"]
	_show_cursor()


func _cursor() -> int:
	for index in _shown.size():
		if _shown[index]["id"] == menu.cursor:
			return index
	return -1


func _move(step: int) -> void:
	if _shown.is_empty():
		return
	menu.cursor = _shown[wrapi(_cursor() + step, 0, _shown.size())]["id"]
	_show_cursor()


func _show_cursor() -> void:
	var at := _cursor()
	for index in _buttons.size():
		_buttons[index].set_pressed_no_signal(index == at)


func _run() -> void:
	var at := _cursor()
	if at < 0:
		return
	var callable: Callable = _shown[at]["callable"]
	if not callable.is_valid():
		return
	_busy = true
	var done: Variant = await callable.call()
	_busy = false
	if is_closed():
		return
	if done is bool and done:
		close()
	else:
		refresh()


func _on_language_changed(_code: String) -> void:
	refresh()


func _service(args: Dictionary, key: StringName) -> Variant:
	if args.has(key):
		return args[key]
	var engine := get_node_or_null(^"/root/Wildgrass")
	return engine.get(key) if engine != null else null
