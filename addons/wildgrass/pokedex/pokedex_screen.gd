## The Pokédex: a row per species of the Pokédex shown, its number and name
## once seen, and beside it the species under the cursor and the counts. Up
## and down move one row, going round; left and right ten; confirm opens the
## entry of a species seen; cancel closes. The engine's scene uses Godot's
## default theme; a game's extends it (`_make_row()`, `_show_selected()`,
## `_show_species()`) and points `wildgrass/screens/pokedex` to it.
##
## Opened by the pause menu; arguments: `pokedex`, `species`, `texts`,
## `dialogue`, the services (the engine's).
class_name WgPokedexScreen
extends WgScreen

const Pokedex := preload("res://addons/wildgrass/pokedex/pokedex.gd")
const SpeciesData := preload("res://addons/wildgrass/pokemon/species_data.gd")
const Dialogue := preload("res://addons/wildgrass/dialogue/dialogue.gd")
const Texts := preload("res://addons/wildgrass/texts/texts.gd")

## True: the list stops at the last species seen; nothing seen, every row.
@export var hide_after_last_seen := true
## Rows left and right move.
@export var page := 10

@export_group("Nodes")
## The `ScrollContainer` of the rows.
@export var scroll: NodePath = ^"List"
## The container the rows are added to.
@export var list: NodePath = ^"List/Rows"
## A `Label`: the Pokédex's name and its counts.
@export var header: NodePath = ^"Header"
## A `TextureRect`: the species under the cursor, once seen.
@export var picture: NodePath = ^"Side/Picture"
## A `Label`: its name, once seen.
@export var species_name: NodePath = ^"Side/Name"

@export_group("Texts")
## `{number}`, `{name}`; a species never seen: `unknown_row_text`.
@export var row_text := "{number}  {name}"
@export var unknown_row_text := "{number}  -----"
## `{dex}`, `{seen}`, `{caught}`.
@export var header_text := "{dex}   Seen {seen}   Caught {caught}"

var pokedex: Pokedex
var species: SpeciesData
var dialogue: Dialogue
var texts: Texts
## The index of the row under the cursor.
var cursor := 0
## The services, given to the entry screen.
var services := {}

var _rows: Array[Dictionary] = []
var _cards: Array[Control] = []
var _busy := false


func _on_open(args: Dictionary) -> void:
	services = args.duplicate()
	pokedex = _service(args, &"pokedex")
	species = _service(args, &"species")
	dialogue = _service(args, &"dialogue")
	texts = _service(args, &"texts")
	if pokedex == null or species == null or dialogue == null or texts == null:
		push_error("pokedex screen: no pokedex, species, dialogue or texts service")
		close()
		return
	refresh()


func _on_input(event: InputEvent) -> bool:
	if _busy:
		return true
	if dialogue.is_action(event, "cancel"):
		close()
	elif dialogue.is_action(event, "confirm"):
		_open_entry()
	elif dialogue.is_action(event, "up"):
		_move_round(-1)
	elif dialogue.is_action(event, "down"):
		_move_round(1)
	elif dialogue.is_action(event, "left"):
		_move_by(-page)
	elif dialogue.is_action(event, "right"):
		_move_by(page)
	elif _is_switch(event):
		_switch()
	else:
		return false
	return true


## Each row: `{species, form, number, seen, caught}`.
func rows() -> Array[Dictionary]:
	return _rows.duplicate()


## The row under the cursor, or {}.
func selected() -> Dictionary:
	return _rows[cursor] if cursor < _rows.size() else {}


## Builds the rows again from what was seen.
func refresh() -> void:
	_rows.clear()
	var last_seen := -1
	for entry in pokedex.entries():
		var row := entry.duplicate()
		row["seen"] = pokedex.is_seen(entry["species"])
		row["caught"] = pokedex.is_caught(entry["species"])
		if row["seen"]:
			last_seen = _rows.size()
		_rows.append(row)
	if hide_after_last_seen and last_seen >= 0:
		_rows.resize(last_seen + 1)
	var box := get_node_or_null(list)
	for card in _cards:
		card.queue_free()
		if card.get_parent() != null:
			card.get_parent().remove_child(card)
	_cards.clear()
	for row in _rows:
		var card := _make_row(row)
		_cards.append(card)
		if box != null:
			box.add_child(card)
	var shown_header := get_node_or_null(header) as Label
	if shown_header != null:
		var dex := pokedex.find(pokedex.dex)
		shown_header.text = texts.label(header_text, {"dex": texts.label(dex.name) if dex != null else "", "seen": pokedex.seen_count(), "caught": pokedex.caught_count()})
	cursor = clampi(cursor, 0, maxi(_rows.size() - 1, 0))
	_show_cursor()


## The number shown for a row.
static func number_text(row: Dictionary) -> String:
	return "%03d" % int(row.get("number", 0))


## A row of the list; the engine's is a button, marked once seen or caught.
func _make_row(row: Dictionary) -> Control:
	var card := Button.new()
	var found := species.find(row["species"])
	var values := {"number": number_text(row), "name": texts.label(found.name) if found != null else ""}
	card.text = ("● " if row["caught"] else ("○ " if row["seen"] else "   ")) + texts.label(row_text if row["seen"] else unknown_row_text, values)
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.toggle_mode = true
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return card


## Shows `card` under the cursor or not; the engine's presses its button.
func _show_selected(card: Control, is_selected: bool) -> void:
	if card is Button:
		(card as Button).set_pressed_no_signal(is_selected)


## Shows the species of `row` beside the list: its picture and name once
## seen. `row` is {} with no row.
func _show_species(row: Dictionary) -> void:
	var seen: bool = row.get("seen", false) and species.has(row.get("species", &""))
	var form := species.form(row["species"], row["form"]) if seen else null
	var shown_picture := get_node_or_null(picture) as TextureRect
	if shown_picture != null:
		shown_picture.texture = form.picture(&"front") if form != null else null
	var shown_name := get_node_or_null(species_name) as Label
	if shown_name != null:
		shown_name.text = texts.label(species.find(row["species"]).name) if seen else ""


func _move_round(step: int) -> void:
	if _rows.is_empty():
		return
	cursor = wrapi(cursor + step, 0, _rows.size())
	_show_cursor()


func _move_by(step: int) -> void:
	if _rows.is_empty():
		return
	cursor = clampi(cursor + step, 0, _rows.size() - 1)
	_show_cursor()


func _show_cursor() -> void:
	for index in _cards.size():
		_show_selected(_cards[index], index == cursor)
	var container := get_node_or_null(scroll) as ScrollContainer
	if container != null and cursor < _cards.size() and _cards[cursor].is_inside_tree():
		container.ensure_control_visible(_cards[cursor])
	_show_species(selected())


func _open_entry() -> void:
	var row := selected()
	if not row.get("seen", false):
		return
	var screens: Variant = _service(services, &"screens")
	if screens == null:
		return
	var args := services.duplicate()
	args["rows"] = _rows.duplicate()
	args["index"] = cursor
	var entry: WgScreen = screens.open(&"pokedex_entry", args)
	if entry == null or entry.is_closed():
		return
	_busy = true
	await entry.closed
	_busy = false
	if not is_closed():
		cursor = int(entry.get(&"index"))
		_show_cursor()


func _is_switch(event: InputEvent) -> bool:
	var action := pokedex.config().switch
	return not action.is_empty() and InputMap.has_action(action) and event.is_action_pressed(action)


func _switch() -> void:
	var owned := pokedex.dexes
	if owned.size() < 2:
		return
	pokedex.dex = owned[wrapi(owned.find(pokedex.dex) + 1, 0, owned.size())]
	cursor = 0
	refresh()


func _service(args: Dictionary, key: StringName) -> Variant:
	if args.has(key):
		return args[key]
	var engine := get_node_or_null(^"/root/Wildgrass")
	return engine.get(key) if engine != null else null
