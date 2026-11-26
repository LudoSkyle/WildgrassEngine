## A Pokémon as Studio's scripts see it (`PFM::Pokemon`, feature 23): the
## engine's `WgPokemon` under Studio's names. The Studio layer's; nothing of
## the engine depends on it.
extends RefCounted

## The engine's Pokémon.
var pokemon: WgPokemon
## Its species' national number.
var id: int:
	get:
		var found := pokemon.species_data()
		return found.number if found != null else 0
var db_symbol: StringName:
	get:
		return pokemon.species
## Set as Studio sets it: only to a form its species has.
var form: int:
	get:
		return pokemon.form
	set(value):
		pokemon.set_form(value)
var level: int:
	get:
		return pokemon.level
## Its friendship, 0 to 255.
var loyalty: int:
	get:
		return pokemon.friendship
	set(value):
		pokemon.friendship = clampi(value, 0, 255)
var shiny: bool:
	get:
		return pokemon.is_shiny()
	set(value):
		pokemon.set_shiny(value)
var hp: int:
	get:
		return pokemon.hp
	set(value):
		pokemon.set_hp(value)
var max_hp: int:
	get:
		return pokemon.max_hp()
## Its species' name, in the language shown.
var name: String:
	get:
		var found := pokemon.species_data()
		return _label(found.name) if found != null else String(pokemon.species)
## Its nickname, else its species' name; set to its species' name, it has
## none.
var given_name: String:
	get:
		return pokemon.nickname if not pokemon.nickname.is_empty() else name
	set(value):
		pokemon.nickname = "" if value == name else value

var _texts: WeakRef


func _init(seen: WgPokemon, texts: Object) -> void:
	pokemon = seen
	_texts = weakref(texts)


## True while it is an egg (`egg?`).
func egg() -> bool:
	return pokemon.is_egg()


## True if it cannot fight: no HP, or an egg (`dead?`).
func dead() -> bool:
	return not pokemon.is_alive()


## Its status ended.
func cure() -> void:
	pokemon.status = &""
	pokemon.status_count = 0


## `pokemon` itself, or the one Studio's view shows; null for anything else.
static func engine_of(given: Variant) -> WgPokemon:
	if given is WgPokemon:
		return given
	if given is RefCounted and (given as RefCounted).get(&"pokemon") is WgPokemon:
		return (given as RefCounted).get(&"pokemon")
	return null


func _label(text: String) -> String:
	var texts: Object = _texts.get_ref()
	return str(texts.call(&"label", text)) if texts != null else text
