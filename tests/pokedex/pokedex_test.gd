extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")

var _world: World
var _events: Array[String] = []


func before_test() -> void:
	_world = World.new(self)
	_events = []
	for spec: Array in [[&"bulbasaur", 1], [&"ivysaur", 2], [&"pikachu", 25], [&"rattata", 19], [&"mew", 151]]:
		var species := WgSpecies.new()
		species.id = spec[0]
		species.number = spec[1]
		species.forms.append(WgSpeciesForm.new())
		_world.species.register(species)
	var pokedex := _world.pokedex
	pokedex.seen.connect(func(id: StringName, form: int, first: bool) -> void: _events.append("seen %s %d %s" % [id, form, first]))
	pokedex.caught.connect(func(id: StringName, form: int, first: bool) -> void: _events.append("caught %s %d %s" % [id, form, first]))


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _dex(id: StringName, species: Array, start := 1) -> WgDex:
	var dex := WgDex.new()
	dex.id = id
	dex.start = start
	for entry: Variant in species:
		dex.creatures.append({"species": entry, "form": 0} if entry is StringName else entry)
	return dex


func test_seeing_and_catching_keep_each_form_and_tell_the_first_time() -> void:
	var pokedex := _world.pokedex
	assert_bool(pokedex.see(&"rattata", 1)).is_true()
	assert_bool(pokedex.see(&"rattata", 1)).is_false()
	assert_bool(pokedex.catch(&"rattata")).is_true()
	assert_bool(pokedex.catch(&"rattata")).is_false()
	assert_array(_events).is_equal(["seen rattata 1 true", "seen rattata 1 false", "seen rattata 0 true", "caught rattata 0 true", "seen rattata 0 false", "caught rattata 0 false"])
	assert_array(pokedex.forms_seen(&"rattata")).is_equal([0, 1])
	assert_array(pokedex.forms_caught(&"rattata")).is_equal([0])
	assert_bool(pokedex.is_seen(&"rattata")).is_true()
	assert_bool(pokedex.is_caught(&"rattata", 1)).is_false()
	assert_bool(pokedex.is_caught(&"rattata")).is_true()
	assert_bool(pokedex.is_seen(&"mew")).is_false()
	pokedex.forget(&"rattata")
	assert_bool(pokedex.is_seen(&"rattata")).is_false()
	assert_bool(pokedex.is_caught(&"rattata")).is_false()


func test_an_unknown_species_is_refused() -> void:
	assert_bool(_world.pokedex.see(&"missingno")).is_false()
	assert_bool(_world.pokedex.catch(&"missingno")).is_false()
	assert_bool(_world.pokedex.is_seen(&"missingno")).is_false()
	assert_array(_events).is_empty()
	assert_array(_world.logged).is_equal(["ERROR unknown species 'missingno'"])


func test_a_pokedex_numbers_its_species_from_its_start_and_skips_unknown_ones() -> void:
	_world.pokedex.register(_dex(&"kanto", [&"pikachu", &"glitch", {"species": &"rattata", "form": 1}], 10))
	var kanto := _world.pokedex.find(&"kanto")
	assert_int(kanto.number_of(&"rattata")).is_equal(12)
	assert_int(kanto.number_of(&"mew")).is_equal(0)
	assert_array(_world.pokedex.entries(&"kanto")).is_equal([{"species": &"pikachu", "form": 0, "number": 10}, {"species": &"rattata", "form": 1, "number": 12}])
	_world.pokedex.entries(&"kanto")
	assert_array(_world.logged).is_equal(["WARN Pokédex 'kanto' lists an unknown species 'glitch'"])


func test_registered_then_the_folder_s_then_a_source_s_and_an_unknown_one_logged() -> void:
	DirAccess.make_dir_recursive_absolute(_world.sandbox.root + "dex")
	ResourceSaver.save(_dex(&"johto", [&"mew"]), _world.sandbox.root + "dex/johto.tres")
	_world.pokedex.add_source(func(id: StringName) -> WgDex: return _dex(&"", [&"bulbasaur"]) if id == &"hoenn" else null)
	assert_array(_world.pokedex.entries(&"johto").map(func(entry: Dictionary) -> StringName: return entry["species"])).is_equal([&"mew"])
	assert_str(_world.pokedex.find(&"hoenn").id).is_equal("hoenn")
	assert_object(_world.pokedex.find(&"sinnoh")).is_null()
	assert_array(_world.logged).is_equal(["ERROR unknown Pokédex 'sinnoh'"])


func test_the_national_one_is_every_species_by_national_number_unless_the_game_has_its_own() -> void:
	var numbers: Array[String] = []
	for entry in _world.pokedex.entries(&"national"):
		numbers.append("%d %s" % [entry["number"], entry["species"]])
	assert_array(numbers).is_equal(["1 bulbasaur", "2 ivysaur", "19 rattata", "25 pikachu", "151 mew"])
	assert_array(_world.logged).is_empty()
	_world.pokedex.register(_dex(&"national", [&"mew"]))
	assert_array(_world.pokedex.entries(&"national").map(func(entry: Dictionary) -> StringName: return entry["species"])).is_equal([&"mew"])


func test_counts_are_among_a_pokedex_s_species() -> void:
	_world.pokedex.register(_dex(&"kanto", [&"bulbasaur", &"ivysaur", &"pikachu"]))
	_world.pokedex.see(&"bulbasaur")
	_world.pokedex.catch(&"pikachu")
	_world.pokedex.catch(&"mew")
	assert_int(_world.pokedex.seen_count(&"kanto")).is_equal(2)
	assert_int(_world.pokedex.caught_count(&"kanto")).is_equal(1)
	assert_int(_world.pokedex.seen_count(&"national")).is_equal(3)


func test_the_player_s_pokedexes_start_from_the_config_and_grow() -> void:
	_world.sandbox.write_json("config/pokedex.json", {"dexes": ["kanto"]})
	_world.pokedex.register(_dex(&"kanto", [&"bulbasaur"]))
	var pokedex := _world.pokedex
	assert_array(pokedex.dexes).is_equal([&"kanto"])
	assert_str(pokedex.dex).is_equal("kanto")
	assert_bool(pokedex.add_dex(&"national")).is_true()
	assert_bool(pokedex.add_dex(&"national")).is_false()
	assert_bool(pokedex.add_dex(&"sinnoh")).is_false()
	assert_array(pokedex.dexes).is_equal([&"kanto", &"national"])
	pokedex.dex = &"national"
	assert_str(pokedex.dex).is_equal("national")
	pokedex.dex = &"elsewhere"
	assert_str(pokedex.dex).is_equal("kanto")


func test_an_empty_list_of_pokedexes_is_corrected() -> void:
	_world.sandbox.write_json("config/pokedex.json", {"dexes": []})
	assert_array(_world.pokedex.dexes).is_equal([&"national"])
	assert_array(_world.logged).is_equal(["WARN pokedex.json: dexes needs a Pokédex; using national"])


func test_saved_and_restored_whole_a_new_game_seeing_nothing() -> void:
	_world.save.add_part(&"pokedex", _world.pokedex.state, _world.pokedex.restore, _world.pokedex.reset)
	_world.hooks.add(&"save_summary", &"pokedex", _world.pokedex.save_summary)
	_world.pokedex.register(_dex(&"kanto", [&"bulbasaur", &"rattata"]))
	var pokedex := _world.pokedex
	pokedex.see(&"rattata", 1)
	pokedex.catch(&"rattata")
	pokedex.see(&"mew")
	pokedex.add_dex(&"kanto")
	pokedex.dex = &"kanto"
	assert_bool(_world.save.write(1)).is_true()
	assert_float(_world.save.summary(1)["pokedex"]).is_equal(1.0)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_world.save.path_of(1)))["parts"]["pokedex"]
	assert_that(saved).is_equal({"seen": {"rattata": [0.0, 1.0], "mew": [0.0]}, "caught": {"rattata": [0.0]}, "dexes": ["national", "kanto"], "dex": "kanto"})
	_world.save.new_game(2)
	assert_bool(pokedex.is_seen(&"rattata")).is_false()
	assert_array(pokedex.dexes).is_equal([&"national"])
	assert_bool(await _world.save.load_game(1)).is_true()
	assert_array(pokedex.forms_seen(&"rattata")).is_equal([0, 1])
	assert_bool(pokedex.is_caught(&"rattata", 0)).is_true()
	assert_bool(pokedex.is_seen(&"mew")).is_true()
	assert_str(pokedex.dex).is_equal("kanto")
