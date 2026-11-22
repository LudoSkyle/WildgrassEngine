## The species view, a debug tool: every species the engine finds, by
## national number, to check their data. On the left the list, a page at a
## time, a star by a species with something missing (the title counts
## them); on the right its card, what is missing in red, and its
## `character` sheet turning. Up and down: a species, round; left and right:
## ten; cancel closes. The engine's scene uses Godot's default theme; a game
## points `wildgrass/screens/species_view` to its own.
##
## Arguments: `species`, `texts`, `dialogue`.
class_name WgSpeciesViewScreen
extends WgScreen

const SpeciesData := preload("res://addons/wildgrass/pokemon/species_data.gd")
const Texts := preload("res://addons/wildgrass/texts/texts.gd")
const Dialogue := preload("res://addons/wildgrass/dialogue/dialogue.gd")
const SheetView := preload("res://addons/wildgrass/debug/species_sheet_view.gd")
const MISSING := "#e04040"

@export_group("Nodes")
@export var title: NodePath = ^"List/Title"
## The lines of the list, one Label each, made as many as `lines_shown`.
@export var lines_box: NodePath = ^"List/Lines"
@export var icon: NodePath = ^"Card/Pictures/Icon"
@export var front: NodePath = ^"Card/Pictures/Front"
## Where the turning sheet is drawn.
@export var sheet_holder: NodePath = ^"Card/Pictures/Sheet"
## The card's text, BBCode.
@export var card: NodePath = ^"Card/Text"
@export_group("")
## Lines of the list shown at a time.
@export var lines_shown := 12
## Screen pixels a picture pixel, for every sheet.
@export var sheet_scale := 2.0
## The list's lines' font size.
@export var font_size := 8

var species: SpeciesData
var texts: Texts
var dialogue: Dialogue
## Each {"id", "number", "missing": Array[String]}, by national number.
var entries: Array[Dictionary] = []
var selected := 0
## The sheet turning.
var sheet_view: Control


func _on_open(args: Dictionary) -> void:
	species = _service(args, &"species")
	texts = _service(args, &"texts")
	dialogue = _service(args, &"dialogue")
	if species == null or texts == null or dialogue == null:
		push_error("species view: no species, texts or dialogue service")
		close()
		return
	sheet_view = SheetView.new()
	sheet_view.scale_by = sheet_scale
	var holder := get_node_or_null(sheet_holder)
	if holder != null:
		holder.add_child(sheet_view)
	for found: WgSpecies in species.all():
		entries.append({"id": found.id, "number": found.number, "missing": missing(found)})
	refresh()


func _process(delta: float) -> void:
	advance(delta)


## Turns the sheet on by `delta` seconds.
func advance(delta: float) -> void:
	if sheet_view != null:
		sheet_view.advance(delta)


func _on_input(event: InputEvent) -> bool:
	if dialogue.is_action(event, "cancel"):
		close()
	elif dialogue.is_action(event, "up"):
		_select(selected - 1)
	elif dialogue.is_action(event, "down"):
		_select(selected + 1)
	elif dialogue.is_action(event, "left"):
		_select(selected - 10)
	elif dialogue.is_action(event, "right"):
		_select(selected + 10)
	else:
		return false
	return true


## What `found` lacks: a name or a description of its own in a language
## the game offers (not another language's in its place), a height, a
## weight, the icon, the front picture, the sheet. Pictures are checked by
## their path, not loaded.
func missing(found: WgSpecies) -> Array[String]:
	var lacks: Array[String] = []
	var form: WgSpeciesForm = found.forms[0] if not found.forms.is_empty() else null
	for code in _languages():
		if not texts.is_given_in(code, found.name):
			lacks.append("name (%s)" % code)
		if not texts.is_given_in(code, found.description):
			lacks.append("description (%s)" % code)
	if form == null or form.height <= 0.0:
		lacks.append("height")
	if form == null or form.weight <= 0.0:
		lacks.append("weight")
	for kind: StringName in [&"icon", &"front", &"character"]:
		if form == null or not form.has_picture(kind):
			lacks.append(str(kind))
	return lacks


## How many species lack something.
func incomplete() -> int:
	return entries.filter(func(entry: Dictionary) -> bool: return not (entry["missing"] as Array).is_empty()).size()


## Shows the list around the species selected, and its card.
func refresh() -> void:
	var heading := get_node_or_null(title) as Label
	if heading != null:
		heading.text = texts.label("Species: {count}, {missing} incomplete", {"count": entries.size(), "missing": incomplete()})
	var box := get_node_or_null(lines_box)
	if box != null:
		while box.get_child_count() < lines_shown:
			var line := Label.new()
			line.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			line.add_theme_font_size_override(&"font_size", font_size)
			box.add_child(line)
		var first := clampi(selected - lines_shown / 2, 0, maxi(entries.size() - lines_shown, 0))
		for index in lines_shown:
			var at := first + index
			(box.get_child(index) as Label).text = _line(at) if at < entries.size() else ""
	_show_card()


## The list's line of entry `at`: a cursor, its number, its name, a star if
## it lacks something.
func line_of(at: int) -> String:
	return _line(at)


func _line(at: int) -> String:
	var entry := entries[at]
	var found := species.find(entry["id"])
	var star := " *" if not (entry["missing"] as Array).is_empty() else ""
	return "%s %04d %s%s" % [">" if at == selected else " ", entry["number"], texts.label(found.name), star]


func _select(at: int) -> void:
	if entries.is_empty():
		return
	selected = wrapi(at, 0, entries.size())
	if sheet_view != null:
		sheet_view.restart()
	refresh()


func _show_card() -> void:
	var text := get_node_or_null(card) as RichTextLabel
	if entries.is_empty():
		if text != null:
			text.text = texts.label("No species.")
		return
	var entry := entries[selected]
	var found := species.find(entry["id"])
	var form: WgSpeciesForm = found.forms[0] if not found.forms.is_empty() else null
	var shown_icon := get_node_or_null(icon) as TextureRect
	if shown_icon != null:
		shown_icon.texture = _first_frame(form.picture(&"icon") if form != null else null)
	var shown_front := get_node_or_null(front) as TextureRect
	if shown_front != null:
		shown_front.texture = form.picture(&"front") if form != null else null
	sheet_view.sheet = form.picture(&"character") if form != null else null
	if text == null:
		return
	var lacks: Array = entry["missing"]
	var parts: Array[String] = []
	parts.append("#%04d  %s" % [found.number, texts.label(found.genus)])
	var types: Array[String] = []
	for type: StringName in form.types if form != null else []:
		types.append(str(type))
	parts.append("%s %s · %s" % [texts.label("Generation"), found.generation, "/".join(types)])
	parts.append("%s · %s" % [_measure("%s m" % form.height if form != null else "", "height" in lacks), _measure("%s kg" % form.weight if form != null else "", "weight" in lacks)])
	for code in _languages():
		var name := texts.label_in(code, found.name) if "name (%s)" % code not in lacks else ""
		var said := texts.label_in(code, found.description) if "description (%s)" % code not in lacks else ""
		parts.append("[b]%s[/b] %s" % [code, _or_missing(name, texts.label("no name"))])
		parts.append(_or_missing(said, texts.label("no description")))
	var pictures: Array[String] = []
	for kind: String in ["icon", "front", "character"]:
		if kind in lacks:
			pictures.append(kind)
	if not pictures.is_empty():
		parts.append("[color=%s]%s %s[/color]" % [MISSING, texts.label("No picture:"), ", ".join(pictures)])
	text.text = "\n".join(parts)


func _measure(value: String, lacking: bool) -> String:
	return "[color=%s]%s[/color]" % [MISSING, value] if lacking else value


func _or_missing(value: String, instead: String) -> String:
	if value.strip_edges().is_empty():
		return "[color=%s]%s[/color]" % [MISSING, instead]
	return value.replace("[", "[lb]")


## The languages the game offers, else the one shown.
func _languages() -> Array[String]:
	var codes := texts.languages()
	if codes.is_empty():
		codes.append(texts.language)
	return codes


## An icon of two frames side by side shows its first.
static func _first_frame(picture: Texture2D) -> Texture2D:
	if picture == null or picture.get_width() != picture.get_height() * 2:
		return picture
	var cut := AtlasTexture.new()
	cut.atlas = picture
	cut.region = Rect2(0, 0, picture.get_height(), picture.get_height())
	return cut


func _service(args: Dictionary, key: StringName) -> Variant:
	if args.has(key):
		return args[key]
	var engine := get_node_or_null(^"/root/Wildgrass")
	return engine.get(key) if engine != null else null
