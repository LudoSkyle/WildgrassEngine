extends GdUnitTestSuite

const FADE := "res://addons/wildgrass/maps/transitions/fade.tscn"


func _fade(seconds: float) -> WgTransition:
	var fade: WgTransition = auto_free((load(FADE) as PackedScene).instantiate())
	add_child(fade)
	fade._on_open({"seconds": seconds})
	return fade


func test_cover_and_uncover_fade_over_time() -> void:
	var fade := _fade(0.1)
	fade.cover()
	assert_float(fade.call(&"opacity")).is_less(1.0)
	await fade.cover()
	assert_float(fade.call(&"opacity")).is_equal(1.0)
	fade.uncover()
	assert_float(fade.call(&"opacity")).is_greater(0.0)
	await fade.uncover()
	assert_float(fade.call(&"opacity")).is_equal(0.0)


func test_with_no_length_the_fade_is_instant() -> void:
	var fade := _fade(0.0)
	fade.cover()
	assert_float(fade.call(&"opacity")).is_equal(1.0)


func test_a_transition_swallows_input() -> void:
	assert_bool(_fade(0.0)._on_input(InputEventKey.new())).is_true()
