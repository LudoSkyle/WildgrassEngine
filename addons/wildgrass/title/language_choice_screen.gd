## The language, asked at first launch: a column of the languages by their
## names. Up and down move round, confirm picks one; there is no going back.
## The engine's scene uses Godot's default theme; a game points
## `wildgrass/screens/language_choice` to its own.
##
## Opened by `Wildgrass.title`; arguments: `languages` (codes), `texts`,
## `dialogue` (the engine's).
class_name WgLanguageChoiceScreen
extends WgScreen

const _Dialogue := preload("res://addons/wildgrass/dialogue/dialogue.gd")
const _Texts := preload("res://addons/wildgrass/texts/texts.gd")

## Emitted with the code picked, just before the screen closes.
signal chosen(code: String)

@export_group("Nodes")
## The container the languages are added to.
@export var list: NodePath = ^"Panel/Margin/Languages"

var dialogue: _Dialogue
var texts: _Texts
## The codes shown, in order.
var languages: Array[String] = []
## The index of the language under the cursor.
var cursor := 0

var _buttons: Array[Button] = []


func _on_open(args: Dictionary) -> void:
	dialogue = _service(args, &"dialogue")
	texts = _service(args, &"texts")
	languages.assign(args.get("languages", []))
	if dialogue == null or texts == null or languages.is_empty():
		push_error("language choice screen: no dialogue, texts or languages")
		close()
		return
	var box := get_node_or_null(list)
	for code in languages:
		var button := Button.new()
		button.text = texts.language_name(code)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_buttons.append(button)
		if box != null:
			box.add_child(button)
	cursor = maxi(languages.find(texts.language), 0)
	_show_cursor()


func _on_input(event: InputEvent) -> bool:
	if dialogue.is_action(event, "confirm"):
		chosen.emit(languages[cursor])
		close()
	elif dialogue.is_action(event, "up"):
		_move(-1)
	elif dialogue.is_action(event, "down"):
		_move(1)
	return true


## The code under the cursor.
func selected() -> String:
	return languages[cursor]


func _move(step: int) -> void:
	cursor = wrapi(cursor + step, 0, languages.size())
	_show_cursor()


func _show_cursor() -> void:
	for index in _buttons.size():
		_buttons[index].set_pressed_no_signal(index == cursor)


func _service(args: Dictionary, key: StringName) -> Variant:
	if args.has(key):
		return args[key]
	var engine := get_node_or_null(^"/root/Wildgrass")
	return engine.get(key) if engine != null else null
