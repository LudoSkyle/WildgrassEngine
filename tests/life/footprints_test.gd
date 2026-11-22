extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const T := preload("res://tests/support/tile_builder.gd")

var _world: World
var _map: WgMap
var _ground: TileMapLayer


func before_test() -> void:
	_world = World.new(self)
	var cells := {}
	for x in range(1, 7):
		cells[Vector2i(x, 5)] = T.SAND
	cells[Vector2i(7, 5)] = T.GROUND
	_map = _world.map(cells, Vector2i(10, 10))
	_ground = _map.get_children().filter(func(node: Node) -> bool: return node is TileMapLayer)[0]


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _walk(walker: WgWalker, direction: Vector2i) -> void:
	walker.step(direction)
	walker.advance(0.5)


func _places() -> Array[Vector2]:
	var found: Array[Vector2] = []
	for print_node in _world.footprints.prints:
		found.append(print_node.global_position)
	return found


func test_leaving_sand_leaves_a_pair_each_side_of_the_way_above_the_ground() -> void:
	var above := T.layer(_map, _ground.tile_set, {Vector2i(8, 8): T.FLOWER}, 0)
	var walker := _world.walker(Vector2i(2, 5))
	walker.step(Vector2i.RIGHT)
	walker.advance(0.05)
	assert_array(_world.footprints.prints).is_empty()
	walker.advance(0.1)
	# The cell's centre (40, 88), the feet 4 px lower, 3 px each side, the right foot 2 px behind.
	assert_array(_places()).contains_exactly([Vector2(38, 95), Vector2(42, 89)])
	var holder := _world.footprints.prints[0].get_parent()
	assert_int(holder.get_index()).is_equal(_ground.get_index() + 1)
	assert_int(above.get_index()).is_greater(holder.get_index())
	assert_int((holder as Node2D).z_index).is_equal(_ground.z_index)
	assert_that(_world.footprints.prints[0].modulate).is_equal(Color(0, 0, 0, 0.26))
	assert_bool(_world.footprints.prints[0].region_enabled).is_false()


func test_the_leading_foot_changes_each_step_for_each_walker() -> void:
	var walker := _world.walker(Vector2i(1, 5))
	_walk(walker, Vector2i.RIGHT)
	_walk(walker, Vector2i.RIGHT)
	assert_array(_places()).contains_exactly([Vector2(22, 95), Vector2(26, 89), Vector2(42, 95), Vector2(38, 89)])
	var other := _world.walker(Vector2i(6, 5))
	_walk(other, Vector2i.LEFT)
	# Its own first step: centre (104, 88), side (0, -1), the leading foot behind.
	assert_array(_places().slice(4)).contains_exactly([Vector2(106, 89), Vector2(102, 95)])
	_walk(walker, Vector2i.RIGHT)
	assert_array(_places().slice(6)).contains_exactly([Vector2(54, 95), Vector2(58, 89)])


func test_a_print_holds_for_half_its_life_then_fades_even_without_its_walker() -> void:
	var walker := _world.walker(Vector2i(2, 5))
	walker.step(Vector2i.RIGHT)
	walker.advance(0.15)
	walker.free()
	var first := _world.footprints.prints[0]
	_world.footprints.advance(0.5)
	assert_float(first.modulate.a).is_equal_approx(0.26, 0.0001)
	_world.footprints.advance(0.25)
	assert_float(first.modulate.a).is_equal_approx(0.13, 0.0001)
	_world.footprints.advance(0.25)
	assert_array(_world.footprints.prints).is_empty()
	assert_bool(first.is_queued_for_deletion()).is_true()
	_walk(_world.walker(Vector2i(4, 5)), Vector2i.RIGHT)
	assert_int(_world.footprints.prints.size()).is_equal(2)


func test_no_prints_off_sand_under_a_jetty_after_a_jump_or_without_the_data() -> void:
	var walker := _world.walker(Vector2i(7, 5))
	_walk(walker, Vector2i.LEFT)
	assert_array(_world.footprints.prints).is_empty()
	var sand := (_ground.tile_set.get_source(0) as TileSetAtlasSource).get_tile_data(T.SAND, 0)
	sand.set_custom_data("footprints", false)
	_walk(walker, Vector2i.LEFT)
	assert_array(_world.footprints.prints).is_empty()
	sand.set_custom_data("footprints", true)
	T.layer(_map, _ground.tile_set, {Vector2i(3, 5): T.JETTY}, 0)
	var jetty := _world.walker(Vector2i(3, 5))
	_walk(jetty, Vector2i.RIGHT)
	assert_array(_world.footprints.prints).is_empty()
	T.layer(_map, _ground.tile_set, {Vector2i(5, 6): T.LEDGE}, -1)
	var jumper := _world.walker(Vector2i(5, 5))
	jumper.step(Vector2i.DOWN)
	jumper.advance(0.2)
	jumper.advance(0.2)
	assert_that(jumper.cell).is_equal(Vector2i(5, 7))
	assert_array(_world.footprints.prints).is_empty()


func test_the_configs_picture_gives_each_print_its_direction_and_foot() -> void:
	var image := Image.create(64, 8, false, Image.FORMAT_RGBA8)
	var path := _world.sandbox.root + "footprints.png"
	image.save_png(path)
	_world.config.get_config(&"footprints").load_data({"texture": path}, "test")
	_ground.set_cell(Vector2i(4, 6), 0, T.SAND)
	var walker := _world.walker(Vector2i(4, 5))
	_walk(walker, Vector2i.DOWN)
	_walk(walker, Vector2i.UP)
	_walk(walker, Vector2i.LEFT)
	_walk(walker, Vector2i.RIGHT)
	var regions: Array[float] = []
	for print_node in _world.footprints.prints:
		assert_bool(print_node.region_enabled).is_true()
		assert_that(print_node.region_rect.size).is_equal(Vector2(8, 8))
		regions.append(print_node.region_rect.position.x)
	# Down, up, left, right; in each pair of cells the left or upper foot first.
	assert_array(regions).is_equal([0.0, 8.0, 56.0, 48.0, 16.0, 24.0, 40.0, 32.0])


func test_a_missing_picture_is_reported_once_and_the_oval_drawn() -> void:
	_world.config.get_config(&"footprints").load_data({"texture": "res://nowhere/prints.png"}, "test")
	var missing: Array[String] = []
	_world.paths.asset_missing.connect(func(path: String, _requester: String) -> void: missing.append(path))
	var walker := _world.walker(Vector2i(2, 5))
	_walk(walker, Vector2i.RIGHT)
	_walk(walker, Vector2i.RIGHT)
	assert_array(missing).is_equal(["res://nowhere/prints.png"])
	assert_bool(_world.footprints.prints[0].region_enabled).is_false()
	assert_that(_world.footprints.prints[0].texture.get_size()).is_equal(Vector2(3, 4))


func test_a_wrong_config_is_corrected() -> void:
	var settings := WgFootprintsConfig.new()
	var problems := settings.load_data({"life_seconds": 0, "darkness": 1.5}, "test")
	assert_int(problems.size()).is_equal(2)
	assert_float(settings.life_seconds).is_equal(1.0)
	assert_float(settings.darkness).is_equal(0.26)


func test_prints_gone_with_their_map_leave_at_the_next_advance() -> void:
	var walker := _world.walker(Vector2i(2, 5))
	_walk(walker, Vector2i.RIGHT)
	_map.free()
	_world.footprints.advance(0.1)
	assert_array(_world.footprints.prints).is_empty()
	var next := _world.map({Vector2i(1, 1): T.SAND, Vector2i(2, 1): T.SAND})
	_walk(_world.walker(Vector2i(1, 1)), Vector2i.RIGHT)
	assert_int(_world.footprints.prints.size()).is_equal(2)
	assert_object(_world.footprints.prints[0].get_parent().get_parent()).is_same(next)
