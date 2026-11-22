extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const T := preload("res://tests/support/tile_builder.gd")

var _world: World
var _map: WgMap
var _layer: TileMapLayer


func before_test() -> void:
	_world = World.new(self)
	_map = _world.map({Vector2i(3, 5): T.TUFT, Vector2i(4, 5): T.TUFT, Vector2i(5, 5): T.GROUND}, Vector2i(10, 10))
	_layer = _map.get_children().filter(func(node: Node) -> bool: return node is TileMapLayer)[0]
	_world.hooks.run(&"map_loaded", [_map])


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func test_the_front_strips_are_built_among_the_entities_on_the_tufts_cells() -> void:
	var front := _world.grass.front_of(_layer)
	assert_object(front.get_parent()).is_same(_map.entities_node())
	assert_bool(front.y_sort_enabled).is_true()
	assert_int(front.y_sort_origin).is_equal(2)
	assert_array(front.get_used_cells()).contains_exactly_in_any_order([Vector2i(3, 5), Vector2i(4, 5)])
	assert_int(front.get_cell_source_id(Vector2i(3, 5))).is_equal(1)
	assert_that(front.get_cell_atlas_coords(Vector2i(3, 5))).is_equal(T.TUFT)
	_world.hooks.run(&"map_loaded", [_map])
	assert_int(_map.entities_node().get_children().filter(func(node: Node) -> bool: return node is TileMapLayer).size()).is_equal(1)


func test_a_walker_entering_makes_the_tuft_rustle_then_stand_again() -> void:
	var walker := _world.walker(Vector2i(2, 5))
	walker.step(Vector2i.RIGHT)
	walker.advance(0.15)
	var front := _world.grass.front_of(_layer)
	var seen: Array[Vector2i] = [_layer.get_cell_atlas_coords(Vector2i(3, 5))]
	for step in 5:
		_world.grass.advance(0.07)
		seen.append(_layer.get_cell_atlas_coords(Vector2i(3, 5)))
		assert_that(front.get_cell_atlas_coords(Vector2i(3, 5))).is_equal(seen.back())
	assert_array(seen).is_equal([T.TUFT_PARTING, T.TUFT_PARTED, T.TUFT_PARTED, T.TUFT_PARTING, T.TUFT, T.TUFT])
	assert_that(_layer.get_cell_atlas_coords(Vector2i(4, 5))).is_equal(T.TUFT)


func test_it_rustles_halfway_into_the_cell_and_once_while_rustling() -> void:
	var walker := _world.walker(Vector2i(2, 5))
	walker.step(Vector2i.RIGHT)
	walker.advance(0.05)
	assert_that(_layer.get_cell_atlas_coords(Vector2i(3, 5))).is_equal(T.TUFT)
	walker.advance(0.1)
	assert_that(_layer.get_cell_atlas_coords(Vector2i(3, 5))).is_equal(T.TUFT_PARTING)
	walker.advance(0.5)
	walker.place_at(Vector2i(7, 7))
	_world.grass.advance(0.22)
	assert_that(_layer.get_cell_atlas_coords(Vector2i(3, 5))).is_equal(T.TUFT_PARTING)
	var other := _world.walker(Vector2i(3, 4))
	other.step(Vector2i.DOWN)
	other.advance(0.5)
	_world.grass.advance(0.07)
	assert_that(_layer.get_cell_atlas_coords(Vector2i(3, 5))).is_equal(T.TUFT)
	_world.grass.advance(0.07)
	assert_that(_layer.get_cell_atlas_coords(Vector2i(3, 5))).is_equal(T.TUFT)


func test_a_cell_without_grass_never_rustles() -> void:
	var walker := _world.walker(Vector2i(4, 5))
	walker.step(Vector2i.RIGHT)
	walker.advance(0.5)
	_world.grass.advance(0.07)
	assert_that(_layer.get_cell_atlas_coords(Vector2i(5, 5))).is_equal(T.GROUND)
	assert_that(_layer.get_cell_atlas_coords(Vector2i(4, 5))).is_equal(T.TUFT)


func test_a_new_map_gets_its_own_front_strips_once_the_old_map_is_gone() -> void:
	_map.free()
	var next := _world.map({Vector2i(1, 1): T.TUFT}, Vector2i(10, 10))
	var layer: TileMapLayer = next.get_children().filter(func(node: Node) -> bool: return node is TileMapLayer)[0]
	_world.hooks.run(&"map_loaded", [next])
	assert_array(_world.grass.front_of(layer).get_used_cells()).contains_exactly([Vector2i(1, 1)])


func test_a_rustle_whose_map_is_gone_is_dropped() -> void:
	var walker := _world.walker(Vector2i(2, 5))
	_walk_in(walker)
	_map.free()
	_world.grass.advance(0.07)
	_world.grass.advance(0.5)
	var next := _world.map({Vector2i(1, 1): T.TUFT}, Vector2i(10, 10))
	_world.hooks.run(&"map_loaded", [next])
	var layer: TileMapLayer = next.get_children().filter(func(node: Node) -> bool: return node is TileMapLayer)[0]
	var other := _world.walker(Vector2i(0, 1))
	other.step(Vector2i.RIGHT)
	other.advance(0.15)
	assert_that(layer.get_cell_atlas_coords(Vector2i(1, 1))).is_equal(T.TUFT_PARTING)


func _walk_in(walker: WgWalker) -> void:
	walker.step(Vector2i.RIGHT)
	walker.advance(0.15)
