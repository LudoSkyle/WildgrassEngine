extends GdUnitTestSuite

const Clock := preload("res://addons/wildgrass/core/clock/clock.gd")

var _time_scale: float


func before_test() -> void:
	_time_scale = Engine.time_scale


func after_test() -> void:
	Engine.time_scale = _time_scale


func test_game_time_adds_up_frame_deltas_and_ignores_negative_ones() -> void:
	var clock := Clock.new()
	clock.advance(0.5)
	clock.advance(-1.0)
	clock.advance(0.25)
	assert_float(clock.seconds).is_equal(0.75)
	assert_int(clock.msec()).is_equal(750)


func test_speed_is_the_engine_time_scale_and_never_negative() -> void:
	var clock := Clock.new()
	clock.speed = 4.0
	assert_float(Engine.time_scale).is_equal(4.0)
	clock.speed = -1.0
	assert_float(clock.speed).is_equal(0.0)


func test_the_shader_global_follows_game_time_once_enabled() -> void:
	var clock := RecordingClock.new()
	clock.advance(1.0)
	assert_array(clock.pushed).is_empty()
	clock.updates_shader_global = true
	clock.advance(1.0)
	assert_array(clock.pushed).is_equal([2.0])


## Records what would go to the rendering server, which keeps no value headless.
class RecordingClock extends Clock:
	var pushed: Array[float] = []

	func _set_shader_global(value: float) -> void:
		pushed.append(value)
