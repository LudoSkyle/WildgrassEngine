extends GdUnitTestSuite

# The party (feature 23): Pokémon made by the tests' maker, added, moved,
# kept by the save through JSON as a save file holds it.

const World := preload("res://tests/support/walking_world.gd")

var _world: World


func before_test() -> void:
	_world = World.new(self)
	_world.trainer.reset()
	_world.pokemon.reset()
	for id: StringName in [&"pichu", &"eevee", &"ralts"]:
		var species := WgSpecies.new()
		species.id = id
		var form := WgSpeciesForm.new()
		form.base_stats.assign({&"hp": 40, &"attack": 40, &"defense": 40, &"speed": 40, &"special_attack": 40, &"special_defense": 40})
		form.abilities.assign([&"static", &"run_away", &"lightning_rod"])
		form.female_rate = 50.0
		species.forms.append(form)
		var second := WgSpeciesForm.new()
		second.form = 1
		second.base_stats.assign(form.base_stats)
		second.abilities.assign([&"plus", &"minus", &"telepathy"])
		species.forms.append(second)
		_world.species.register(species)
	var move := WgMove.new()
	move.id = &"tackle"
	move.pp = 35
	_world.moves.register(move)
	var nature := WgNature.new()
	nature.id = &"hardy"
	_world.natures.register(nature)


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _made(species: StringName, level := 10, options := {}) -> WgPokemon:
	return _world.pokemon.make(species, level, options)


func _logged(text: String) -> Array:
	return _world.logged.filter(func(line: String) -> bool: return line.contains(text))


func test_added_bound_and_recorded_by_the_pokedex_an_egg_not() -> void:
	var written := WgPokemon.new()
	written.species = &"eevee"
	written.form = 1
	written.level = 5
	assert_bool(_world.party.add(written)).is_true()
	assert_object(written.maker).is_same(_world.pokemon)
	assert_bool(_world.pokedex.is_caught(&"eevee", 1)).is_true()
	assert_bool(_world.pokedex.is_seen(&"eevee", 1)).is_true()
	var egg := _made(&"ralts", 1, {})
	egg.steps_left = 2560
	assert_bool(_world.party.add(egg)).is_true()
	assert_bool(_world.pokedex.is_seen(&"ralts")).is_false()
	assert_bool(_world.party.add(written)).is_false()
	assert_int(_world.party.size()).is_equal(2)


func test_full_at_the_config_s_size_the_next_refused_and_logged() -> void:
	assert_int(WgPartyConfig.new().size).is_equal(6)
	_world.sandbox.write_json("config/party.json", {"size": 2})
	assert_bool(_world.party.add(_made(&"pichu"))).is_true()
	assert_bool(_world.party.is_full()).is_false()
	assert_bool(_world.party.add(_made(&"eevee"))).is_true()
	assert_bool(_world.party.is_full()).is_true()
	assert_bool(_world.party.add(_made(&"ralts"))).is_false()
	assert_bool(_world.pokedex.is_seen(&"ralts")).is_false()
	assert_array(_logged("ralts not added: the party is full")).has_size(1)


func test_removed_swapped_and_read_in_order_each_change_told() -> void:
	var told := [0]
	_world.party.changed.connect(func() -> void: told[0] += 1)
	for species: StringName in [&"pichu", &"eevee", &"ralts"]:
		_world.party.add(_made(species))
	assert_bool(_world.party.swap(0, 2)).is_true()
	assert_bool(_world.party.swap(0, 3)).is_false()
	assert_array(_world.party.all().map(func(pokemon: WgPokemon) -> StringName: return pokemon.species)).is_equal([&"ralts", &"eevee", &"pichu"])
	assert_that(_world.party.remove(1).species).is_equal(&"eevee")
	assert_object(_world.party.remove(5)).is_null()
	assert_object(_world.party.remove(2)).is_null()
	assert_object(_world.party.remove(-1)).is_null()
	assert_that(_world.party.at(1).species).is_equal(&"pichu")
	assert_object(_world.party.at(2)).is_null()
	assert_object(_world.party.at(-1)).is_null()
	assert_int(told[0]).is_equal(5)
	_world.party.all().clear()
	assert_int(_world.party.size()).is_equal(2)


func test_found_by_species_alive_counted_among_the_first_healed() -> void:
	for species: StringName in [&"pichu", &"eevee", &"ralts", &"eevee"]:
		_world.party.add(_made(species))
	assert_bool(_world.party.has(&"eevee")).is_true()
	assert_bool(_world.party.has(&"mew")).is_false()
	assert_int(_world.party.index_of(&"eevee")).is_equal(1)
	assert_int(_world.party.index_of(&"mew")).is_equal(-1)
	_world.party.at(0).set_hp(0)
	_world.party.at(1).steps_left = 10
	assert_int(_world.party.alive_count()).is_equal(2)
	assert_int(_world.party.alive_count(2)).is_equal(0)
	assert_int(_world.party.alive_count(3)).is_equal(1)
	assert_int(_world.party.alive_count(9)).is_equal(2)
	assert_that(_world.party.first_alive().species).is_equal(&"ralts")
	_world.party.at(2).set_hp(0)
	_world.party.at(3).set_hp(0)
	assert_object(_world.party.first_alive()).is_null()
	_world.party.heal()
	assert_int(_world.party.alive_count()).is_equal(3)
	assert_int(_world.party.at(0).hp).is_equal(_world.party.at(0).max_hp())


func test_kept_by_the_save_through_json_and_not_told_to_the_pokedex_again() -> void:
	var pichu := _made(&"pichu", 12, {"nickname": "Zap", "held_item": "oran_berry", "ivs": {"attack": 7}, "evs": {"hp": 252}, "moves": ["tackle"]})
	pichu.code = 0xFFFFFFFE
	pichu.status = &"burn"
	pichu.moves[0].pp = 3
	pichu.ribbons.append(&"champion")
	pichu.conditions[&"cool"] = 9
	_world.party.add(pichu)
	_world.party.add(_made(&"eevee"))
	var saved: Variant = JSON.parse_string(JSON.stringify(_world.party.state()))
	_world.pokedex.reset()
	_world.party.reset()
	assert_bool(_world.party.is_empty()).is_true()
	_world.party.restore(saved)
	assert_bool(_world.pokedex.is_seen(&"pichu")).is_false()
	var back := _world.party.at(0)
	assert_int(_world.party.size()).is_equal(2)
	assert_object(back.maker).is_same(_world.pokemon)
	assert_dict(back.to_data()).is_equal(pichu.to_data())
	assert_int(back.code).is_equal(0xFFFFFFFE)
	assert_that(back.status).is_equal(&"burn")
	assert_that(typeof(back.ivs.keys()[0])).is_equal(TYPE_STRING_NAME)
	assert_that(typeof(back.ivs[&"attack"])).is_equal(TYPE_INT)
	assert_int(back.ivs[&"attack"]).is_equal(7)
	assert_int(back.moves[0].pp).is_equal(3)
	assert_int(back.moves[0].max_pp).is_equal(35)
	assert_that(back.ribbons[0]).is_equal(&"champion")
	assert_int(back.stat(&"attack")).is_equal(pichu.stat(&"attack"))


func test_a_saved_pokemon_of_a_species_gone_is_kept_and_logged() -> void:
	_world.party.restore({"pokemon": [{"species": "missingno", "level": 3}, "not a pokemon"]})
	assert_int(_world.party.size()).is_equal(1)
	assert_int(_world.party.at(0).level).is_equal(3)
	assert_array(_logged("species 'missingno' is not in the game")).has_size(1)
