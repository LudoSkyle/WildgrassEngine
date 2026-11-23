## The bag: its pockets, the items of one with their counts, the icon and
## description of the item under the cursor. On an item, the message box asks
## what to do: Use, Toss, Cancel. The engine's scene uses Godot's default
## theme; a game points `wildgrass/screens/bag` to its own.
##
## `Wildgrass.screens.open(&"bag")`; arguments: `pocket`, the id of the pocket
## shown first (the first one); `bag`, `dialogue`, `texts`, the services (the
## engine's).
class_name WgBagScreen
extends WgScreen

const _Bag := preload("res://addons/wildgrass/bag/bag.gd")
const _Dialogue := preload("res://addons/wildgrass/dialogue/dialogue.gd")
const _Texts := preload("res://addons/wildgrass/texts/texts.gd")

@export_group("Nodes")
## The `Label` of the pocket's name.
@export var pocket_name: NodePath = ^"Box/Pocket/Name"
## The `Tree` of the pocket's items: their names, then their counts.
@export var list: NodePath = ^"Box/List"
## The `TextureRect` of the icon of the item under the cursor.
@export var icon: NodePath = ^"Box/Details/Icon"
## The `Label` of its description.
@export var description: NodePath = ^"Box/Details/Description"
## Hidden while the message box asks, which covers it.
@export var details: NodePath = ^"Box/Details"
## The least width of the counts' column; a longer count widens it.
@export var count_width := 40

@export_group("Texts")
## Asked with the choices; `{item}` is its name.
@export_multiline var selected_text := "wg.bag.selected"
@export var use_choice := "wg.bag.use"
@export var toss_choice := "wg.bag.toss"
@export var cancel_choice := "wg.cancel"
## `{item}` is its plural name.
@export_multiline var toss_count_text := "wg.bag.toss_count"
## `{count}`, and `{item}`, its name for that count.
@export_multiline var toss_confirm_text := "wg.bag.toss_confirm"

var bag: _Bag
var dialogue: _Dialogue
var texts: _Texts
## The ids of the pockets, in order.
var pockets: Array[StringName] = []
## The id of the pocket shown.
var pocket: StringName = &""

## The cursor of each pocket.
var _cursors: Dictionary[StringName, int] = {}
var _shown: Array[StringName] = []
var _busy := false


func _on_open(args: Dictionary) -> void:
	bag = _service(args, &"bag")
	dialogue = _service(args, &"dialogue")
	texts = _service(args, &"texts")
	if bag == null or dialogue == null or texts == null:
		push_error("bag screen: no bag, dialogue or texts service")
		close()
		return
	for entry: Dictionary in bag.config().pockets:
		pockets.append(StringName(str(entry["id"])))
	if pockets.is_empty():
		bag.log.warn(&"bag", "the bag has no pocket to show")
		close()
		return
	var first := StringName(args.get("pocket", ""))
	pocket = first if first in pockets else pockets[0]
	var tree := get_node_or_null(list) as Tree
	if tree != null and tree.columns > 1:
		tree.set_column_expand(1, false)
	bag.changed.connect(_on_bag_changed)
	refresh()


func _on_close() -> void:
	if bag != null and bag.changed.is_connected(_on_bag_changed):
		bag.changed.disconnect(_on_bag_changed)


## Left and right turn a pocket at a time, held or not.
func _repeats(key: String) -> bool:
	return key == "up" or key == "down"


func _on_input(event: InputEvent) -> bool:
	if _busy:
		return true
	if dialogue.is_action(event, "cancel"):
		close()
	elif dialogue.is_action(event, "confirm"):
		_act()
	elif dialogue.is_action(event, "up"):
		_move(-1)
	elif dialogue.is_action(event, "down"):
		_move(1)
	elif dialogue.is_action(event, "left"):
		_turn(-1)
	elif dialogue.is_action(event, "right"):
		_turn(1)
	else:
		return false
	return true


## The id of the item under the cursor, or none in an empty pocket.
func selected() -> StringName:
	return &"" if _shown.is_empty() else _shown[_cursors[pocket]]


## Shows the pocket again: called whenever the bag changes.
func refresh() -> void:
	_shown = bag.items(pocket)
	_cursors[pocket] = clampi(_cursors.get(pocket, 0), 0, maxi(_shown.size() - 1, 0))
	var name_label := get_node_or_null(pocket_name) as Label
	if name_label != null:
		name_label.text = texts.label(bag.config().pocket(pocket).get("name", String(pocket)))
	var tree := get_node_or_null(list) as Tree
	if tree != null:
		tree.clear()
		var root := tree.create_item()
		var font := tree.get_theme_font(&"font")
		var font_size := tree.get_theme_font_size(&"font_size")
		var widest := float(count_width)
		for id in _shown:
			var item := bag.item(id)
			var row := tree.create_item(root)
			row.set_text(0, texts.label(item.name))
			if tree.columns > 1:
				var count := "×%d" % bag.count(id) if item.consumed else ""
				row.set_text(1, count)
				row.set_text_alignment(1, HORIZONTAL_ALIGNMENT_RIGHT)
				widest = maxf(widest, font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 2 * tree.get_theme_constant(&"h_separation"))
		if tree.columns > 1:
			tree.set_column_custom_minimum_width(1, ceili(widest))
	_show_selected()


func _move(step: int) -> void:
	if _shown.is_empty():
		return
	_cursors[pocket] = clampi(_cursors[pocket] + step, 0, _shown.size() - 1)
	_show_selected()


func _turn(step: int) -> void:
	pocket = pockets[wrapi(pockets.find(pocket) + step, 0, pockets.size())]
	refresh()


func _show_selected() -> void:
	var id := selected()
	var item := bag.item(id) if not id.is_empty() else null
	var tree := get_node_or_null(list) as Tree
	if tree != null and item != null:
		var row := tree.get_root().get_child(_cursors[pocket])
		row.select(0)
		tree.scroll_to_item(row)
	var shown_icon := get_node_or_null(icon) as TextureRect
	if shown_icon != null:
		shown_icon.texture = item.icon if item != null else null
	var shown_description := get_node_or_null(description) as Label
	if shown_description != null:
		shown_description.text = texts.label(item.description) if item != null else ""


## Asks what to do with the item under the cursor, and does it.
func _act() -> void:
	var id := selected()
	if id.is_empty():
		return
	var item := bag.item(id)
	var choices: Array = []
	var answers: Array[StringName] = []
	if bag.can_use(id):
		choices.append(use_choice)
		answers.append(&"use")
	if item.consumed:
		choices.append(toss_choice)
		answers.append(&"toss")
	choices.append(cancel_choice)
	answers.append(&"cancel")
	_busy = true
	_show_details(false)
	var picked := await dialogue.ask(selected_text, choices, {"values": {"item": item.name}})
	match answers[picked] if picked >= 0 else &"cancel":
		&"use":
			await bag.use(id)
		&"toss":
			await _toss(id, item)
	_show_details(true)
	_busy = false


func _show_details(shown: bool) -> void:
	var node := get_node_or_null(details) as CanvasItem
	if node != null:
		node.visible = shown


## How many, unless there is one, then Yes or No.
func _toss(id: StringName, item: WgItem) -> void:
	var count := 1
	if bag.count(id) > 1:
		var asked: Variant = await dialogue.ask_number(toss_count_text, {"min": 1, "max": bag.count(id), "default": 1, "values": {"item": item.name_for(2)}})
		if asked == null:
			return
		count = asked
	if await dialogue.confirm(toss_confirm_text, {"values": {"item": item.name_for(count), "count": count}}):
		bag.remove(id, count)


func _on_bag_changed(_id: StringName, _count: int) -> void:
	refresh()


func _service(args: Dictionary, key: StringName) -> Variant:
	if args.has(key):
		return args[key]
	var engine := get_node_or_null(^"/root/Wildgrass")
	return engine.get(key) if engine != null else null
