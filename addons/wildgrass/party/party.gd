## The player's party (feature 23): up to the `party` config's size of
## Pokémon, in order. A Pokémon added is bound to the game's data and
## recorded by the Pokédex; the party is kept by the save, each Pokémon as
## data.
extends RefCounted

const _Log := preload("res://addons/wildgrass/core/log/log.gd")
const _ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const _PokemonMaker := preload("res://addons/wildgrass/party/pokemon_maker.gd")
const _Pokedex := preload("res://addons/wildgrass/pokedex/pokedex.gd")

## A Pokémon came, left, or moved.
signal changed

@warning_ignore("shadowed_global_identifier")
var log: _Log

var _config: _ConfigRegistry
var _maker: _PokemonMaker
var _pokedex: _Pokedex
var _pokemon: Array[WgPokemon] = []


func _init(logger: _Log, config_registry: _ConfigRegistry, maker: _PokemonMaker, pokedex: _Pokedex) -> void:
	log = logger
	_config = config_registry
	_maker = maker
	_pokedex = pokedex


func config() -> WgPartyConfig:
	return _config.get_config(&"party") as WgPartyConfig


## Adds `pokemon` at the end, bound, the Pokédex told (seen and caught,
## unless an egg). False if the party is full (logged: the PC is a feature
## of its own) or already has it.
func add(pokemon: WgPokemon) -> bool:
	if pokemon == null or _pokemon.has(pokemon):
		return false
	if is_full():
		log.warn(&"party", "%s not added: the party is full (no PC yet)" % pokemon.species)
		return false
	_maker.bind(pokemon)
	if not pokemon.is_egg():
		_pokedex.catch(pokemon.species, pokemon.form)
	_pokemon.append(pokemon)
	changed.emit()
	return true


## Takes out the Pokémon at `index`, the others closing up; null if none.
func remove(index: int) -> WgPokemon:
	if index < 0 or index >= _pokemon.size():
		return null
	var removed: WgPokemon = _pokemon.pop_at(index)
	changed.emit()
	return removed


## Swaps the Pokémon at `a` and `b`; false if either has none.
func swap(a: int, b: int) -> bool:
	if a < 0 or b < 0 or a >= _pokemon.size() or b >= _pokemon.size():
		return false
	var first := _pokemon[a]
	_pokemon[a] = _pokemon[b]
	_pokemon[b] = first
	changed.emit()
	return true


## The Pokémon at `index`; null if none.
func at(index: int) -> WgPokemon:
	return _pokemon[index] if index >= 0 and index < _pokemon.size() else null


## Every Pokémon, in order: a copy.
func all() -> Array[WgPokemon]:
	return _pokemon.duplicate()


func size() -> int:
	return _pokemon.size()


func is_empty() -> bool:
	return _pokemon.is_empty()


func is_full() -> bool:
	return _pokemon.size() >= config().size


## How many are alive among the first `among` (all with -1), as the
## reference counts them.
func alive_count(among := -1) -> int:
	var count := 0
	for index in mini(among if among >= 0 else _pokemon.size(), _pokemon.size()):
		if _pokemon[index].is_alive():
			count += 1
	return count


## Each one's HP, status and PP restored; told, a fainted one able again.
func heal() -> void:
	for pokemon in _pokemon:
		pokemon.heal()
	changed.emit()


func has(species: StringName) -> bool:
	return index_of(species) >= 0


## The index of the first of species `species`; -1 if none.
func index_of(species: StringName) -> int:
	for index in _pokemon.size():
		if _pokemon[index].species == species:
			return index
	return -1


## The first alive, not an egg; null if none.
func first_alive() -> WgPokemon:
	for pokemon in _pokemon:
		if pokemon.is_alive():
			return pokemon
	return null


## The `party` part of a saved game: each Pokémon as data.
func state() -> Dictionary:
	return {"pokemon": _pokemon.map(func(pokemon: WgPokemon) -> Dictionary: return pokemon.to_data())}


## Puts back the party `state()` saw, each Pokémon bound; the Pokédex is
## not told again.
func restore(saved: Dictionary) -> void:
	_pokemon.clear()
	var listed: Variant = saved.get("pokemon", [])
	for data: Variant in (listed if listed is Array else []):
		if not data is Dictionary:
			continue
		var pokemon := WgPokemon.from_data(data)
		if not _maker.bind(pokemon):
			log.warn(&"party", "the saved Pokémon's species '%s' is not in the game" % pokemon.species)
		_pokemon.append(pokemon)
	changed.emit()


## A new game: nobody.
func reset() -> void:
	_pokemon.clear()
	changed.emit()
