extends GdUnitTestSuite


## A sheet of `columns` × 4 frames of 16×24 pixels.
func _sheet(columns := 4) -> Texture2D:
	return ImageTexture.create_from_image(Image.create(16 * columns, 96, false, Image.FORMAT_RGBA8))


func _region(sprite: WgCharacterSprite, animation_name: String, index: int) -> Rect2:
	return (sprite.sprite_frames.get_frame_texture(animation_name, index) as AtlasTexture).region


func test_a_sheet_gives_idle_and_walk_for_each_row_feet_at_the_bottom_of_the_cell() -> void:
	var sprite: WgCharacterSprite = auto_free(WgCharacterSprite.new())
	sprite.sheet = _sheet()
	var names := Array(sprite.sprite_frames.get_animation_names())
	names.sort()
	assert_array(names).is_equal(["idle_down", "idle_left", "idle_right", "idle_up", "walk_down", "walk_left", "walk_right", "walk_up"])
	assert_int(sprite.sprite_frames.get_frame_count("idle_left")).is_equal(1)
	assert_that(_region(sprite, "idle_left", 0)).is_equal(Rect2(0, 24, 16, 24))
	assert_int(sprite.sprite_frames.get_frame_count("walk_up")).is_equal(4)
	assert_that(_region(sprite, "walk_up", 3)).is_equal(Rect2(48, 72, 16, 24))
	assert_float(sprite.sprite_frames.get_animation_speed("walk_up")).is_equal(8.0)
	assert_that(sprite.offset).is_equal(Vector2(0, -4))


func test_the_layout_can_change() -> void:
	var sprite: WgCharacterSprite = auto_free(WgCharacterSprite.new())
	sprite.columns = 3
	sprite.rows_order = ["up", "right", "down", "left"]
	sprite.fps = 6.0
	sprite.foot_line = 16.0
	sprite.sheet = _sheet(3)
	assert_int(sprite.sprite_frames.get_frame_count("walk_down")).is_equal(3)
	assert_that(_region(sprite, "idle_down", 0)).is_equal(Rect2(0, 48, 16, 24))
	assert_float(sprite.sprite_frames.get_animation_speed("walk_down")).is_equal(6.0)
	assert_that(sprite.offset).is_equal(Vector2(0, 4))
	sprite.sheet = null
	assert_object(sprite.sprite_frames).is_null()
