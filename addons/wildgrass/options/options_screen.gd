## The options: a row per option shown, its name and value, and the
## description of the one under the cursor. Up and down move, left and right
## change the value, applied and kept at once; cancel closes it. The engine's
## scene uses Godot's default theme; a game points `wildgrass/screens/options`
## to its own.
##
## `Wildgrass.screens.open(&"options")`; arguments: `options`, `dialogue`,
## `texts`, the services (the engine's).
class_name WgOptionsScreen
extends WgScreen

const _Options := preload("res://addons/wildgrass/options/options.gd")
const _Dialogue := preload("res://addons/wildgrass/dialogue/dialogue.gd")
const _Texts := preload("res://addons/wildgrass/texts/texts.gd")

@export_group("Nodes")
## The `Tree` of the options: their names, then their values.
@export var list: NodePath = ^"Box/List"
## The `Label` of the description of the option under the cursor.
@export var description: NodePath = ^"Box/Description"
## The width of the values' column.
@export var value_width := 110

@export_group("Texts")
## Said in the frame chosen when confirm is pressed on `message_frame`.
@export_multiline var frame_sample_text := "wg.options.frame_sample"

var options: _Options
var dialogue: _Dialogue
var texts: _Texts
## The ids of the options shown, in order.
var rows: Array[StringName] = []
## The index of the row under the cursor.
var cursor := 0


func _on_open(args: Dictionary) -> void:
	options = _service(args, &"options")
	dialogue = _service(args, &"dialogue")
	texts = _service(args, &"texts")
	if options == null or dialogue == null or texts == null:
		push_error("options screen: no options, dialogue or texts service")
		close()
		return
	var tree := get_node_or_null(list) as Tree
	if tree != null and tree.columns > 1:
		tree.set_column_expand(1, false)
		tree.set_column_custom_minimum_width(1, value_width)
	texts.language_changed.connect(_on_language_changed)
	refresh()


func _on_close() -> void:
	if texts != null and texts.language_changed.is_connected(_on_language_changed):
		texts.language_changed.disconnect(_on_language_changed)


func _on_input(event: InputEvent) -> bool:
	if dialogue.is_action(event, "cancel"):
		close()
	elif dialogue.is_action(event, "confirm"):
		_sample()
	elif dialogue.is_action(event, "up"):
		_move(-1)
	elif dialogue.is_action(event, "down"):
		_move(1)
	elif dialogue.is_action(event, "left"):
		_change(-1)
	elif dialogue.is_action(event, "right"):
		_change(1)
	else:
		return false
	return true


## The id of the option under the cursor.
func selected() -> StringName:
	return rows[cursor] if cursor < rows.size() else &""


## Writes the rows again: the options shown, their names and values.
func refresh() -> void:
	rows = options.shown()
	cursor = clampi(cursor, 0, maxi(rows.size() - 1, 0))
	var tree := get_node_or_null(list) as Tree
	if tree != null:
		tree.clear()
		var root := tree.create_item()
		for id in rows:
			var row := tree.create_item(root)
			row.set_text(0, texts.label(str(options.option(id).get("name", id))))
			if tree.columns > 1:
				row.set_text(1, texts.label(options.text_of(id)))
				row.set_text_alignment(1, HORIZONTAL_ALIGNMENT_RIGHT)
	_show_cursor()


func _move(step: int) -> void:
	if rows.is_empty():
		return
	cursor = clampi(cursor + step, 0, rows.size() - 1)
	_show_cursor()


## The next value, round the values; a slider stops at its ends.
func _change(step: int) -> void:
	var id := selected()
	if id.is_empty():
		return
	var values := options.values_of(id)
	var at := values.find(options.value(id))
	var next := clampi(at + step, 0, values.size() - 1) if options.option(id).get("slider", false) else wrapi(at + step, 0, values.size())
	if next != at:
		options.set_value(id, values[next])
		refresh()


func _show_cursor() -> void:
	var tree := get_node_or_null(list) as Tree
	if tree != null and cursor < rows.size():
		var row := tree.get_root().get_child(cursor)
		row.select(0)
		tree.scroll_to_item(row)
	var shown := get_node_or_null(description) as Label
	if shown != null:
		shown.text = texts.label(str(options.option(selected()).get("description", ""))) if not rows.is_empty() else ""


## On `message_frame`, a message in the frame chosen, already applied.
func _sample() -> void:
	if selected() == &"message_frame":
		dialogue.say(frame_sample_text)


func _on_language_changed(_code: String) -> void:
	refresh()


func _service(args: Dictionary, key: StringName) -> Variant:
	if args.has(key):
		return args[key]
	var engine := get_node_or_null(^"/root/Wildgrass")
	return engine.get(key) if engine != null else null
