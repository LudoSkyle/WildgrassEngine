## Makes Pokémon as the reference does, and binds each to the game's data:
## its species, its nature, the moves. Every draw goes through `random`.
extends RefCounted

const _Log := preload("res://addons/wildgrass/core/log/log.gd")
const _ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const _SpeciesData := preload("res://addons/wildgrass/pokemon/species_data.gd")
const _Natures := preload("res://addons/wildgrass/pokemon/natures.gd")
const _Moves := preload("res://addons/wildgrass/pokemon/moves.gd")
const _Bag := preload("res://addons/wildgrass/bag/bag.gd")
const _Trainer := preload("res://addons/wildgrass/party/trainer.gd")
const _Zones := preload("res://addons/wildgrass/maps/zones.gd")

## A code is drawn below this.
const CODE_RANGE := 0xFFFFFFFF
## The item that gives more tries at a shiny code.
const SHINY_CHARM := &"shiny_charm"
## How many tries the shiny charm adds.
const SHINY_CHARM_TRIES := 2
## The draw from 0 to 99 below which the ability is the first, the second;
## else the third.
const ABILITY_CHANCES: Array[int] = [49, 98, 100]
## Species whose form, when none is given, is drawn from the Pokémon:
## `{species: Callable(pokemon) -> form}`. Unown's follows its code,
## Meowstic's its gender.
var form_rules: Dictionary[StringName, Callable] = {
	&"unown": func(pokemon: WgPokemon) -> int: return pokemon.code % 28,
	&"meowstic": func(pokemon: WgPokemon) -> int: return 1 if pokemon.gender == WgPokemon.Gender.FEMALE else 0,
}

@warning_ignore("shadowed_global_identifier")
var log: _Log
## Every draw; a test or a judge seeds it.
var random := RandomNumberGenerator.new()
## Gives the time a Pokémon is caught at, in seconds since 1970.
var now := func() -> int: return int(Time.get_unix_time_from_system())
## The highest level a Pokémon may reach now: the `pokemon` config's
## `max_level` at a new game; a game may change it. Kept by the save.
var level_limit := 100

var _config: _ConfigRegistry
var _species: _SpeciesData
var _natures: _Natures
var _moves: _Moves
var _bag: _Bag
var _trainer: _Trainer
var _zones: _Zones
var _warned: Dictionary[String, bool] = {}


func _init(logger: _Log, config_registry: _ConfigRegistry, species: _SpeciesData, natures: _Natures, moves: _Moves, bag: _Bag, trainer: _Trainer, zones: _Zones) -> void:
	log = logger
	_config = config_registry
	_species = species
	_natures = natures
	_moves = moves
	_bag = bag
	_trainer = trainer
	_zones = zones


func config() -> WgPokemonConfig:
	return _config.get_config(&"pokemon") as WgPokemonConfig


## A Pokémon of `species` at `level`, made as the reference makes it, bound.
## `options` gives what is not to be drawn: `shiny` (bool), `form`,
## `nickname`, `ball`, `caught_at`, `caught_level`, `caught_in`,
## `trainer_name`, `trainer_id`, `gender` (`WgPokemon.Gender`), `friendship`,
## `evs` and `ivs` (`{stat: value}`), `conditions`, `nature` (a number or a
## nature's id), `moves` (move ids, replacing from the first), `held_item`
## (empty: none), `ability`, `pokerus`. Null, logged, if the species is
## unknown.
func make(species_id: StringName, level: int, options := {}) -> WgPokemon:
	var species := _species.find(species_id)
	if species == null or species.forms.is_empty():
		return null
	var pokemon := WgPokemon.new()
	pokemon.species = species_id
	pokemon.maker = self
	# 1. Its code, its shininess.
	for _try in _shiny_tries():
		pokemon.code = draw(0, CODE_RANGE - 1)
		if pokemon.is_shiny():
			break
	if options.has("shiny"):
		pokemon.set_shiny(bool(options["shiny"]))
	# 2. Its level.
	pokemon.level = maxi(level, 1)
	# 3. Its form, its experience.
	var form := int(options.get("form", -1))
	if form == -1 and not form_rules.has(species_id):
		form = 0
	pokemon.form = form if form != -1 and species.find_form(form) != null else 0
	pokemon.experience = WgExperience.total(form_of(pokemon).growth_rate, pokemon.level)
	# 4. Its catch, its gender.
	_catch(pokemon, options)
	var data := form_of(pokemon)
	pokemon.gender = _gender(data, options)
	if form == -1:
		var ruled := int(form_rules[species_id].call(pokemon))
		pokemon.form = ruled if species.find_form(ruled) != null else 0
		data = form_of(pokemon)
		pokemon.experience = WgExperience.total(data.growth_rate, pokemon.level)
	# 5. Its friendship, efforts, values, conditions, nature, HP.
	pokemon.friendship = clampi(int(options.get("friendship", data.base_friendship)), 0, 255)
	for stat in WgPokemon.STATS:
		pokemon.evs[stat] = int((options.get("evs", {}) as Dictionary).get(stat, 0))
	for stat in WgPokemon.STATS:
		var given: Variant = (options.get("ivs", {}) as Dictionary).get(stat)
		pokemon.ivs[stat] = clampi(int(given) if given != null else draw(0, 31), 0, 31)
	for condition in WgPokemon.CONDITIONS:
		pokemon.conditions[condition] = int((options.get("conditions", {}) as Dictionary).get(condition, 0))
	pokemon.nature = _nature_number(pokemon, options)
	pokemon.hp = pokemon.max_hp()
	# 6. Its moves.
	_learn_by_level(pokemon, data)
	var given_moves: Array = options.get("moves", [])
	for index in mini(given_moves.size(), WgPokemon.MOVES):
		_replace_move(pokemon, index, StringName(str(given_moves[index])))
	# 7. Its held item.
	pokemon.held_item = StringName(str(options["held_item"])) if options.has("held_item") else _held_item(data)
	# 8. Its ability.
	if options.has("ability"):
		pokemon.ability = StringName(str(options["ability"]))
	else:
		var draw := draw(0, 99)
		var index := ABILITY_CHANCES.find_custom(func(chance: int) -> bool: return chance > draw)
		pokemon.ability_index = index
		pokemon.ability = data.abilities[index] if index < data.abilities.size() else &""
	pokemon.pokerus = int(options.get("pokerus", 0))
	return pokemon


## A number drawn from `from` to `to`, both included: every draw of a
## Pokémon goes through here. A span past 31 bits is drawn on 32.
func draw(from: int, to: int) -> int:
	if to - from < 0x7FFFFFFF:
		return random.randi_range(from, to)
	var drawn := random.randi()
	while drawn > to - from:
		drawn = random.randi()
	return from + drawn


## Binds `pokemon` to the game's data; true if its species is known.
func bind(pokemon: WgPokemon) -> bool:
	pokemon.maker = self
	return _species.has(pokemon.species)


func species_of(pokemon: WgPokemon) -> WgSpecies:
	return _species.find(pokemon.species)


func form_of(pokemon: WgPokemon) -> WgSpeciesForm:
	return _species.form(pokemon.species, pokemon.form)


func nature_of(pokemon: WgPokemon) -> WgNature:
	return _natures.of_number(pokemon.nature)


func move_of(move: StringName) -> WgMove:
	return _moves.find(move)


func state() -> Dictionary:
	return {"level_limit": level_limit}


func restore(saved: Dictionary) -> void:
	level_limit = int(saved.get("level_limit", config().max_level))


func reset() -> void:
	level_limit = config().max_level


func _shiny_tries() -> int:
	return 1 + (SHINY_CHARM_TRIES if _bag != null and _bag.count(SHINY_CHARM) > 0 else 0)


func _catch(pokemon: WgPokemon, options: Dictionary) -> void:
	pokemon.ball = StringName(str(options.get("ball", "poke_ball")))
	pokemon.caught_at = int(options["caught_at"]) if options.has("caught_at") else int(now.call())
	pokemon.caught_level = int(options.get("caught_level", pokemon.level))
	var zone := _zones.current() if _zones != null else null
	pokemon.caught_in = StringName(str(options["caught_in"])) if options.has("caught_in") else (zone.id if zone != null else &"")
	pokemon.trainer_id = int(options.get("trainer_id", _trainer.id))
	pokemon.trainer_name = str(options.get("trainer_name", _trainer.name))
	pokemon.caught_by_player = pokemon.trainer_id == _trainer.id and pokemon.trainer_name == _trainer.name
	pokemon.nickname = str(options.get("nickname", ""))


## Given, else drawn by the species' rate; its rate wins at -1, 0 and 100.
func _gender(data: WgSpeciesForm, options: Dictionary) -> WgPokemon.Gender:
	var gender := int(options["gender"]) if options.has("gender") else (WgPokemon.Gender.FEMALE if draw(0, 99) < data.female_rate else WgPokemon.Gender.MALE)
	if data.female_rate == -1:
		return WgPokemon.Gender.NONE
	if data.female_rate == 0:
		return WgPokemon.Gender.MALE
	if data.female_rate == 100:
		return WgPokemon.Gender.FEMALE
	return clampi(gender, 0, 2) as WgPokemon.Gender


## The number given, or a nature's id given, else the code's high 16 bits;
## modulo the natures' count.
func _nature_number(pokemon: WgPokemon, options: Dictionary) -> int:
	var count := maxi(_natures.count(), 1)
	var given: Variant = options.get("nature")
	if given is String or given is StringName:
		var found := _natures.find(StringName(given))
		given = found.number if found != null else null
	return (int(given) if given != null else pokemon.code >> 16) % count


## The moves learnt by level, from 0 to its level, the highest first, each
## once, until `MOVES`; then in level order. Moves of one level keep the
## species' order; a move the game does not have is left out, logged once.
func _learn_by_level(pokemon: WgPokemon, data: WgSpeciesForm) -> void:
	var by_level: Array[Dictionary] = []
	for index in data.moves.size():
		var entry: Dictionary = data.moves[index]
		if entry.get("how") == &"level" and int(entry.get("level", 0)) >= 0 and int(entry.get("level", 0)) <= pokemon.level:
			by_level.append({"move": StringName(str(entry["move"])), "level": int(entry["level"]), "at": index})
	by_level.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["level"] > b["level"] if a["level"] != b["level"] else a["at"] > b["at"])
	var chosen: Array[WgMoveSlot] = []
	for entry in by_level:
		var move: StringName = entry["move"]
		if chosen.size() >= WgPokemon.MOVES or chosen.any(func(slot: WgMoveSlot) -> bool: return slot.move == move):
			continue
		var found := _moves.find(move)
		if found == null:
			continue
		chosen.append(WgMoveSlot.of(move, found.pp))
		if move not in pokemon.learnt_moves:
			pokemon.learnt_moves.append(move)
	chosen.reverse()
	pokemon.moves = chosen


func _replace_move(pokemon: WgPokemon, index: int, move: StringName) -> void:
	var found := _moves.find(move)
	if found == null:
		return
	var slot := WgMoveSlot.of(move, found.pp)
	if index < pokemon.moves.size():
		pokemon.moves[index] = slot
	else:
		pokemon.moves.append(slot)
	if move not in pokemon.learnt_moves:
		pokemon.learnt_moves.append(move)


## A draw from 0 to 99 walking down the species' chances.
func _held_item(data: WgSpeciesForm) -> StringName:
	var draw := float(draw(0, 99))
	for held: Dictionary in data.held_items:
		var chance := float(held.get("chance", 0))
		if draw < chance:
			return StringName(str(held.get("item", "")))
		draw -= chance
	return &""
