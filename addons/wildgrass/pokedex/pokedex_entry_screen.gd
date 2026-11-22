## A species' entry in the Pokédex: its picture, number and name; once
## caught, its genus, types, height, weight and description, else question
## marks. It cries as it shows. Up and down go to the species seen before or
## after; cancel goes back. A game's scene extends it (`_show_entry()`) and
## points `wildgrass/screens/pokedex_entry` to it.
##
## Opened by the Pokédex; arguments: `rows` and `index` (the list's),
## `species`, `types`, `texts`, `dialogue`, the services (the engine's).
class_name WgPokedexEntryScreen
extends WgScreen

const _SpeciesData := preload("res://addons/wildgrass/pokemon/species_data.gd")
const _Types := preload("res://addons/wildgrass/pokemon/types.gd")
const _Dialogue := preload("res://addons/wildgrass/dialogue/dialogue.gd")
const _Texts := preload("res://addons/wildgrass/texts/texts.gd")

@export_group("Nodes")
@export var picture: NodePath = ^"Picture"
## A `Label`: the number and the name.
@export var title: NodePath = ^"Title"
## `Label`s shown once caught.
@export var genus: NodePath = ^"Details/Genus"
@export var type_names: NodePath = ^"Details/Types"
@export var size_label: NodePath = ^"Details/Size"
@export var description: NodePath = ^"Description"
## An `AudioStreamPlayer` for the cry.
@export var cry_player: NodePath = ^"Cry"

@export_group("Texts")
## `{number}`, `{name}`.
@export var title_text := "{number}  {name}"
## `{height}`, `{weight}`.
@export var size_text := "Height {height} m   Weight {weight} kg"
## Shown in place of what is known once caught.
@export var unknown_text := "?????"

var species: _SpeciesData
var types: _Types
var dialogue: _Dialogue
var texts: _Texts
## The list's rows, and the index of the one shown.
var rows: Array[Dictionary] = []
var index := 0


func _on_open(args: Dictionary) -> void:
	species = _service(args, &"species")
	types = _service(args, &"types")
	dialogue = _service(args, &"dialogue")
	texts = _service(args, &"texts")
	rows.assign(args.get("rows", []))
	index = int(args.get("index", 0))
	if species == null or types == null or dialogue == null or texts == null or index < 0 or index >= rows.size():
		push_error("pokedex entry screen: no species, types, dialogue, texts or row")
		close()
		return
	_show()


func _on_input(event: InputEvent) -> bool:
	if dialogue.is_action(event, "cancel"):
		close()
	elif dialogue.is_action(event, "up"):
		_go(-1)
	elif dialogue.is_action(event, "down"):
		_go(1)
	else:
		return false
	return true


## The row shown.
func row() -> Dictionary:
	return rows[index]


## Shows the species of `shown`: its fields, and the engine's nodes.
func _show_entry(shown: Dictionary) -> void:
	var found := species.find(shown["species"])
	var form := species.form(shown["species"], shown["form"])
	var caught: bool = shown.get("caught", false)
	var shown_picture := get_node_or_null(picture) as TextureRect
	if shown_picture != null:
		shown_picture.texture = form.picture(&"front") if form != null else null
	_write(title, texts.label(title_text, {"number": WgPokedexScreen.number_text(shown), "name": texts.label(found.name)}))
	_write(genus, texts.label(found.genus) if caught else unknown_text)
	var names: Array[String] = []
	for id in form.types if form != null else []:
		var type := types.find(id)
		names.append(texts.label(type.name) if type != null else str(id))
	_write(type_names, " / ".join(names) if caught else unknown_text)
	_write(size_label, texts.label(size_text, {"height": "%.1f" % form.height, "weight": "%.1f" % form.weight}) if caught and form != null else unknown_text)
	var text := form.description if form != null and not form.description.is_empty() else found.description
	_write(description, texts.label(text) if caught else "")


func _show() -> void:
	_show_entry(row())
	var form := species.form(row()["species"], row()["form"])
	var player := get_node_or_null(cry_player) as AudioStreamPlayer
	if player != null and form != null:
		player.stream = form.cry()
		if player.stream != null:
			player.play()


## To the species seen before or after, stopping at the ends.
func _go(step: int) -> void:
	var at := index + step
	while at >= 0 and at < rows.size() and not rows[at].get("seen", false):
		at += step
	if at < 0 or at >= rows.size():
		return
	index = at
	_show()


func _write(path: NodePath, text: String) -> void:
	var label := get_node_or_null(path) as Label
	if label != null:
		label.text = text


func _service(args: Dictionary, key: StringName) -> Variant:
	if args.has(key):
		return args[key]
	var engine := get_node_or_null(^"/root/Wildgrass")
	return engine.get(key) if engine != null else null
