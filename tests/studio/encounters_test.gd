extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const StudioProject := preload("res://tests/support/studio_project.gd")

var _world: World
var _studio: StudioProject.Studio


func before_test() -> void:
	_world = World.new(self)


func after_test() -> void:
	if _studio != null:
		_studio.uninstall()
	_world.root.free()
	_world.cleanup()


func _encounter(species: String, low: int, high: int, chance: float, shiny := {"kind": "automatic", "rate": -1}) -> Dictionary:
	return {"specie": species, "form": 0, "shinySetup": shiny, "levelSetup": {"kind": "minmax", "level": {"minimumLevel": low, "maximumLevel": high}},
		"randomEncounterChance": chance, "expandPokemonSetup": []}


func test_studio_s_groups_become_tables_found_by_id() -> void:
	_world.sandbox.write_json("Data/Studio/groups/group_16.json", {"klass": "Group", "id": 16, "dbSymbol": "group_16", "systemTag": "TallGrass", "terrainTag": 1, "tool": null,
		"customConditions": [{"type": "mapId", "value": 8, "relationWithPreviousCondition": "AND"}, {"type": "enabledSwitch", "value": 13, "relationWithPreviousCondition": "AND"}, {"type": "enabledSwitch", "value": 2, "relationWithPreviousCondition": "AND"}],
		"encounters": [_encounter("carnivine", 24, 28, 2), _encounter("yanmega", 30, 30, 1, {"kind": "rate", "rate": 0.01}), {"specie": "ditto", "form": 0, "shinySetup": {"kind": "rate", "rate": 0}, "levelSetup": {"kind": "fixed", "level": 12}, "randomEncounterChance": 1}],
		"stepsAverage": 20, "vsType": "double"})
	_world.sandbox.write_json("Data/Studio/groups/group_0.json", {"klass": "Group", "id": 0, "dbSymbol": "group_0", "systemTag": "Pond", "terrainTag": 0, "tool": "OldRod", "customConditions": [], "encounters": [], "stepsAverage": 0, "vsType": "simple"})
	_studio = StudioProject.install(_world)
	var table := _world.encounters.find(&"group_16")
	assert_str(table.terrain).is_equal("tall_grass")
	assert_int(table.area).is_equal(1)
	assert_str(table.tool).is_empty()
	assert_float(table.rate).is_equal(5.0)
	assert_bool(table.double).is_true()
	assert_str(table.condition).is_equal("switch_13, switch_2")
	assert_that(table.pokemon).is_equal([
		{"species": &"carnivine", "form": 0, "min_level": 24, "max_level": 28, "weight": 2.0, "shiny_rate": 0},
		{"species": &"yanmega", "form": 0, "min_level": 30, "max_level": 30, "weight": 1.0, "shiny_rate": 100},
		{"species": &"ditto", "form": 0, "min_level": 12, "max_level": 12, "weight": 1.0, "shiny_rate": -1},
	])
	var rod := _world.encounters.find(&"group_0")
	assert_array([rod.terrain, rod.tool, rod.rate, rod.double]).is_equal([&"pond", &"old_rod", 0.0, false])
	assert_array(_world.encounters.ids()).contains_exactly_in_any_order([&"group_0", &"group_16"])
	assert_array(_world.logged).is_empty()


func test_an_unknown_condition_or_an_or_is_logged_once_and_a_broken_file_too() -> void:
	_world.sandbox.write_json("Data/Studio/groups/group_3.json", {"klass": "Group", "dbSymbol": "group_3", "systemTag": "Grass", "terrainTag": 0, "tool": null,
		"customConditions": [{"type": "dayTime", "value": 1, "relationWithPreviousCondition": "OR"}], "encounters": [], "stepsAverage": 0, "vsType": "simple"})
	_world.sandbox.write("Data/Studio/groups/group_4.json", "[]")
	_studio = StudioProject.install(_world)
	assert_str(_world.encounters.find(&"group_3").condition).is_empty()
	assert_object(_world.encounters.find(&"group_4")).is_null()
	assert_object(_world.encounters.find(&"group_4")).is_null()
	assert_array(_world.logged).is_equal([
		"WARN group group_3: its condition 'dayTime' is not read yet; ignored",
		"WARN group group_3: conditions joined by OR are read as AND",
		"ERROR group_4.json: not a Studio group",
		"ERROR unknown encounter table 'group_4'",
	])


func test_a_map_names_a_studio_group_and_never_shiny_holds() -> void:
	_world.sandbox.write_json("Data/Studio/groups/group_1.json", {"klass": "Group", "dbSymbol": "group_1", "systemTag": "Grass", "terrainTag": 0, "tool": null, "customConditions": [],
		"encounters": [{"specie": "ditto", "form": 0, "shinySetup": {"kind": "rate", "rate": 0}, "levelSetup": {"kind": "fixed", "level": 12}, "randomEncounterChance": 1}], "stepsAverage": 0, "vsType": "simple"})
	var ditto := WgSpecies.new()
	ditto.id = &"ditto"
	ditto.forms.append(WgSpeciesForm.new())
	_world.species.register(ditto)
	_studio = StudioProject.install(_world)
	var node := WgEncounters.new()
	node.table_ids.assign([&"group_1"])
	_world.map().add_child(node)
	_world.config.get_config(&"encounters").load_data({"shiny_rate": 1}, "test")
	var pokemon := _world.encounters.draw(&"grass")
	assert_array([pokemon["species"], pokemon["level"], pokemon["shiny"]]).is_equal([&"ditto", 12, false])
