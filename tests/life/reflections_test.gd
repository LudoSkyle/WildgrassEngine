extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const T := preload("res://tests/support/tile_builder.gd")

var _world: World
var _map: WgMap
var _ground: TileMapLayer
var _walker: WgWalker
var _sprite: AnimatedSprite2D


## A walker standing on (3, 3), its feet at y 64, a picture of 16 by 24
## drawn 4 px up: mirrored, it spans x 48 to 64 and y 59 to 83.
func before_test() -> void:
	_world = World.new(self)
	_map = _world.map({Vector2i(3, 3): T.GROUND, Vector2i(4, 3): T.GROUND, Vector2i(3, 4): T.WATER, Vector2i(3, 5): T.WATER}, Vector2i(10, 10))
	_ground = _map.get_children().filter(func(node: Node) -> bool: return node is TileMapLayer)[0]
	_walker = _world.walker(Vector2i(3, 3))
	_walker.position = Vector2(56, 56)
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.position = Vector2(0, -4)
	_sprite.sprite_frames = SpriteFrames.new()
	for shade: Color in [Color.RED, Color.BLUE]:
		var image := Image.create(16, 24, false, Image.FORMAT_RGBA8)
		image.fill(shade)
		_sprite.sprite_frames.add_frame(&"default", ImageTexture.create_from_image(image))
	_walker.add_child(_sprite)


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


## Shows a blank picture of `size` instead.
func _picture(size: Vector2i) -> void:
	_sprite.sprite_frames.add_animation(&"other")
	_sprite.sprite_frames.add_frame(&"other", ImageTexture.create_from_image(Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)))
	_sprite.animation = &"other"


func _glass() -> Sprite2D:
	_world.reflections.show_all()
	return _world.reflections.of(_walker)


func test_the_reflection_is_the_picture_flipped_and_tinted_above_the_water_layer() -> void:
	var above := T.layer(_map, _ground.tile_set, {Vector2i(8, 8): T.FLOWER}, 0)
	var glass := _glass()
	assert_bool(glass.visible).is_true()
	assert_bool(glass.flip_v).is_true()
	assert_that(glass.modulate).is_equal(Color(0.6, 0.8, 1.0, 0.45))
	assert_object(glass.texture).is_same(_sprite.sprite_frames.get_frame_texture(&"default", 0))
	# The water starts at y 64: the top 5 rows of the reflection are cut, the
	# bottom 5 rows of the picture.
	assert_that(glass.region_rect).is_equal(Rect2(0, 0, 16, 19))
	assert_that(glass.global_position).is_equal(Vector2(56, 73.5))
	assert_int(glass.get_parent().get_index()).is_equal(_ground.get_index() + 1)
	assert_int((glass.get_parent() as Node2D).z_index).is_equal(_ground.z_index)
	assert_int(above.get_index()).is_greater(glass.get_parent().get_index())
	_sprite.frame = 1
	assert_object(_glass().texture).is_same(_sprite.sprite_frames.get_frame_texture(&"default", 1))


func test_a_bank_cuts_the_reflection_and_it_rises_into_view_through_a_step() -> void:
	_ground.set_cell(Vector2i(3, 5), 0, T.GROUND)
	var glass := _glass()
	assert_that(glass.region_rect).is_equal(Rect2(0, 3, 16, 16))
	assert_that(glass.global_position).is_equal(Vector2(56, 72))
	_walker.position = Vector2(56, 36)
	assert_bool(_glass().visible).is_false()
	# Lower, the head comes into the water first.
	_walker.position = Vector2(56, 50)
	assert_that(_glass().region_rect).is_equal(Rect2(0, 0, 16, 13))
	# Water again past the bank does not take it up: a picture 64 tall,
	# mirrored from y 39 to 103.
	_walker.position = Vector2(56, 56)
	_picture(Vector2i(16, 64))
	_ground.set_cell(Vector2i(3, 6), 0, T.WATER)
	assert_that(_glass().region_rect).is_equal(Rect2(0, 23, 16, 16))


func test_a_reflection_starting_in_the_water_shows_whole() -> void:
	_ground.set_cell(Vector2i(3, 3), 0, T.WATER)
	assert_that(_glass().region_rect).is_equal(Rect2(0, 0, 16, 24))
	assert_that(_glass().global_position).is_equal(Vector2(56, 71))


func test_only_the_columns_over_water_show_and_a_flipped_picture_is_cut_its_way() -> void:
	_walker.position = Vector2(64, 56)
	var glass := _glass()
	assert_that(glass.region_rect).is_equal(Rect2(0, 0, 8, 19))
	assert_that(glass.global_position).is_equal(Vector2(60, 73.5))
	_sprite.flip_h = true
	glass = _glass()
	assert_bool(glass.flip_h).is_true()
	assert_that(glass.region_rect).is_equal(Rect2(8, 0, 8, 19))
	# Two columns of water: the height they share, whichever is shallower.
	_ground.set_cell(Vector2i(4, 4), 0, T.WATER)
	assert_that(_glass().region_rect).is_equal(Rect2(0, 3, 16, 16))
	_sprite.flip_h = false
	_ground.set_cell(Vector2i(4, 4), 0, T.GROUND)
	_ground.set_cell(Vector2i(2, 4), 0, T.WATER)
	_walker.position = Vector2(48, 56)
	assert_that(_glass().region_rect).is_equal(Rect2(0, 3, 16, 16))


func test_the_widest_run_of_columns_over_water_wins() -> void:
	# A picture 40 wide, from x 38 to 78: 10 px over water, a dry column, 14 px over water.
	_picture(Vector2i(40, 24))
	_walker.position = Vector2(58, 56)
	_ground.set_cell(Vector2i(2, 4), 0, T.WATER)
	_ground.set_cell(Vector2i(3, 4), 0, T.GROUND)
	_ground.set_cell(Vector2i(3, 5), 0, T.GROUND)
	_ground.set_cell(Vector2i(4, 4), 0, T.WATER)
	_ground.set_cell(Vector2i(4, 5), 0, T.WATER)
	var glass := _glass()
	assert_that(glass.region_rect).is_equal(Rect2(26, 0, 14, 19))
	assert_that(glass.global_position).is_equal(Vector2(71, 73.5))
	# Water lower in the middle column, meeting neither side's: it starts its own run.
	_ground.set_cell(Vector2i(3, 4), 0, T.WATER)
	_ground.set_cell(Vector2i(2, 4), 0, T.GROUND)
	_ground.set_cell(Vector2i(2, 5), 0, T.WATER)
	_ground.set_cell(Vector2i(3, 5), 0, T.GROUND)
	_ground.set_cell(Vector2i(4, 4), 0, T.GROUND)
	assert_that(_glass().region_rect).is_equal(Rect2(10, 3, 16, 16))


func test_it_sways_a_pixel_four_times_a_second() -> void:
	_ground.set_cell(Vector2i(2, 4), 0, T.WATER)
	_ground.set_cell(Vector2i(4, 4), 0, T.WATER)
	var places: Array[float] = []
	for quarter in 5:
		places.append(_glass().global_position.x)
		_world.reflections.advance(0.25)
	assert_array(places).is_equal([56.0, 57.0, 56.0, 55.0, 56.0])


func test_no_reflection_under_a_jetty_off_water_or_for_a_walker_hidden_or_that_does_not_reflect() -> void:
	var jetty := T.layer(_map, _ground.tile_set, {Vector2i(3, 4): T.JETTY, Vector2i(3, 5): T.JETTY}, 0)
	assert_object(_glass()).is_null()
	jetty.free()
	assert_bool(_glass().visible).is_true()
	_walker.reflects = false
	assert_bool(_glass().visible).is_false()
	_walker.reflects = true
	_walker.hide()
	assert_bool(_glass().visible).is_false()
	_walker.show()
	assert_bool(_glass().visible).is_true()
	_walker.position = Vector2(120, 56)
	assert_bool(_glass().visible).is_false()
	_walker.position = Vector2(56, 56)
	(_ground.tile_set.get_source(0) as TileSetAtlasSource).get_tile_data(T.WATER, 0).set_custom_data("reflects", false)
	assert_bool(_glass().visible).is_false()


func test_a_sprite_with_a_region_and_a_walker_gone() -> void:
	_sprite.free()
	var still := Sprite2D.new()
	still.name = "Sprite"
	still.position = Vector2(0, -4)
	still.texture = ImageTexture.create_from_image(Image.create(64, 24, false, Image.FORMAT_RGBA8))
	still.region_enabled = true
	still.region_rect = Rect2(32, 0, 16, 24)
	_walker.add_child(still)
	var glass := _glass()
	assert_that(glass.region_rect).is_equal(Rect2(32, 0, 16, 19))
	_walker.free()
	_world.reflections.show_all()
	assert_bool(glass.is_queued_for_deletion()).is_true()


func test_a_walker_on_another_map_gets_a_new_reflection_there() -> void:
	var old := _glass()
	var next := _world.map({Vector2i(3, 3): T.GROUND, Vector2i(3, 4): T.WATER}, Vector2i(10, 10))
	_walker.reparent(next.entities_node())
	_map.free()
	assert_object(_world.reflections.of(_walker)).is_null()
	var glass := _glass()
	assert_object(glass).is_not_same(old)
	assert_object(glass.get_parent().get_parent()).is_same(next)
	_walker.free()
	_world.reflections.show_all()
	assert_bool(glass.is_queued_for_deletion()).is_true()
