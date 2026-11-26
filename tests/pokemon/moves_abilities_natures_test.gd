extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")

var _world: World


func before_test() -> void:
	_world = World.new(self)


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _move(id: StringName, number: int) -> WgMove:
	var move := WgMove.new()
	move.id = id
	move.number = number
	return move


func _nature(id: StringName, number: int, stats: Dictionary[StringName, int] = {}) -> WgNature:
	var nature := WgNature.new()
	nature.id = id
	nature.number = number
	nature.stats = stats
	return nature


func test_moves_registered_then_the_folder_s_then_a_source_s() -> void:
	DirAccess.make_dir_recursive_absolute(_world.sandbox.root + "moves")
	var pound := _move(&"", 1)
	pound.power = 40
	ResourceSaver.save(pound, _world.sandbox.root + "moves/pound.tres")
	var tackle := _move(&"tackle", 33)
	_world.moves.register(tackle)
	_world.moves.add_source(func(id: StringName) -> WgMove: return _move(&"", 10) if id == &"scratch" else null, func() -> Array: return [&"scratch"])
	assert_object(_world.moves.find(&"tackle")).is_same(tackle)
	assert_int(_world.moves.find(&"pound").power).is_equal(40)
	assert_str(_world.moves.find(&"pound").id).is_equal("pound")
	assert_bool(_world.moves.has(&"scratch")).is_true()
	assert_bool(_world.moves.has(&"splash")).is_false()
	assert_array(_world.moves.all().map(func(move: WgMove) -> StringName: return move.id)).is_equal([&"pound", &"scratch", &"tackle"])
	assert_array(_world.logged).is_empty()


func test_an_unknown_move_or_ability_is_logged_once() -> void:
	assert_object(_world.moves.find(&"splash")).is_null()
	assert_object(_world.moves.find(&"splash")).is_null()
	assert_object(_world.abilities.find(&"levitate")).is_null()
	assert_array(_world.logged).is_equal(["ERROR unknown move 'splash'", "ERROR unknown ability 'levitate'"])


func test_abilities_by_number() -> void:
	for pair: Array in [[&"stench", 1], [&"overgrow", 65], [&"drizzle", 2]]:
		var ability := WgAbility.new()
		ability.id = pair[0]
		ability.number = pair[1]
		_world.abilities.register(ability)
	assert_array(_world.abilities.all().map(func(ability: WgAbility) -> StringName: return ability.id)).is_equal([&"stench", &"drizzle", &"overgrow"])
	assert_array(_world.abilities.ids()).contains_exactly_in_any_order([&"stench", &"drizzle", &"overgrow"])


func test_a_move_s_flags() -> void:
	var move := _move(&"mach_punch", 183)
	move.flags = [&"contact", &"punch"]
	assert_bool(move.has_flag(&"punch")).is_true()
	assert_bool(move.has_flag(&"sound")).is_false()


func test_natures_are_counted_and_found_by_number() -> void:
	_world.natures.register(_nature(&"lonely", 1))
	_world.natures.register(_nature(&"hardy", 0))
	_world.natures.add_source(func(id: StringName) -> WgNature: return _nature(&"", 2) if id == &"brave" else null, func() -> Array: return [&"brave"])
	assert_int(_world.natures.count()).is_equal(3)
	assert_str(_world.natures.of_number(2).id).is_equal("brave")
	assert_str(_world.natures.of_number(0).id).is_equal("hardy")
	assert_array(_world.natures.all().map(func(nature: WgNature) -> StringName: return nature.id)).is_equal([&"hardy", &"lonely", &"brave"])
	assert_array(_world.logged).is_empty()


func test_a_nature_registered_later_is_counted() -> void:
	_world.natures.register(_nature(&"hardy", 0))
	assert_int(_world.natures.count()).is_equal(1)
	_world.natures.register(_nature(&"lonely", 1))
	assert_int(_world.natures.count()).is_equal(2)
	assert_str(_world.natures.of_number(1).id).is_equal("lonely")


func test_a_number_no_nature_has_is_logged() -> void:
	_world.natures.register(_nature(&"hardy", 0))
	_world.natures.register(_nature(&"brave", 2))
	assert_object(_world.natures.of_number(1)).is_null()
	assert_array(_world.logged).is_equal(["ERROR no nature numbered 1"])


func test_a_nature_s_factor_and_a_stat_it_does_not_name() -> void:
	var adamant := _nature(&"adamant", 3, {&"attack": 110, &"special_attack": 90})
	assert_int(adamant.factor(&"attack")).is_equal(110)
	assert_int(adamant.factor(&"special_attack")).is_equal(90)
	assert_int(adamant.factor(&"speed")).is_equal(100)


func test_the_pokemon_config_s_max_level() -> void:
	assert_int((_world.config.get_config(&"pokemon") as WgPokemonConfig).max_level).is_equal(100)
	_world.sandbox.write_json("config/pokemon.json", {"max_level": 0})
	_world.config.register(&"pokemon", WgPokemonConfig, "pokemon")
	assert_int((_world.config.get_config(&"pokemon") as WgPokemonConfig).max_level).is_equal(100)
	assert_array(_world.logged).contains(["WARN pokemon.json: max_level 0 is below 1; using 100"])
