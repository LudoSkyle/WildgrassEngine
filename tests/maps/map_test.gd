extends GdUnitTestSuite

const MapBuilder := preload("res://tests/support/map_builder.gd")

var _map: WgMap


func before_test() -> void:
	_map = auto_free(WgMap.new())
	add_child(_map)


func test_find_point_returns_doors_and_spawn_points_by_name_only() -> void:
	var spawn := MapBuilder.spawn(_map, "Spawn", Vector2.ZERO)
	var house := Node2D.new()
	_map.add_child(house)
	var door := MapBuilder.door(house, "Door", Vector2.ZERO, &"a", &"b")
	var plain := Node2D.new()
	plain.name = "Plain"
	_map.add_child(plain)
	assert_object(_map.find_point(&"Spawn")).is_same(spawn)
	assert_object(_map.find_point(&"Door")).is_same(door)
	assert_object(_map.find_point(&"Plain")).is_null()
	assert_object(_map.find_point(&"Nope")).is_null()


func test_first_spawn_point_skips_doors() -> void:
	MapBuilder.door(_map, "Door", Vector2.ZERO, &"a", &"b")
	assert_object(_map.first_spawn_point()).is_null()
	var spawn := MapBuilder.spawn(_map, "Spawn", Vector2.ZERO)
	assert_object(_map.first_spawn_point()).is_same(spawn)


func test_find_part_finds_a_node_by_type_anywhere() -> void:
	var holder := Node.new()
	_map.add_child(holder)
	var part := Timer.new()
	holder.add_child(part)
	assert_object(_map.find_part(Timer)).is_same(part)
	assert_object(_map.find_part(WgDoor)).is_null()


func test_entities_falls_back_to_the_map_itself() -> void:
	assert_object(_map.entities_node()).is_same(_map)
	var entities := Node2D.new()
	entities.name = "Entities"
	_map.add_child(entities)
	assert_object(_map.entities_node()).is_same(entities)


func test_map_config_resets_impossible_values() -> void:
	var config := WgMapConfig.new()
	assert_array(config.load_data({"tile_size": 0, "fade_seconds": -1}, "map.json")).has_size(2)
	assert_int(config.tile_size).is_equal(16)
	assert_float(config.fade_seconds).is_equal(0.0)


func test_map_config_needs_one_solid_and_one_edge_layer_from_1_to_32_per_level() -> void:
	var config := WgMapConfig.new()
	assert_array(config.load_data({"solid_layers": [1, 2], "edge_layers": [4, 5]}, "map.json")).is_empty()
	assert_array(config.solid_layers).is_equal([1, 2])
	for bad: Dictionary in [{"solid_layers": [1, 2], "edge_layers": [4]}, {"solid_layers": [], "edge_layers": []}, {"solid_layers": [0], "edge_layers": [4]}, {"solid_layers": [1], "edge_layers": [33]}]:
		config = WgMapConfig.new()
		assert_array(config.load_data(bad, "map.json")).has_size(1)
		assert_array(config.solid_layers).is_equal([1])
		assert_array(config.edge_layers).is_equal([4])
