extends GdUnitTestSuite

# The screen's effects (feature 21, step 2): the service ticked by hand at
# RPG Maker's 60 ticks a second, and its view drawn in the test's tree.

const World := preload("res://tests/support/walking_world.gd")
const Screen := preload("res://addons/wildgrass/screen/screen.gd")
const ScreenView := preload("res://addons/wildgrass/screen/screen_view.gd")
const TICK := 1.0 / 60.0

var _world: World
var _screen: Screen
var _texture: Texture2D


func before_test() -> void:
	_world = World.new(self)
	_screen = Screen.new(_world.logger, _world.config)
	_texture = ImageTexture.create_from_image(Image.create(8, 4, false, Image.FORMAT_RGBA8))


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _ticks(count: int) -> void:
	for _tick in count:
		_screen.advance(TICK)


func test_a_tone_goes_a_share_of_the_way_left_each_tick_the_day_s_tint_giving_way() -> void:
	_screen.tone_to(Vector4(-255, -255, -255, 300), 4 * TICK)
	_ticks(1)
	assert_that(_screen.tone).is_equal(Vector4(-63.75, -63.75, -63.75, 63.75))
	assert_float(_screen.day_share).is_equal_approx(0.75, 0.0001)
	_ticks(3)
	assert_that(_screen.tone).is_equal(Vector4(-255, -255, -255, 255))
	assert_float(_screen.day_share).is_equal(0.0)
	_screen.tone_to(Vector4.ZERO, 2 * TICK)
	_ticks(1)
	assert_that(_screen.tone).is_equal(Vector4(-127.5, -127.5, -127.5, 127.5))
	assert_float(_screen.day_share).is_equal_approx(0.5, 0.0001)
	_ticks(5)
	assert_that(_screen.tone).is_equal(Vector4.ZERO)
	assert_float(_screen.day_share).is_equal(1.0)
	_screen.tone_to(Vector4(400, 10, 0, -5))
	assert_that(_screen.tone).is_equal(Vector4(255, 10, 0, 0))


func test_ticks_are_counted_from_the_time_that_passes() -> void:
	_screen.tone_to(Vector4(60, 0, 0, 0), 6 * TICK)
	_screen.advance(TICK / 2.0)
	assert_that(_screen.tone).is_equal(Vector4.ZERO)
	_screen.advance(TICK * 2.5)
	assert_float(_screen.tone.x).is_equal_approx(30.0, 0.001)


func test_a_flash_fades_and_a_shake_swings_back_to_rest() -> void:
	_screen.flash(Color(1, 1, 1, 1), 4 * TICK)
	_ticks(2)
	assert_float(_screen.flash_color.a).is_equal_approx(0.5, 0.0001)
	_ticks(2)
	assert_float(_screen.flash_color.a).is_equal(0.0)
	_screen.shake_screen(2, 5, 3 * TICK)
	_ticks(1)
	assert_float(_screen.shake).is_equal(1.0)
	_ticks(4)
	assert_float(_screen.shake).is_equal(5.0)
	_ticks(1)
	assert_float(_screen.shake).is_equal(4.0)
	_ticks(1)
	assert_float(_screen.shake).is_equal(3.0)
	_ticks(30)
	assert_float(_screen.shake).is_equal(0.0)
	_screen.shake_screen(1, 3, TICK)
	_ticks(200)
	assert_float(_screen.shake).is_equal(0.0)


func test_a_scroll_slides_at_rpg_maker_s_speed_within_what_the_view_allows() -> void:
	_screen.scroll(Vector2i.RIGHT, 2, 4)
	assert_bool(_screen.is_scrolling()).is_true()
	_ticks(1)
	assert_that(_screen.scroll_offset).is_equal(Vector2(2, 0))
	_ticks(15)
	assert_that(_screen.scroll_offset).is_equal(Vector2(32, 0))
	assert_bool(_screen.is_scrolling()).is_false()
	_ticks(2)
	assert_that(_screen.scroll_offset).is_equal(Vector2(32, 0))
	_screen.clamp_scroll = func(wanted: Vector2) -> Vector2: return Vector2(minf(wanted.x, 36.0), wanted.y)
	_screen.scroll(Vector2i.RIGHT, 1, 6)
	_ticks(1)
	assert_that(_screen.scroll_offset).is_equal(Vector2(36, 0))
	_screen.scroll(Vector2i.LEFT, 1, 6)
	_ticks(1)
	assert_that(_screen.scroll_offset).is_equal(Vector2(28, 0))
	_screen.scroll_by(Vector2(-6, 3))
	assert_that(_screen.scroll_offset).is_equal(Vector2(22, 3))
	_screen.scroll_by(Vector2(100, 0))
	assert_that(_screen.scroll_offset).is_equal(Vector2(36, 3))
	_screen.reset_scroll()
	assert_that(_screen.scroll_offset).is_equal(Vector2.ZERO)
	assert_bool(_screen.is_scrolling()).is_false()


func test_pictures_show_move_turn_tone_and_go() -> void:
	_screen.show_picture(3, _texture, {"origin": Screen.Origin.CENTER, "position": Vector2(10, 20), "zoom": Vector2(200, 50), "opacity": 128, "blend": Screen.Blend.ADD})
	var shown := _screen.picture(3)
	assert_array([shown["texture"], shown["origin"], shown["position"], shown["zoom"], shown["opacity"], shown["blend"]]) \
		.is_equal([_texture, Screen.Origin.CENTER, Vector2(10, 20), Vector2(200, 50), 128.0, Screen.Blend.ADD])
	_screen.move_picture(3, 2 * TICK, {"position": Vector2(30, 0), "opacity": 0})
	_ticks(1)
	assert_array([shown["position"], shown["zoom"], shown["opacity"]]).is_equal([Vector2(20, 10), Vector2(200, 50), 64.0])
	_ticks(1)
	assert_array([shown["position"], shown["opacity"]]).is_equal([Vector2(30, 0), 0.0])
	_screen.move_picture(3, 0.0, {"zoom": Vector2(100, 100)})
	assert_that(shown["zoom"]).is_equal(Vector2(100, 100))
	_screen.rotate_picture(3, 10)
	_ticks(2)
	assert_float(shown["angle"]).is_equal(10.0)
	_screen.rotate_picture(3, -800)
	_ticks(1)
	assert_float(shown["angle"]).is_equal(330.0)
	_screen.tone_picture(3, Vector4(0, 0, 100, 0), 2 * TICK)
	_ticks(1)
	assert_that(shown["tone"]).is_equal(Vector4(0, 0, 50, 0))
	_screen.show_picture(1, _texture)
	assert_array(_screen.picture_numbers()).is_equal([1, 3])
	_screen.erase_picture(3)
	assert_dict(_screen.picture(3)).is_empty()
	_screen.show_picture(51, _texture)
	_screen.move_picture(9, 1.0)
	assert_array(_screen.picture_numbers()).is_equal([1])
	assert_array(_world.logged.filter(func(line: String) -> bool: return line.contains("no picture numbered 51"))).has_size(1)


func test_a_frozen_screen_comes_back_in_20_ticks_or_60_through_a_picture() -> void:
	_screen.transition(_texture)
	assert_array([_screen.frozen, _screen.transition_texture]).is_equal([false, null])
	_screen.freeze()
	assert_bool(_screen.frozen).is_true()
	assert_bool(_screen.is_transitioning()).is_false()
	_ticks(9)
	assert_array([_screen.frozen, _screen.is_transitioning()]).is_equal([true, false])
	# Frozen too long: it comes back by itself, as the reference's.
	_ticks(1)
	assert_bool(_screen.is_transitioning()).is_true()
	_ticks(7)
	assert_bool(_screen.frozen).is_true()
	_ticks(1)
	assert_bool(_screen.frozen).is_false()
	_screen.freeze()
	_ticks(5)
	_screen.transition()
	_ticks(10)
	assert_float(_screen.transition_progress).is_equal_approx(0.5, 0.0001)
	_ticks(10)
	assert_bool(_screen.frozen).is_false()
	_screen.freeze()
	_screen.transition(_texture)
	assert_object(_screen.transition_texture).is_same(_texture)
	_ticks(59)
	assert_bool(_screen.is_transitioning()).is_true()
	_ticks(1)
	assert_bool(_screen.frozen).is_false()
	_screen.freeze()
	_screen.transition(null, 5 * TICK)
	_ticks(5)
	assert_bool(_screen.frozen).is_false()


func test_kept_by_the_save_through_json() -> void:
	var path := _world.sandbox.root + "picture.png"
	Image.create(4, 4, false, Image.FORMAT_RGBA8).save_png(path)
	var saved_texture := ImageTexture.create_from_image(Image.load_from_file(path))
	saved_texture.take_over_path(path)
	_screen.tone_to(Vector4(10, 20, 30, 40), 10 * TICK)
	_ticks(5)
	_screen.scroll(Vector2i.DOWN, 1, 6)
	_ticks(1)
	_screen.show_picture(2, saved_texture, {"position": Vector2(5, 6), "blend": Screen.Blend.SUBTRACT})
	_screen.move_picture(2, 4 * TICK, {"position": Vector2(9, 6)})
	_ticks(1)
	var saved: Variant = JSON.parse_string(JSON.stringify(_screen.state()))
	var back := Screen.new(_world.logger, _world.config)
	back.restore(saved)
	assert_that(back.tone).is_equal(_screen.tone)
	assert_float(back.day_share).is_equal_approx(_screen.day_share, 0.000001)
	assert_that(back.scroll_offset).is_equal(Vector2(0, 16))
	var shown := back.picture(2)
	assert_str((shown["texture"] as Texture2D).resource_path).is_equal(path)
	assert_array([shown["position"], shown["blend"]]).is_equal([Vector2(6, 6), Screen.Blend.SUBTRACT])
	_ticks(5)
	back.advance(TICK * 5)
	assert_that(back.tone).is_equal(_screen.tone)
	assert_that(back.picture(2)["position"]).is_equal(_screen.picture(2)["position"])
	back.reset()
	assert_array([back.tone, back.day_share, back.scroll_offset, back.picture_numbers().size()]).is_equal([Vector4.ZERO, 1.0, Vector2.ZERO, 0])


func test_the_view_draws_the_tone_pictures_and_flash_and_moves_the_camera() -> void:
	_world.map({}, Vector2i(40, 30))
	var player := _world.walker(Vector2i(20, 15))
	var camera := WgCamera.new()
	player.add_child(camera)
	camera.make_current()
	var view := ScreenView.new(_screen)
	_world.root.add_child(view)
	view.draw()
	var tone := view.get_node("Tone").get_child(0) as ColorRect
	assert_bool(tone.visible).is_false()
	_screen.tone_to(Vector4(1, 2, 3, 4))
	_screen.flash(Color(1, 0, 0, 0.5))
	_screen.show_picture(4, _texture, {"origin": Screen.Origin.CENTER, "position": Vector2(7, 8), "zoom": Vector2(50, 200), "opacity": 51, "blend": Screen.Blend.ADD})
	_screen.rotate_picture(4, 180)
	_screen.advance(TICK)
	_screen.shake_screen(5, 5, 1.0)
	_screen.advance(TICK)
	_screen.scroll_offset = Vector2(16, 0)
	view.draw()
	assert_bool(tone.visible).is_true()
	assert_that((tone.material as ShaderMaterial).get_shader_parameter(&"tone")).is_equal(Vector4(1, 2, 3, 4))
	var flash := view.get_node("Flash").get_child(0) as ColorRect
	assert_array([flash.visible, flash.color]).is_equal([true, Color(1, 0, 0, 0.5)])
	var sprite := view.get_node("Pictures/Pictures/Picture4") as Sprite2D
	assert_array([sprite.texture, sprite.centered, sprite.position, sprite.scale, sprite.z_index]).is_equal([_texture, true, Vector2(7, 8), Vector2(0.5, 2), 4])
	assert_float(sprite.rotation).is_equal_approx(-PI, 0.0001)
	assert_float(sprite.modulate.a).is_equal_approx(0.2, 0.0001)
	assert_str((sprite.material as ShaderMaterial).shader.code).contains("render_mode blend_add;")
	assert_that(camera.position).is_equal(Vector2(16, 0))
	assert_that(camera.offset).is_equal(Vector2(2.5, 0))
	_screen.erase_picture(4)
	view.draw()
	assert_bool(is_instance_valid(sprite) and not sprite.is_queued_for_deletion()).is_false()


func test_a_frozen_still_is_drawn_at_the_screen_s_size_whatever_its_own() -> void:
	var view := ScreenView.new(_screen)
	view.capture = func() -> Texture2D: return ImageTexture.create_from_image(Image.create(1280, 960, false, Image.FORMAT_RGBA8))
	_world.root.add_child(view)
	_screen.freeze()
	view.draw()
	var still := view.get_node("Still").get_child(0) as TextureRect
	assert_bool(still.visible).is_true()
	assert_that(still.size).is_equal(view.get_viewport().get_visible_rect().size)
	_screen.transition(null, TICK)
	_screen.advance(TICK)
	view.draw()
	assert_bool(still.visible).is_false()


func test_the_view_holds_a_scroll_within_the_camera_s_limits() -> void:
	_world.map({}, Vector2i(40, 30))
	var player := _world.walker(Vector2i(20, 15))
	var camera := Camera2D.new()
	player.add_child(camera)
	camera.make_current()
	camera.limit_left = 0
	camera.limit_right = 640
	camera.limit_top = 0
	camera.limit_bottom = 480
	var view := ScreenView.new(_screen)
	_world.root.add_child(view)
	var half := camera.get_viewport_rect().size / 2.0
	var centre := player.global_position
	var allowed := Vector2(640, 480) - half - centre
	assert_that(_screen.clamp_scroll.call(Vector2(9999, 9999))).is_equal(allowed)
	assert_that(_screen.clamp_scroll.call(Vector2.ZERO)).is_equal(Vector2.ZERO.clamp(half - centre, allowed))
