extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")

var _world: World
var _node: WgEncounters


func before_test() -> void:
	_world = World.new(self)
	for id: StringName in [&"rattata", &"pidgey", &"caterpie", &"zubat"]:
		var species := WgSpecies.new()
		species.id = id
		species.forms.append(WgSpeciesForm.new())
		_world.species.register(species)
	var map := _world.map()
	_node = WgEncounters.new()
	map.add_child(_node)
	_world.encounters.seed(7)


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _table(id: StringName, pokemon: Array[Dictionary], terrain := &"grass") -> WgEncounterTable:
	var table := WgEncounterTable.new()
	table.id = id
	table.terrain = terrain
	table.pokemon = pokemon
	return table


func _draws(count: int, terrain := &"grass", tool := &"", area := 0) -> Dictionary:
	var seen := {}
	for draw in count:
		var pokemon := _world.encounters.draw(terrain, tool, area)
		var key := "%s %d" % [pokemon.get("species", "-"), pokemon.get("level", 0)]
		seen[key] = seen.get(key, 0) + 1
	return seen


func test_a_draw_picks_by_weight_and_a_level_between_the_two() -> void:
	_node.tables.append(_table(&"route", [
		{"species": &"rattata", "min_level": 2, "max_level": 4, "weight": 3},
		{"species": &"pidgey", "min_level": 5, "max_level": 5, "weight": 1},
	]))
	var counts := {}
	var levels := {}
	for draw in 4000:
		var pokemon := _world.encounters.draw(&"grass")
		counts[pokemon["species"]] = counts.get(pokemon["species"], 0) + 1
		levels[pokemon["level"]] = true
		assert_str(pokemon["table"]).is_equal("route")
	assert_float(float(counts[&"rattata"]) / 4000.0).is_between(0.72, 0.78)
	assert_array(levels.keys()).contains_exactly_in_any_order([2, 3, 4, 5])


func test_the_seed_makes_it_repeatable() -> void:
	_node.tables.append(_table(&"route", [{"species": &"rattata", "min_level": 2, "max_level": 9}, {"species": &"pidgey", "min_level": 2, "max_level": 9}]))
	_world.encounters.seed(42)
	var first := _draws(20)
	_world.encounters.seed(42)
	assert_that(_draws(20)).is_equal(first)


func test_only_the_tables_that_fit_the_terrain_area_tool_and_condition() -> void:
	var cave := _table(&"cave", [{"species": &"zubat", "min_level": 9}], &"cave")
	var north := _table(&"north", [{"species": &"caterpie", "min_level": 3}])
	north.area = 1
	var rod := _table(&"rod", [{"species": &"pidgey", "min_level": 1}])
	rod.tool = &"old_rod"
	var night := _table(&"night", [{"species": &"rattata", "min_level": 6}])
	night.condition = "night"
	_node.tables.assign([cave, north, rod, night])
	assert_that(_draws(10, &"cave")).is_equal({"zubat 9": 10})
	assert_that(_draws(10, &"grass", &"", 1)).is_equal({"caterpie 3": 10})
	assert_that(_draws(10, &"grass", &"old_rod")).is_equal({"pidgey 1": 10})
	assert_that(_draws(5)).is_equal({"- 0": 5})
	_world.story.set_flag(&"night")
	assert_that(_draws(5)).is_equal({"rattata 6": 5})
	assert_that(_draws(5, &"water")).is_equal({"- 0": 5})


func test_every_table_that_fits_is_drawn_from_and_tables_are_found_by_id() -> void:
	_node.tables.append(_table(&"own", [{"species": &"rattata", "min_level": 2}]))
	_world.encounters.register(_table(&"shared", [{"species": &"pidgey", "min_level": 3}]))
	DirAccess.make_dir_recursive_absolute(_world.sandbox.root + "encounters")
	ResourceSaver.save(_table(&"saved", [{"species": &"caterpie", "min_level": 4}]), _world.sandbox.root + "encounters/saved.tres")
	_node.table_ids.assign([&"shared", &"saved", &"gone"])
	assert_array(_draws(300).keys()).contains_exactly_in_any_order(["rattata 2", "pidgey 3", "caterpie 4"])
	assert_array(_world.encounters.ids()).contains_exactly_in_any_order([&"shared", &"saved"])
	assert_array(_world.logged).is_equal(["ERROR unknown encounter table 'gone'"])


func test_a_wrong_entry_is_left_out_logged_once() -> void:
	_node.tables.append(_table(&"route", [
		{"species": &"missingno", "min_level": 2},
		{"species": &"rattata", "min_level": 5, "max_level": 3},
		{"species": &"pidgey", "min_level": 0},
		{"species": &"caterpie", "min_level": 2, "weight": 0},
		{"species": &"zubat", "min_level": 7},
	]))
	assert_that(_draws(10)).is_equal({"zubat 7": 10})
	assert_array(_world.logged).is_equal([
		"WARN encounter table 'route': unknown species 'missingno', left out",
		"WARN encounter table 'route': levels 5 to 3, left out",
		"WARN encounter table 'route': levels 0 to 0, left out",
		"WARN encounter table 'route': no weight, left out",
	])


func test_shiny_once_in_its_rate_else_the_config_s() -> void:
	_node.tables.append(_table(&"route", [{"species": &"rattata", "min_level": 2, "shiny_rate": 1}]))
	assert_bool(_world.encounters.draw(&"grass")["shiny"]).is_true()
	_node.tables[0].pokemon[0]["shiny_rate"] = 0
	_world.config.get_config(&"encounters").load_data({"shiny_rate": 2}, "test")
	var shiny := 0
	for draw in 2000:
		if _world.encounters.draw(&"grass")["shiny"]:
			shiny += 1
	assert_int(shiny).is_between(900, 1100)


func test_a_map_without_encounters_draws_no_one() -> void:
	_node.free()
	assert_object(_world.encounters.map_node()).is_null()
	assert_that(_world.encounters.draw(&"grass")).is_equal({})


func test_a_bad_shiny_rate_is_corrected() -> void:
	var settings := WgEncountersConfig.new()
	assert_int(settings.load_data({"shiny_rate": 0}, "encounters.json").size()).is_equal(1)
	assert_int(settings.shiny_rate).is_equal(4096)
