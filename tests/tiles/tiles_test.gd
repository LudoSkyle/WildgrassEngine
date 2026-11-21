extends GdUnitTestSuite

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")
const ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")
const ScreenRegistry := preload("res://addons/wildgrass/core/screens/screen_registry.gd")
const Maps := preload("res://addons/wildgrass/maps/maps.gd")
const Tiles := preload("res://addons/wildgrass/tiles/tiles.gd")
const Sandbox := preload("res://tests/support/sandbox.gd")
const T := preload("res://tests/support/tile_builder.gd")

const UP := Vector2i.UP
const DOWN := Vector2i.DOWN
const LEFT := Vector2i.LEFT
const RIGHT := Vector2i.RIGHT

var _sandbox: Sandbox
var _hooks: Hooks
var _maps: Maps
var _tiles: Tiles
var _host: Node2D
var _logged: Array[String]
var _set: TileSet


func before_test() -> void:
	_sandbox = Sandbox.new()
	_sandbox.use_data_folder()
	_sandbox.write_json("config/map.json", {"solid_layers": [1, 2], "edge_layers": [4, 5]})
	var logger := Log.new()
	logger.echo = false
	_logged = []
	logger.logged.connect(func(level: Log.Level, _channel: StringName, message: String) -> void:
		_logged.append("%s %s" % [Log.Level.keys()[level], message]))
	var config := ConfigRegistry.new(Paths.new(false), logger)
	config.register(&"map", WgMapConfig, "map")
	_hooks = Hooks.new()
	var layer: Node = auto_free(Node.new())
	add_child(layer)
	_host = auto_free(Node2D.new())
	add_child(_host)
	_maps = Maps.new(Paths.new(false), logger, config, _hooks, ScreenRegistry.new(logger, layer), _host)
	_tiles = Tiles.new(logger, config, _hooks, _maps)
	_set = T.tile_set()


func after_test() -> void:
	_sandbox.cleanup()


## A 10×10 map at `at`, current unless `neighbour`.
func _map(at := Vector2.ZERO, neighbour := false) -> WgMap:
	var map := WgMap.new()
	map.size = Vector2i(10, 10)
	map.position = at
	_host.add_child(map)
	if neighbour:
		_maps.neighbours.append(map)
	else:
		_maps.current = map
	return map


func test_cells_are_world_cells_of_the_configured_size() -> void:
	assert_that(_tiles.cell_of(Vector2(15.9, 16))).is_equal(Vector2i(0, 1))
	assert_that(_tiles.cell_of(Vector2(-0.1, -16.1))).is_equal(Vector2i(-1, -2))
	assert_that(_tiles.center_of(Vector2i(-1, 2))).is_equal(Vector2(-8, 40))


func test_a_solid_polygon_blocks_its_cell_and_outside_every_map_is_solid() -> void:
	T.layer(_map(), _set, {Vector2i(1, 1): T.WALL, Vector2i(2, 1): T.GROUND})
	assert_bool(_tiles.is_solid(Vector2i(1, 1))).is_true()
	assert_bool(_tiles.is_solid(Vector2i(2, 1))).is_false()
	assert_bool(_tiles.is_solid(Vector2i(3, 1))).is_false()
	assert_bool(_tiles.is_solid(Vector2i(-1, 0))).is_true()


func test_a_tile_of_several_cells_blocks_the_cells_its_polygon_covers() -> void:
	T.layer(_map(), _set, {Vector2i(4, 4): T.TREE})
	var blocked: Array[Vector2i] = []
	for x in range(2, 7):
		for y in range(2, 7):
			if _tiles.is_solid(Vector2i(x, y)):
				blocked.append(Vector2i(x, y))
	assert_array(blocked).contains_exactly_in_any_order([
		Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5),
	])


func test_flipped_and_turned_tiles_block_exactly_where_godot_physics_does() -> void:
	# World cells of 4 px: four by four of them sample each 16 px tile.
	_sandbox.write_json("config/map.json", {"tile_size": 4})
	var cells := {}
	var flags := [0, TileSetAtlasSource.TRANSFORM_FLIP_H, TileSetAtlasSource.TRANSFORM_FLIP_V, TileSetAtlasSource.TRANSFORM_TRANSPOSE]
	var index := 0
	for a: int in flags:
		for b: int in flags:
			cells[Vector2i(index, 0)] = [T.HALF, a | b]
			index += 1
	var map := _map()
	map.size = Vector2i(64, 4)
	T.layer(map, _set, cells)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = 1
	var space := _host.get_world_2d().direct_space_state
	var mismatches: Array[Vector2i] = []
	for x in 64:
		for y in 4:
			query.position = _tiles.center_of(Vector2i(x, y))
			if space.intersect_point(query, 1).is_empty() == _tiles.is_solid(Vector2i(x, y)):
				mismatches.append(Vector2i(x, y))
	assert_array(mismatches).is_empty()


func test_every_enabled_colliding_layer_blocks_whatever_its_z_index() -> void:
	var map := _map()
	T.layer(map, _set, {Vector2i(1, 1): T.WALL}, 7)
	T.layer(map, _set, {Vector2i(2, 1): T.WALL}).enabled = false
	T.layer(map, _set, {Vector2i(3, 1): T.WALL}).collision_enabled = false
	assert_bool(_tiles.is_solid(Vector2i(1, 1))).is_true()
	assert_bool(_tiles.is_solid(Vector2i(2, 1))).is_false()
	assert_bool(_tiles.is_solid(Vector2i(3, 1))).is_false()


func test_an_edge_stands_between_two_cells_seen_from_either_side() -> void:
	T.layer(_map(), _set, {Vector2i(1, 1): T.TOP_EDGE})
	assert_bool(_tiles.has_edge(Vector2i(1, 1), UP)).is_true()
	assert_bool(_tiles.has_edge(Vector2i(1, 0), DOWN)).is_true()
	assert_bool(_tiles.has_edge(Vector2i(1, 1), DOWN)).is_false()
	assert_bool(_tiles.has_edge(Vector2i(1, 1), LEFT)).is_false()
	assert_bool(_tiles.is_solid(Vector2i(1, 1))).is_false()


func test_can_step_needs_a_map_no_solid_and_no_edge() -> void:
	T.layer(_map(), _set, {Vector2i(1, 1): T.WALL, Vector2i(3, 1): T.TOP_EDGE})
	assert_bool(_tiles.can_step(Vector2i(0, 1), RIGHT)).is_false()
	assert_bool(_tiles.can_step(Vector2i(3, 0), DOWN)).is_false()
	assert_bool(_tiles.can_step(Vector2i(0, 0), LEFT)).is_false()
	assert_bool(_tiles.can_step(Vector2i(2, 1), DOWN)).is_true()


## A deck along x = 2, rows 2 to 4, ramps at rows 1 and 5. Under it, water at
## rows 2 and 4, and a path at row 3.
func _bridge() -> void:
	var map := _map()
	T.layer(map, _set, {Vector2i(2, 2): T.WATER, Vector2i(2, 4): T.WATER}, -1)
	T.layer(map, _set, {Vector2i(2, 1): T.RAMP, Vector2i(2, 2): T.DECK, Vector2i(2, 3): T.DECK, Vector2i(2, 4): T.DECK, Vector2i(2, 5): T.RAMP})


## Walks from `cell` along `steps`, as walking will; returns the levels after
## each step, or "blocked" where a step is refused.
func _walk(cell: Vector2i, steps: Array[Vector2i], level := 0) -> Array:
	var levels := []
	for direction: Vector2i in steps:
		if not _tiles.can_step(cell, direction, level):
			levels.append("blocked")
			return levels
		level = _tiles.level_after(cell, direction, level)
		cell += direction
		levels.append(level)
	return levels


func test_a_bridge_is_crossed_up_the_ramp_over_the_deck_and_down_again() -> void:
	_bridge()
	assert_array(_walk(Vector2i(2, 0), [DOWN, DOWN, DOWN, DOWN, DOWN, DOWN])).is_equal([1, 1, 1, 1, 1, 0])
	assert_array(_walk(Vector2i(2, 6), [UP, UP, UP, UP, UP, UP])).is_equal([1, 1, 1, 1, 1, 0])


func test_on_the_deck_the_railings_block_and_there_is_no_walking_on_air() -> void:
	_bridge()
	assert_array(_walk(Vector2i(2, 1), [DOWN, DOWN, LEFT], 1)).is_equal([1, 1, "blocked"])
	assert_bool(_tiles.can_step(Vector2i(0, 0), RIGHT, 1)).is_false()


func test_under_the_bridge_only_the_ground_counts() -> void:
	_bridge()
	assert_bool(_tiles.can_step(Vector2i(1, 2), RIGHT)).is_false()
	assert_array(_walk(Vector2i(1, 3), [RIGHT, RIGHT])).is_equal([0, 0])


func test_a_ramp_entered_from_the_side_can_be_left_the_same_way() -> void:
	_bridge()
	assert_array(_walk(Vector2i(1, 1), [RIGHT, LEFT])).is_equal([1, 0])


func test_the_railings_of_a_ramp_keep_out_who_comes_from_its_side() -> void:
	T.layer(_map(), _set, {Vector2i(2, 1): T.RAILED_RAMP, Vector2i(2, 2): T.DECK})
	assert_array(_walk(Vector2i(1, 1), [RIGHT])).is_equal(["blocked"])
	assert_array(_walk(Vector2i(2, 0), [DOWN, DOWN])).is_equal([1, 1])


func test_the_can_step_hook_has_the_last_word() -> void:
	T.layer(_map(), _set, {Vector2i(1, 1): T.WATER})
	var walker: Node = auto_free(Node.new())
	var calls: Array[String] = []
	_hooks.add(&"can_step", &"surf", func(allowed: bool, cell: Vector2i, direction: Vector2i, level: int, who: Node) -> bool:
		calls.append("%s %s %s %s %s" % [allowed, cell, direction, level, who == walker])
		return not allowed)
	assert_bool(_tiles.can_step(Vector2i(0, 1), RIGHT, 0, walker)).is_true()
	assert_bool(_tiles.can_step(Vector2i(0, 0), RIGHT)).is_false()
	assert_array(calls).is_equal(["false (0, 1) (1, 0) 0 true", "true (0, 0) (1, 0) 0 false"])


func test_bad_directions_and_unknown_levels_are_logged_and_refused() -> void:
	_map()
	assert_bool(_tiles.can_step(Vector2i(1, 1), Vector2i(1, 1))).is_false()
	assert_bool(_tiles.has_edge(Vector2i(1, 1), Vector2i.ZERO)).is_false()
	assert_bool(_tiles.can_step(Vector2i(1, 1), DOWN, 2)).is_false()
	assert_bool(_tiles.is_solid(Vector2i(1, 1), -1)).is_true()
	assert_array(_logged).is_equal([
		"ERROR (1, 1) is not up, down, left or right",
		"ERROR (0, 0) is not up, down, left or right",
		"ERROR no level 2 in the map config",
		"ERROR no level -1 in the map config",
	])


func test_a_neighbour_answers_for_its_own_cells_and_a_missing_one_is_a_wall() -> void:
	T.layer(_map(), _set, {Vector2i(9, 4): T.TOP_EDGE})
	T.layer(_map(Vector2(160, 0), true), _set, {Vector2i(0, 3): T.WALL})
	assert_bool(_tiles.is_solid(Vector2i(10, 3))).is_true()
	assert_bool(_tiles.can_step(Vector2i(9, 4), RIGHT)).is_true()
	assert_bool(_tiles.can_step(Vector2i(9, 4), UP)).is_false()
	assert_bool(_tiles.can_step(Vector2i(4, 9), DOWN)).is_false()


func test_data_comes_from_the_first_tile_from_the_top_that_sets_it() -> void:
	var map := _map()
	T.layer(map, _set, {Vector2i(1, 1): T.SAND, Vector2i(2, 1): T.WATER, Vector2i(3, 1): T.SAND}, -2)
	T.layer(map, _set, {Vector2i(1, 1): T.FLOWER, Vector2i(2, 1): T.JETTY, Vector2i(3, 1): T.JETTY}, -1)
	assert_that(_tiles.data(Vector2i(1, 1), &"sand")).is_equal(true)
	assert_that(_tiles.data(Vector2i(2, 1), &"water")).is_equal(false)
	assert_that(_tiles.data(Vector2i(3, 1), &"sand")).is_equal(false)
	assert_that(_tiles.data(Vector2i(4, 1), &"sand")).is_null()
	assert_that(_tiles.data(Vector2i(1, 1), &"nope")).is_null()
	assert_that(_tiles.data(Vector2i(1, 1), &"water")).is_equal(false)


func test_the_top_is_the_highest_effective_z_index_then_the_last_in_the_tree() -> void:
	var map := _map()
	var under := Node2D.new()
	under.z_index = 3
	map.add_child(under)
	T.layer(under, _set, {Vector2i(1, 1): T.JETTY, Vector2i(2, 1): T.SAND})
	T.layer(map, _set, {Vector2i(1, 1): T.SAND}, 2)
	T.layer(map, _set, {Vector2i(2, 1): T.JETTY}, 3)
	assert_that(_tiles.data(Vector2i(1, 1), &"sand")).is_equal(false)
	assert_that(_tiles.data(Vector2i(2, 1), &"sand")).is_equal(false)


func test_a_layer_with_bigger_tiles_is_read_in_its_own_grid() -> void:
	T.layer(_map(), T.tile_set(32), {Vector2i(1, 0): T.WALL, Vector2i(0, 1): T.SAND})
	assert_bool(_tiles.is_solid(Vector2i(2, 0))).is_true()
	assert_bool(_tiles.is_solid(Vector2i(3, 1))).is_true()
	assert_bool(_tiles.is_solid(Vector2i(4, 0))).is_false()
	assert_that(_tiles.data(Vector2i(1, 3), &"sand")).is_equal(true)
