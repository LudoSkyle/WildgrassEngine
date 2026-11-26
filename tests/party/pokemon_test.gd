extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const PokemonMaker := preload("res://addons/wildgrass/party/pokemon_maker.gd")
const G := WgPokemon.Gender


## A maker whose draws are written by the test, in order; none left: 0.
class ScriptedMaker extends PokemonMaker:
	var rolls: Array[int] = []
	var asked: Array[String] = []

	func draw(from: int, to: int) -> int:
		asked.append("%d-%d" % [from, to])
		return rolls.pop_front() if not rolls.is_empty() else 0


var _world: World
var _maker: ScriptedMaker


func before_test() -> void:
	_world = World.new(self)
	_maker = ScriptedMaker.new(_world.logger, _world.config, _world.species, _world.natures, _world.moves, _world.bag, _world.trainer, _world.zones)
	_maker.now = func() -> int: return 1700000000
	_maker.reset()
	_world.trainer.reset()
	_world.trainer.boy_id = 4242
	_species(&"pichu", 50.0)
	for pair: Array in [[&"hardy", 0, {}], [&"lonely", 1, {&"attack": 110, &"defense": 90}], [&"brave", 2, {&"attack": 110, &"speed": 90}]]:
		var nature := WgNature.new()
		nature.id = pair[0]
		nature.number = pair[1]
		nature.stats.assign(pair[2])
		_world.natures.register(nature)
	for pair: Array in [[&"thunder_shock", 30], [&"charm", 20], [&"tail_whip", 30], [&"sweet_kiss", 10], [&"nasty_plot", 20], [&"thunderbolt", 15]]:
		var move := WgMove.new()
		move.id = pair[0]
		move.pp = pair[1]
		_world.moves.register(move)


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _species(id: StringName, female_rate: float, forms := 1) -> WgSpecies:
	var species := WgSpecies.new()
	species.id = id
	species.name = "Pichu"
	for number in forms:
		var form := WgSpeciesForm.new()
		form.form = number
		form.base_stats.assign({&"hp": 20, &"attack": 40, &"defense": 15, &"speed": 60, &"special_attack": 35, &"special_defense": 35})
		form.growth_rate = WgExperience.Growth.NORMAL
		form.base_friendship = 70
		form.female_rate = female_rate
		form.abilities.assign([&"static", &"static", &"lightning_rod"])
		form.held_items.assign([{"item": &"oran_berry", "chance": 50.0}, {"item": &"sitrus_berry", "chance": 5.0}])
		form.moves.assign([
			{"move": &"thunder_shock", "how": &"level", "level": 1}, {"move": &"charm", "how": &"level", "level": 1},
			{"move": &"tail_whip", "how": &"level", "level": 5}, {"move": &"sweet_kiss", "how": &"level", "level": 8},
			{"move": &"nasty_plot", "how": &"level", "level": 13}, {"move": &"thunderbolt", "how": &"tm", "level": 0},
			{"move": &"charm", "how": &"level", "level": 10},
		])
		species.forms.append(form)
	_world.species.register(species)
	return species


## Rolls in the maker's order: code, gender, the six IVs, held item, ability.
func _rolls(code: int, gender := 0, ivs: Array[int] = [31, 30, 29, 28, 27, 26], item := 99, ability := 0) -> Array[int]:
	var rolls: Array[int] = [code, gender]
	rolls.append_array(ivs)
	rolls.append_array([item, ability])
	return rolls


func test_made_in_the_reference_s_order() -> void:
	_maker.rolls = _rolls(0x00020123)
	var pichu := _maker.make(&"pichu", 10)
	assert_array(_maker.asked).is_equal(["0-4294967294", "0-99", "0-31", "0-31", "0-31", "0-31", "0-31", "0-31", "0-99", "0-99"])
	assert_array([pichu.species, pichu.form, pichu.level, pichu.experience, pichu.code]).is_equal([&"pichu", 0, 10, 1000, 0x00020123])
	assert_bool(pichu.is_shiny()).is_false()
	assert_int(pichu.gender).is_equal(G.FEMALE)
	assert_that(pichu.ivs).is_equal({&"hp": 31, &"attack": 30, &"defense": 29, &"speed": 28, &"special_attack": 27, &"special_defense": 26})
	assert_that(pichu.evs).is_equal({&"hp": 0, &"attack": 0, &"defense": 0, &"speed": 0, &"special_attack": 0, &"special_defense": 0})
	assert_int(pichu.nature).is_equal(2)
	assert_int(pichu.friendship).is_equal(70)
	assert_int(pichu.hp).is_equal(pichu.max_hp())
	assert_str(pichu.held_item).is_empty()
	assert_array([pichu.ability, pichu.ability_index]).is_equal([&"static", 0])
	assert_array([pichu.ball, pichu.caught_at, pichu.caught_level, pichu.caught_in, pichu.trainer_id, pichu.trainer_name]).is_equal([&"poke_ball", 1700000000, 10, &"", 4242, "Alex"])
	assert_bool(pichu.caught_by_player).is_true()
	assert_array(_world.logged).is_empty()


func test_the_stats_follow_the_reference_s_formulas() -> void:
	_maker.rolls = _rolls(0x00010000)
	var pichu := _maker.make(&"pichu", 50, {"evs": {&"hp": 252, &"attack": 7}})
	# HP: (31 + 40 + 63) * 50 / 100 + 10 + 50; attack, lonely: ((80 + 1 + 30) * 50 / 100 + 5) * 110 / 100.
	assert_int(pichu.max_hp()).is_equal(127)
	assert_int(pichu.stat(&"hp")).is_equal(127)
	assert_int(pichu.stat(&"attack")).is_equal(66)
	# Defense, lonely 90: ((30 + 29) * 50 / 100 + 5) * 90 / 100 = 30.
	assert_int(pichu.stat(&"defense")).is_equal(30)
	assert_int(pichu.stat(&"speed")).is_equal(79)


func test_shedinja_has_1_hp() -> void:
	_species(&"shedinja", -1.0)
	_maker.rolls = _rolls(0)
	assert_int(_maker.make(&"shedinja", 50).max_hp()).is_equal(1)


func test_a_code_whose_low_16_bits_are_below_16_is_shiny() -> void:
	_maker.rolls = _rolls(0xABCD000F)
	assert_bool(_maker.make(&"pichu", 5).is_shiny()).is_true()
	_maker.rolls = _rolls(0xABCD0010)
	assert_bool(_maker.make(&"pichu", 5).is_shiny()).is_false()


func test_the_shiny_charm_gives_two_more_tries() -> void:
	_world.bag._counts[&"shiny_charm"] = 1
	_maker.rolls = [0x1000, 0x2000, 0x3000, 0]
	assert_int(_maker.make(&"pichu", 5).code).is_equal(0x3000)
	_maker.rolls = [0x1000, 0x0005, 0x3000, 0]
	assert_int(_maker.make(&"pichu", 5).code).is_equal(0x0005)


func test_shiny_forced_either_way() -> void:
	_maker.rolls = _rolls(0x12345678)
	var shiny := _maker.make(&"pichu", 5, {"shiny": true})
	assert_bool(shiny.is_shiny()).is_true()
	assert_int(shiny.code).is_equal(0x12340000)
	_maker.rolls = _rolls(0x12340003)
	var plain := _maker.make(&"pichu", 5, {"shiny": false})
	assert_bool(plain.is_shiny()).is_false()
	assert_int(plain.code).is_equal(0x1234FFFF)


func test_the_level_is_at_least_1_and_not_bounded_by_the_limit() -> void:
	_maker.rolls = _rolls(0)
	assert_int(_maker.make(&"pichu", 0).level).is_equal(1)
	_maker.rolls = _rolls(0)
	assert_int(_maker.make(&"pichu", 120).level).is_equal(120)


func test_female_below_the_rate_male_from_it() -> void:
	_species(&"azurill", 75.0)
	_maker.rolls = _rolls(0, 74)
	assert_int(_maker.make(&"azurill", 5).gender).is_equal(G.FEMALE)
	_maker.rolls = _rolls(0, 75)
	assert_int(_maker.make(&"azurill", 5).gender).is_equal(G.MALE)
	_species(&"bulbasaur", 12.5)
	_maker.rolls = _rolls(0, 12)
	assert_int(_maker.make(&"bulbasaur", 5).gender).is_equal(G.FEMALE)
	_maker.rolls = _rolls(0, 13)
	assert_int(_maker.make(&"bulbasaur", 5).gender).is_equal(G.MALE)


func test_the_rate_wins_over_a_gender_given_at_minus_1_0_and_100() -> void:
	for pair: Array in [[&"magnemite", -1.0, G.NONE], [&"tauros", 0.0, G.MALE], [&"chansey", 100.0, G.FEMALE]]:
		_species(pair[0], pair[1])
		_maker.rolls = _rolls(0, 0)
		assert_int(_maker.make(pair[0], 5).gender).is_equal(pair[2])
		_maker.rolls = _rolls(0)
		assert_int(_maker.make(pair[0], 5, {"gender": G.FEMALE if pair[2] != G.FEMALE else G.MALE}).gender).is_equal(pair[2])
	_maker.rolls = _rolls(0, 0)
	assert_int(_maker.make(&"pichu", 5, {"gender": G.MALE}).gender).is_equal(G.MALE)


func test_the_nature_from_the_code_s_high_bits_modulo_the_count() -> void:
	_maker.rolls = _rolls(0x00070000)
	assert_int(_maker.make(&"pichu", 5).nature).is_equal(1)
	_maker.rolls = _rolls(0x00070000)
	assert_int(_maker.make(&"pichu", 5, {"nature": 4}).nature).is_equal(1)
	_maker.rolls = _rolls(0x00070000)
	assert_int(_maker.make(&"pichu", 5, {"nature": &"brave"}).nature).is_equal(2)


func test_the_moves_learnt_by_level_the_last_four_in_level_order() -> void:
	_maker.rolls = _rolls(0)
	var at_10 := _maker.make(&"pichu", 10)
	assert_array(at_10.moves.map(func(slot: WgMoveSlot) -> StringName: return slot.move)).is_equal([&"thunder_shock", &"tail_whip", &"sweet_kiss", &"charm"])
	assert_array(at_10.moves.map(func(slot: WgMoveSlot) -> int: return slot.pp)).is_equal([30, 30, 10, 20])
	assert_array(at_10.learnt_moves).contains_exactly_in_any_order([&"thunder_shock", &"tail_whip", &"sweet_kiss", &"charm"])
	_maker.rolls = _rolls(0)
	var at_4 := _maker.make(&"pichu", 4)
	assert_array(at_4.moves.map(func(slot: WgMoveSlot) -> StringName: return slot.move)).is_equal([&"thunder_shock", &"charm"])
	_maker.rolls = _rolls(0)
	var at_20 := _maker.make(&"pichu", 20)
	assert_array(at_20.moves.map(func(slot: WgMoveSlot) -> StringName: return slot.move)).is_equal([&"tail_whip", &"sweet_kiss", &"charm", &"nasty_plot"])


func test_moves_given_replace_from_the_first() -> void:
	_maker.rolls = _rolls(0)
	var pichu := _maker.make(&"pichu", 4, {"moves": [&"thunderbolt", &"charm", &"nasty_plot"]})
	assert_array(pichu.moves.map(func(slot: WgMoveSlot) -> StringName: return slot.move)).is_equal([&"thunderbolt", &"charm", &"nasty_plot"])
	assert_bool(&"thunderbolt" in pichu.learnt_moves).is_true()


func test_the_held_item_walks_down_the_chances() -> void:
	for pair: Array in [[49, &"oran_berry"], [50, &"sitrus_berry"], [54, &"sitrus_berry"], [55, &""]]:
		_maker.rolls = _rolls(0, 0, [0, 0, 0, 0, 0, 0], pair[0])
		assert_str(_maker.make(&"pichu", 5).held_item).is_equal(pair[1])
	_maker.rolls = _rolls(0)
	assert_str(_maker.make(&"pichu", 5, {"held_item": &"light_ball"}).held_item).is_equal("light_ball")


func test_the_ability_49_49_2() -> void:
	for pair: Array in [[48, 0, &"static"], [49, 1, &"static"], [97, 1, &"static"], [98, 2, &"lightning_rod"], [99, 2, &"lightning_rod"]]:
		_maker.rolls = _rolls(0, 0, [0, 0, 0, 0, 0, 0], 99, pair[0])
		var pichu := _maker.make(&"pichu", 5)
		assert_array([pichu.ability_index, pichu.ability]).is_equal([pair[1], pair[2]])
	_maker.rolls = _rolls(0)
	assert_str(_maker.make(&"pichu", 5, {"ability": &"lightning_rod"}).ability).is_equal("lightning_rod")


func test_options_given_are_not_drawn() -> void:
	_maker.rolls = [0x00000100]
	var given := _maker.make(&"pichu", 7, {
		"gender": G.MALE, "ivs": {&"hp": 1, &"attack": 2, &"defense": 3, &"speed": 4, &"special_attack": 5, &"special_defense": 40},
		"held_item": &"", "ability": &"static", "friendship": 300, "nickname": "Zap", "ball": &"great_ball",
		"caught_at": 5, "caught_level": 3, "caught_in": &"route_1", "trainer_name": "Prof", "trainer_id": 1,
	})
	assert_array(_maker.asked).is_equal(["0-4294967294"])
	assert_int(given.ivs[&"special_defense"]).is_equal(31)
	assert_int(given.friendship).is_equal(255)
	assert_array([given.nickname, given.ball, given.caught_at, given.caught_level, given.caught_in, given.trainer_name, given.trainer_id]).is_equal(["Zap", &"great_ball", 5, 3, &"route_1", "Prof", 1])
	assert_bool(given.caught_by_player).is_false()
	_maker.rolls = _rolls(0)
	assert_bool(_maker.make(&"pichu", 7, {"trainer_name": "Prof"}).caught_by_player).is_false()
	assert_str(given.display_name()).is_equal("Zap")


func test_a_form_the_species_has_not_is_form_0() -> void:
	_species(&"rotom", -1.0, 3)
	_maker.rolls = _rolls(0)
	assert_int(_maker.make(&"rotom", 5, {"form": 2}).form).is_equal(2)
	_maker.rolls = _rolls(0)
	assert_int(_maker.make(&"rotom", 5, {"form": 7}).form).is_equal(0)
	assert_array(_world.logged).is_empty()


func test_set_form_to_one_its_species_has_its_ability_following() -> void:
	var rotom := _species(&"rotom", -1.0, 3)
	rotom.forms[2].abilities.assign([&"levitate", &"motor_drive", &"heatproof"])
	_maker.rolls = _rolls(0, 0, [31, 30, 29, 28, 27, 26], 99, 60)
	var made := _maker.make(&"rotom", 5)
	assert_that(made.ability).is_equal(&"static")
	assert_bool(made.set_form(2)).is_true()
	assert_int(made.form).is_equal(2)
	assert_that(made.ability).is_equal(&"motor_drive")
	assert_bool(made.set_form(7)).is_false()
	assert_int(made.form).is_equal(2)
	_maker.rolls = _rolls(0)
	var given := _maker.make(&"rotom", 5, {"ability": "pressure"})
	assert_bool(given.set_form(2)).is_true()
	assert_that(given.ability).is_equal(&"pressure")


func test_unown_s_form_follows_its_code_meowstic_s_its_gender() -> void:
	_species(&"unown", -1.0, 28)
	_maker.rolls = _rolls(30)
	assert_int(_maker.make(&"unown", 5).form).is_equal(2)
	_maker.rolls = _rolls(30)
	assert_int(_maker.make(&"unown", 5, {"form": 5}).form).is_equal(5)
	_species(&"meowstic", 50.0, 2)
	_maker.rolls = _rolls(0, 10)
	assert_int(_maker.make(&"meowstic", 5).form).is_equal(1)
	_maker.rolls = _rolls(0, 90)
	assert_int(_maker.make(&"meowstic", 5).form).is_equal(0)


func test_the_zone_it_is_caught_in_is_the_current_one() -> void:
	var zone := WgZone.new()
	zone.id = &"pallet"
	_world.zones.register(zone)
	var map := _world.map()
	map.zone = &"pallet"
	_world.maps.current = map
	_maker.rolls = _rolls(0)
	assert_str(_maker.make(&"pichu", 5).caught_in).is_equal("pallet")


func test_an_unknown_species_is_logged_and_makes_none() -> void:
	assert_object(_maker.make(&"missingno", 5)).is_null()
	assert_array(_world.logged).is_equal(["ERROR unknown species 'missingno'"])


func test_hp_at_0_ends_the_status_and_heal_restores_all() -> void:
	_maker.rolls = _rolls(0)
	var pichu := _maker.make(&"pichu", 10)
	pichu.status = &"burn"
	pichu.moves[0].pp = 3
	pichu.set_hp(0)
	assert_array([pichu.hp, pichu.status]).is_equal([0, &""])
	assert_bool(pichu.is_alive()).is_false()
	pichu.status = &"sleep"
	pichu.status_count = 2
	pichu.heal()
	assert_array([pichu.hp, pichu.status, pichu.status_count, pichu.moves[0].pp]).is_equal([pichu.max_hp(), &"", 0, 30])
	pichu.steps_left = 10
	assert_bool(pichu.is_egg()).is_true()
	assert_bool(pichu.is_alive()).is_false()
	pichu.steps_left = 0
	pichu.set_hp(9999)
	assert_int(pichu.hp).is_equal(pichu.max_hp())
	assert_bool(pichu.is_alive()).is_true()


func test_learn_as_when_growing_the_oldest_forgotten() -> void:
	_maker.rolls = _rolls(0)
	var pichu := _maker.make(&"pichu", 10)
	assert_bool(pichu.learn(&"charm")).is_false()
	assert_bool(pichu.learn(&"thunderbolt")).is_true()
	assert_array(pichu.moves.map(func(slot: WgMoveSlot) -> StringName: return slot.move)).is_equal([&"tail_whip", &"sweet_kiss", &"charm", &"thunderbolt"])
	assert_bool(pichu.knows(&"thunder_shock")).is_false()
	assert_bool(&"thunder_shock" in pichu.learnt_moves).is_true()
	assert_bool(pichu.learn(&"hyper_beam")).is_false()
	pichu.forget(&"charm")
	assert_array(pichu.moves.map(func(slot: WgMoveSlot) -> StringName: return slot.move)).is_equal([&"tail_whip", &"sweet_kiss", &"thunderbolt"])


func test_set_level_within_the_limit_its_experience_that_level_s() -> void:
	_maker.rolls = _rolls(0)
	var pichu := _maker.make(&"pichu", 10)
	pichu.set_level(20)
	assert_array([pichu.level, pichu.experience]).is_equal([20, 8000])
	_maker.level_limit = 30
	pichu.set_level(50)
	assert_array([pichu.level, pichu.experience]).is_equal([30, 27000])
	pichu.set_level(-3)
	assert_int(pichu.level).is_equal(1)


func test_the_level_limit_is_the_config_s_and_kept_by_the_save() -> void:
	_world.sandbox.write_json("config/pokemon.json", {"max_level": 70})
	_world.config.register(&"pokemon", WgPokemonConfig, "pokemon")
	_maker.reset()
	assert_int(_maker.level_limit).is_equal(70)
	_maker.level_limit = 80
	var saved: Dictionary = JSON.parse_string(JSON.stringify(_maker.state()))
	_maker.reset()
	_maker.restore(saved)
	assert_int(_maker.level_limit).is_equal(80)


func test_a_pokemon_written_by_hand_works_once_bound() -> void:
	var pichu := WgPokemon.new()
	pichu.species = &"pichu"
	pichu.level = 50
	assert_int(pichu.max_hp()).is_equal(0)
	assert_bool(_maker.bind(pichu)).is_true()
	assert_int(pichu.max_hp()).is_equal(80)
	assert_str(pichu.display_name()).is_equal("Pichu")
	pichu.species = &"missingno"
	assert_bool(_maker.bind(pichu)).is_false()


func test_codes_are_drawn_on_32_bits_below_0xffffffff() -> void:
	_world.pokemon.random.seed = 11
	var high := 0
	for _try in 400:
		var code := _world.pokemon.draw(0, PokemonMaker.CODE_RANGE - 1)
		assert_bool(code >= 0 and code < 0xFFFFFFFF).is_true()
		high = maxi(high, code)
	assert_int(high).is_greater(0x80000000)
	assert_int(_world.pokemon.draw(3, 3)).is_equal(3)


func test_a_move_the_game_has_not_is_left_out() -> void:
	_world.species.find(&"pichu").forms[0].moves.push_front({"move": &"kings_shield", "how": &"level", "level": 9})
	_maker.rolls = _rolls(0)
	var pichu := _maker.make(&"pichu", 10)
	assert_array(pichu.moves.map(func(slot: WgMoveSlot) -> StringName: return slot.move)).is_equal([&"thunder_shock", &"tail_whip", &"sweet_kiss", &"charm"])
	assert_array(_world.logged).is_equal(["ERROR unknown move 'kings_shield'"])


func test_the_engine_s_maker_draws_by_its_generator() -> void:
	_world.pokemon.random.seed = 3
	var first := _world.pokemon.make(&"pichu", 5)
	_world.pokemon.random.seed = 3
	var again := _world.pokemon.make(&"pichu", 5)
	assert_array([first.code, first.ivs, first.gender]).is_equal([again.code, again.ivs, again.gender])
