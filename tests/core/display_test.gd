extends GdUnitTestSuite

const Display := preload("res://addons/wildgrass/core/display/display.gd")


func test_display_config_resets_impossible_values() -> void:
	var config := WgDisplayConfig.new()
	var problems := config.load_data({"resolution": {"x": 0, "y": 240}, "windowScale": 0}, "display_config.json")
	assert_array(problems).has_size(2)
	assert_that(config.resolution).is_equal(Vector2i(320, 240))
	assert_int(config.window_scale).is_equal(1)


func test_windowed_the_game_is_drawn_at_window_size_keeping_its_aspect() -> void:
	var config := WgDisplayConfig.new()
	config.load_data({"resolution": {"x": 320, "y": 240}, "windowScale": 4}, "display_config.json")
	var window: Window = auto_free(Window.new())
	Display.new().apply(config, window)
	assert_int(window.content_scale_mode).is_equal(Window.CONTENT_SCALE_MODE_CANVAS_ITEMS)
	assert_int(window.content_scale_aspect).is_equal(Window.CONTENT_SCALE_ASPECT_KEEP)
	assert_that(window.content_scale_size).is_equal(Vector2i(320, 240))
	assert_that(window.size).is_equal(Vector2i(1280, 960))
	assert_int(window.canvas_item_default_texture_filter).is_equal(Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST)


func test_fullscreen_sets_the_mode_and_keeps_the_game_resolution() -> void:
	var config := WgDisplayConfig.new()
	config.load_data({"fullscreen": true}, "display_config.json")
	var window: Window = auto_free(Window.new())
	Display.new().apply(config, window)
	assert_int(window.mode).is_equal(Window.MODE_FULLSCREEN)
	assert_that(window.content_scale_size).is_equal(Vector2i(320, 240))
