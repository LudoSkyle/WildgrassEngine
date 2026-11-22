extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")

var _world: World


func before_test() -> void:
	_world = World.new(self)
	_world.daytime.forced_hour = 23.0


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _color(color: Color) -> String:
	return "%.2f %.2f %.2f" % [color.r, color.g, color.b]


func test_a_map_outside_is_tinted_by_the_moment_and_its_shade() -> void:
	var map := _world.map()
	map.outside = true
	_world.daytime.advance(0.0)
	assert_object(_world.daytime.canvas_modulate.get_parent()).is_same(_world.maps.host)
	assert_str(_color(_world.daytime.canvas_modulate.color)).is_equal("0.38 0.44 0.78")
	map.shade = Color(0.5, 0.5, 0.5)
	_world.daytime.advance(0.0)
	assert_str(_color(_world.daytime.canvas_modulate.color)).is_equal("0.19 0.22 0.39")
	_world.daytime.forced_hour = 12.0
	_world.daytime.advance(0.0)
	assert_str(_color(_world.daytime.canvas_modulate.color)).is_equal("0.50 0.50 0.50")


func test_a_map_inside_or_no_map_is_never_tinted() -> void:
	_world.daytime.advance(0.0)
	assert_str(_color(_world.daytime.canvas_modulate.color)).is_equal("1.00 1.00 1.00")
	assert_float(_world.daytime.map_light()).is_equal(0.0)
	_world.map()
	_world.daytime.advance(0.0)
	assert_str(_color(_world.daytime.map_tint())).is_equal("1.00 1.00 1.00")


func test_the_shader_globals_follow_once_enabled() -> void:
	var daytime := RecordingDaytime.new(_world.logger, _world.config, _world.hooks)
	daytime.follow(_world.maps)
	daytime.forced_hour = 23.0
	var map := _world.map()
	map.outside = true
	daytime.advance(0.0)
	assert_array(daytime.pushed).is_empty()
	daytime.updates_shader_globals = true
	daytime.advance(0.0)
	map.outside = false
	daytime.advance(0.0)
	assert_array(daytime.pushed).is_equal(["0.38 0.44 0.78 1.0", "1.00 1.00 1.00 0.0"])
	daytime.canvas_modulate.free()


## Records what would go to the rendering server, which keeps no value headless.
class RecordingDaytime extends "res://addons/wildgrass/daytime/daytime.gd":
	var pushed: Array[String] = []

	func _set_shader_globals(color: Color, strength: float) -> void:
		pushed.append("%.2f %.2f %.2f %.1f" % [color.r, color.g, color.b, strength])


func test_a_night_light_comes_on_with_the_night_and_wavers() -> void:
	var map := _world.map()
	map.outside = true
	var lamp := WgNightLight.new()
	lamp.daytime = _world.daytime
	lamp.brightness = 2.0
	map.add_child(lamp)
	lamp.set_process(false)
	assert_object(lamp.texture).is_instanceof(GradientTexture2D)
	assert_int(lamp.texture.get_width()).is_equal(128)
	var energies: Array[float] = []
	for step in 5:
		lamp.advance(0.3)
		energies.append(lamp.energy)
	assert_float(energies.min()).is_greater(1.7)
	assert_float(energies.max()).is_less(2.3)
	assert_bool(energies.min() < energies.max()).is_true()
	lamp.flicker = 0.0
	lamp.advance(0.3)
	assert_float(lamp.energy).is_equal(2.0)
	_world.daytime.forced_hour = 12.0
	lamp.advance(0.3)
	assert_float(lamp.energy).is_equal(0.0)
	assert_bool(lamp.enabled).is_false()
	_world.daytime.forced_hour = 19.75
	lamp.advance(0.3)
	assert_float(lamp.energy).is_equal_approx(1.0, 0.01)
