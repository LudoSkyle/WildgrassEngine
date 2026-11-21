## A Studio project's species (`Data/Studio/pokemon/<dbSymbol>.json`) and
## types (`Data/Studio/types/<dbSymbol>.json`), read as they are the first
## time they are asked for: sources of the species and types services.
extends RefCounted

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")

const SPECIES := "Studio/pokemon/"
const TYPES := "Studio/types/"
const NAME_TEXTS := 100000
const GENUS_TEXTS := 100001
const DESCRIPTION_TEXTS := 100002
const TYPE_TEXTS := 100003
const FORM_NAME_TEXTS := 100067
const FORM_DESCRIPTION_TEXTS := 100068
## The last national number of each generation.
const GENERATIONS: Array[int] = [151, 251, 386, 493, 649, 721, 809, 905, 1025]
const STATS: Dictionary[String, StringName] = {
	"Hp": &"hp", "Atk": &"attack", "Dfe": &"defense", "Ats": &"special_attack", "Dfs": &"special_defense", "Spd": &"speed",
}
const HOW: Dictionary[String, StringName] = {
	"LevelLearnableMove": &"level", "TechLearnableMove": &"tm", "TutorLearnableMove": &"tutor",
	"BreedLearnableMove": &"egg", "EvolutionLearnableMove": &"evolution",
}
## Each picture kind: Studio's resource key, its folder inside the graphics
## folder, and its shiny folder.
const PICTURES: Dictionary[StringName, Array] = {
	&"icon": ["icon", "pokedex/pokeicon/", "pokedex/pokeiconshiny/"],
	&"front": ["front", "pokedex/pokefront/", "pokedex/pokefrontshiny/"],
	&"back": ["back", "pokedex/pokeback/", "pokedex/pokebackshiny/"],
	&"footprint": ["footprint", "pokedex/footprints/", "pokedex/footprints/"],
	&"character": ["character", "characters/", "characters/"],
}
## Studio's way of saying "no type", "no item".
const NONE: Array[String] = ["__undef__", "none", ""]

@warning_ignore("shadowed_global_identifier")
var log: Log

var _paths: Paths
## Files that are not what they should be, logged once.
var _broken: Dictionary[String, bool] = {}


func _init(paths: Paths, logger: Log) -> void:
	_paths = paths
	log = logger


## The species of `id`, or null if the project has none.
func read_species(id: StringName) -> WgSpecies:
	var data := _file(SPECIES, id, "species")
	if data.is_empty():
		return null
	var species := WgSpecies.new()
	species.id = id
	species.number = int(data.get("id", 0))
	species.generation = generation_of(species.number)
	species.name = "{text:%d:%d}" % [NAME_TEXTS, species.number]
	species.genus = "{text:%d:%d}" % [GENUS_TEXTS, species.number]
	species.description = "{text:%d:%d}" % [DESCRIPTION_TEXTS, species.number]
	var forms: Variant = data.get("forms", [])
	for form_data: Variant in forms if forms is Array else []:
		if form_data is Dictionary:
			species.forms.append(_form(form_data))
	return species


## The type of `id`, or null if the project has none.
func read_type(id: StringName) -> WgType:
	var data := _file(TYPES, id, "type")
	if data.is_empty():
		return null
	var type := WgType.new()
	type.id = id
	type.name = "{text:%d:%d}" % [TYPE_TEXTS, int(data.get("textId", 0))]
	type.color = Color.from_string(str(data.get("color", "")), Color.WHITE)
	var damage: Variant = data.get("damageTo", [])
	for hit: Variant in damage if damage is Array else []:
		if hit is Dictionary:
			type.damage[StringName(str(hit.get("defensiveType", "")))] = float(hit.get("factor", 1.0))
	return type


func species_ids() -> Array[StringName]:
	return _ids(SPECIES)


func type_ids() -> Array[StringName]:
	return _ids(TYPES)


## The generation of a national number; 0 past the last known.
static func generation_of(number: int) -> int:
	for index in GENERATIONS.size():
		if number >= 1 and number <= GENERATIONS[index]:
			return index + 1
	return 0


func _form(data: Dictionary) -> WgSpeciesForm:
	var form := WgSpeciesForm.new()
	form.form = int(data.get("form", 0))
	var texts: Variant = data.get("formTextId", {})
	if texts is Dictionary:
		if form.form != 0:
			form.name = "{text:%d:%d}" % [FORM_NAME_TEXTS, int(texts.get("name", 0))]
		if int(texts.get("description", 0)) > 0:
			form.description = "{text:%d:%d}" % [FORM_DESCRIPTION_TEXTS, int(texts.get("description", 0))]
	form.height = float(data.get("height", 0.0))
	form.weight = float(data.get("weight", 0.0))
	for key: String in ["type1", "type2"]:
		if str(data.get(key, "")) not in NONE:
			form.types.append(StringName(str(data[key])))
	for suffix: String in STATS:
		form.base_stats[STATS[suffix]] = int(data.get("base" + suffix, 0))
		form.effort[STATS[suffix]] = int(data.get("ev" + suffix, 0))
	form.catch_rate = int(data.get("catchRate", 0))
	form.base_experience = int(data.get("baseExperience", 0))
	form.growth_rate = int(data.get("experienceType", 0))
	form.base_friendship = int(data.get("baseLoyalty", 0))
	form.female_rate = float(data.get("femaleRate", 50.0))
	for group: Variant in _list(data, "breedGroups"):
		form.egg_groups.append(int(group))
	form.hatch_steps = int(data.get("hatchSteps", 0))
	form.baby = StringName(str(data.get("babyDbSymbol", "")))
	form.baby_form = int(data.get("babyForm", 0))
	for held: Variant in _list(data, "itemHeld"):
		if held is Dictionary and str(held.get("dbSymbol", "")) not in NONE:
			form.held_items.append({"item": StringName(str(held["dbSymbol"])), "chance": float(held.get("chance", 0))})
	for ability: Variant in _list(data, "abilities"):
		form.abilities.append(StringName(str(ability)))
	for evolution: Variant in _list(data, "evolutions"):
		if evolution is Dictionary:
			var conditions := []
			for condition: Variant in _list(evolution, "conditions"):
				if condition is Dictionary:
					conditions.append({"type": StringName(str(condition.get("type", ""))), "value": condition.get("value")})
			form.evolutions.append({"species": StringName(str(evolution.get("dbSymbol", ""))), "form": int(evolution.get("form", 0)), "conditions": conditions})
	for move: Variant in _list(data, "moveSet"):
		if move is Dictionary and HOW.has(str(move.get("klass", ""))):
			form.moves.append({"move": StringName(str(move.get("move", ""))), "how": HOW[str(move["klass"])], "level": int(move.get("level", 0))})
	form.front_offset_y = int(data.get("frontOffsetY", 0))
	var resources: Variant = data.get("resources", {})
	if resources is Dictionary:
		_pictures(form, resources)
	return form


## The form's pictures and cry, as paths in the project's folders.
func _pictures(form: WgSpeciesForm, resources: Dictionary) -> void:
	for kind: StringName in PICTURES:
		var place: Array = PICTURES[kind]
		var variants := {
			"": [place[0], place[1]], "_female": [place[0] + "F", place[1]],
			"_shiny": [place[0] + "Shiny", place[2]], "_shiny_female": [place[0] + "ShinyF", place[2]],
		}
		for suffix: String in variants:
			var file := str(resources.get(variants[suffix][0], ""))
			if not file.is_empty():
				form.pictures[StringName(kind + suffix)] = _paths.resolve(&"graphics", variants[suffix][1] + file + ".png")
	var cry := str(resources.get("cry", ""))
	if not cry.is_empty():
		form.pictures[&"cry"] = _paths.resolve(&"audio", "se/cries/" + cry)


func _file(folder: String, id: StringName, what: String) -> Dictionary:
	var path := _paths.resolve(&"data", folder + "%s.json" % id)
	if not FileAccess.file_exists(path):
		return {}
	var parser := JSON.new()
	var data: Variant = parser.data if parser.parse(FileAccess.get_file_as_string(path)) == OK else null
	if not data is Dictionary or str(data.get("dbSymbol", "")) != str(id):
		if not _broken.has(path):
			_broken[path] = true
			log.error(&"studio", "%s: not a Studio %s" % [path.get_file(), what])
		return {}
	return data


func _ids(folder: String) -> Array[StringName]:
	var found: Array[StringName] = []
	var path := _paths.resolve(&"data", folder)
	if not DirAccess.dir_exists_absolute(path):
		return found
	for file in DirAccess.get_files_at(path):
		if file.ends_with(".json"):
			found.append(StringName(file.get_basename()))
	return found


static func _list(data: Dictionary, key: String) -> Array:
	var value: Variant = data.get(key, [])
	return value if value is Array else []
