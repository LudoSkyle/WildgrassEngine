## A Pokémon: what it is, what it knows, where it comes from. Made by
## `Wildgrass.pokemon.make()`, or written in the inspector; its words that
## need the game's data (its species, nature, moves) work once it is bound
## (`Wildgrass.pokemon.bind()`), which the engine does when it makes,
## gives or restores one.
class_name WgPokemon
extends Resource

enum Gender { NONE, MALE, FEMALE }

## The stats, in the order the reference keeps them.
const STATS: Array[StringName] = [&"hp", &"attack", &"defense", &"speed", &"special_attack", &"special_defense"]
## The statuses a Pokémon keeps out of battle.
const STATUSES: Array[StringName] = [&"poison", &"paralysis", &"burn", &"sleep", &"freeze", &"toxic"]
## Its contest conditions.
const CONDITIONS: Array[StringName] = [&"cool", &"beautiful", &"cute", &"clever", &"tough", &"sheen"]
## The most moves it knows.
const MOVES := 4
## Below this, the code's low 16 bits make it shiny: 1 in 4096.
const SHINY_RATE := 16

@export var species: StringName = &""
@export var form := 0
## Empty: the species' name.
@export var nickname := ""
@export var level := 1
@export var experience := 0
## 32 bits: its low 16 make it shiny, its high 16 its nature.
@export var code := 0
## Its nature's number.
@export var nature := 0
## `{stat: 0 to 31}`, the stats of `STATS`.
@export var ivs: Dictionary[StringName, int] = {}
## `{stat: points}`, the stats of `STATS`.
@export var evs: Dictionary[StringName, int] = {}
@export var hp := 0
## Empty, or among `STATUSES`.
@export var status: StringName = &""
## How long its status lasts (sleep), or has (toxic).
@export var status_count := 0
## 0 to 255.
@export var friendship := 0
@export var ability: StringName = &""
## Which of its species' abilities: 0, 1, or 2 (hidden); -1: given.
@export var ability_index := -1
@export var gender := Gender.NONE
## Empty: none.
@export var held_item: StringName = &""
## Up to `MOVES`.
@export var moves: Array[WgMoveSlot] = []
## Every move it has known.
@export var learnt_moves: Array[StringName] = []
## The ball it was caught with.
@export var ball: StringName = &"poke_ball"
## When it was caught, in seconds since 1970.
@export var caught_at := 0
@export var caught_level := 1
## The zone it was caught in; empty: none.
@export var caught_in: StringName = &""
@export var trainer_name := ""
@export var trainer_id := 0
@export var caught_by_player := false
## Above 0, it is an egg hatching after so many steps.
@export var steps_left := 0
## Its strain in the high 4 bits, the days left in the low 4.
@export var pokerus := 0
## `{condition: points}`, the conditions of `CONDITIONS`.
@export var conditions: Dictionary[StringName, int] = {}
@export var ribbons: Array[StringName] = []

## The service it is bound to; null until bound.
var maker: RefCounted = null


func is_shiny() -> bool:
	return (code & 0xFFFF) < SHINY_RATE


## Sets the code's low 16 bits so that it is shiny, or not.
func set_shiny(shiny: bool) -> void:
	code = (code & 0xFFFF0000) | (0 if shiny else 0xFFFF)


func is_egg() -> bool:
	return steps_left > 0


func is_alive() -> bool:
	return hp > 0 and not is_egg()


## Its species; null if not bound or unknown.
func species_data() -> WgSpecies:
	return maker.species_of(self) if _bound() else null


## Its form's data; null if not bound or unknown.
func form_data() -> WgSpeciesForm:
	return maker.form_of(self) if _bound() else null


## Its nature; null if not bound or unknown.
func nature_data() -> WgNature:
	return maker.nature_of(self) if _bound() else null


## A stat of `STATS` but `hp`, as the reference computes it; 0 if not bound.
func stat(stat_name: StringName) -> int:
	if stat_name == &"hp":
		return max_hp()
	var data := form_data()
	var nature_found := nature_data()
	if data == null:
		return 0
	var factor := nature_found.factor(stat_name) if nature_found != null else 100
	@warning_ignore("integer_division")
	return ((2 * data.base_stats.get(stat_name, 0) + evs.get(stat_name, 0) / 4 + ivs.get(stat_name, 0)) * level / 100 + 5) * factor / 100


## Its most HP; 0 if not bound.
func max_hp() -> int:
	var data := form_data()
	if data == null:
		return 0
	if species == &"shedinja":
		return 1
	@warning_ignore("integer_division")
	return (ivs.get(&"hp", 0) + 2 * data.base_stats.get(&"hp", 0) + evs.get(&"hp", 0) / 4) * level / 100 + 10 + level


## Sets its HP within 0 and `max_hp()`; at 0 its status ends.
func set_hp(value: int) -> void:
	if value <= 0:
		hp = 0
		status = &""
		return
	hp = mini(value, max_hp())


## Its HP, status and PP restored.
func heal() -> void:
	status = &""
	status_count = 0
	set_hp(max_hp())
	for slot in moves:
		slot.pp = slot.max_pp


## Its nickname, else its species' name: a label, shown through
## `Wildgrass.texts.label()`.
func display_name() -> String:
	if not nickname.is_empty():
		return nickname
	var found := species_data()
	return found.name if found != null else String(species)


func knows(move: StringName) -> bool:
	return moves.any(func(slot: WgMoveSlot) -> bool: return slot.move == move)


## Learns `move` as when it grows: past `MOVES`, the first one is forgotten.
## False if it knows it, or the move is unknown.
func learn(move: StringName) -> bool:
	if knows(move) or not _bound():
		return false
	var found: WgMove = maker.move_of(move)
	if found == null:
		return false
	moves.append(WgMoveSlot.of(move, found.pp))
	if moves.size() > MOVES:
		moves.remove_at(0)
	if move not in learnt_moves:
		learnt_moves.append(move)
	return true


func forget(move: StringName) -> void:
	moves = moves.filter(func(slot: WgMoveSlot) -> bool: return slot.move != move)


## Takes form `value` if its species has it, its ability following the
## form's (the same of its abilities); false, unchanged, otherwise.
func set_form(value: int) -> bool:
	var found := species_data()
	if found == null or found.find_form(value) == null:
		return false
	form = value
	var data := form_data()
	if ability_index >= 0 and data != null and ability_index < data.abilities.size():
		ability = data.abilities[ability_index]
	return true


## Its level, within 1 and the level limit; its experience that level's.
func set_level(value: int) -> void:
	if value == level or not _bound():
		return
	level = clampi(value, 1, maker.level_limit)
	var data := form_data()
	experience = WgExperience.total(data.growth_rate if data != null else WgExperience.Growth.NORMAL, level)


## Its cry; null if none or not bound.
func cry() -> AudioStream:
	var data := form_data()
	return data.cry() if data != null else null


## Everything it is, as a Dictionary JSON holds: each field by name, its
## moves as `[move, pp, max_pp]`.
func to_data() -> Dictionary:
	var data := {}
	for property in _fields():
		var field: String = property["name"]
		if field == "moves":
			data[field] = moves.map(func(slot: WgMoveSlot) -> Array: return [String(slot.move), slot.pp, slot.max_pp])
		else:
			data[field] = _plain(get(field))
	return data


## A Pokémon from `to_data()`'s, through JSON: its numbers whole again, its
## names StringNames. Not bound; a field missing keeps its default.
static func from_data(data: Dictionary) -> WgPokemon:
	var pokemon := WgPokemon.new()
	for property in pokemon._fields():
		var field: String = property["name"]
		if not data.has(field):
			continue
		var value: Variant = data[field]
		match int(property["type"]):
			TYPE_INT:
				pokemon.set(field, int(value) if value is float or value is int else 0)
			TYPE_BOOL:
				pokemon.set(field, bool(value))
			TYPE_STRING:
				pokemon.set(field, str(value))
			TYPE_STRING_NAME:
				pokemon.set(field, StringName(str(value)))
			TYPE_DICTIONARY:
				var kept: Dictionary = pokemon.get(field)
				kept.clear()
				for key: Variant in (value as Dictionary if value is Dictionary else {}):
					kept[StringName(str(key))] = int(value[key])
			TYPE_ARRAY:
				if field == "moves":
					for slot: Variant in (value as Array if value is Array else []):
						if slot is Array and slot.size() == 3:
							var made := WgMoveSlot.of(StringName(str(slot[0])), int(slot[2]))
							made.pp = int(slot[1])
							pokemon.moves.append(made)
				else:
					var listed: Array = pokemon.get(field)
					for item: Variant in (value as Array if value is Array else []):
						listed.append(StringName(str(item)))
	return pokemon


## Its fields kept: the exported ones.
func _fields() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for property in get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and property["usage"] & PROPERTY_USAGE_STORAGE:
			found.append(property)
	return found


## `value` with its names as Strings, for JSON.
static func _plain(value: Variant) -> Variant:
	if value is StringName:
		return String(value)
	if value is Dictionary:
		var plain := {}
		for key: Variant in value:
			plain[str(key)] = _plain(value[key])
		return plain
	if value is Array:
		var listed := []
		for item: Variant in value:
			listed.append(_plain(item))
		return listed
	return value


func _bound() -> bool:
	if maker != null:
		return true
	push_error("Pokémon '%s' is not bound: bind it with Wildgrass.pokemon.bind()" % species)
	return false
