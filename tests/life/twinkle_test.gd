extends GdUnitTestSuite


func _twinkle(scale := Vector2.ONE, tint := Color.WHITE) -> WgTwinkle:
	var twinkle: WgTwinkle = auto_free(WgTwinkle.new())
	twinkle.scale = scale
	twinkle.modulate = tint
	add_child(twinkle)
	twinkle.set_process(false)
	return twinkle


func test_it_swells_and_pales_around_the_scenes_size_and_opacity() -> void:
	var twinkle := _twinkle(Vector2(2, 2), Color(1, 0.5, 0, 0.8))
	twinkle.advance(0.0)
	assert_that(twinkle.scale).is_equal(Vector2(2, 2))
	assert_float(twinkle.modulate.a).is_equal_approx(0.8 * (0.35 + 0.65 * 0.5), 0.0001)
	assert_float(twinkle.modulate.g).is_equal(0.5)
	var smallest := INF
	var largest := -INF
	var palest := INF
	for tick in 6000:
		twinkle.advance(0.01)
		smallest = minf(smallest, twinkle.scale.x)
		largest = maxf(largest, twinkle.scale.x)
		palest = minf(palest, twinkle.modulate.a)
		assert_float(twinkle.scale.x).is_equal(twinkle.scale.y)
	assert_float(smallest).is_between(2 * 0.65, 2 * 0.70)
	assert_float(largest).is_between(2 * 1.30, 2 * 1.35)
	assert_float(palest).is_between(0.8 * 0.35, 0.8 * 0.40)


func test_its_beat_follows_its_period() -> void:
	var twinkle := _twinkle()
	twinkle.period = 2.0
	twinkle.swell = 0.5
	twinkle.dim = 0.0
	# A quarter beat: the fast beat at its top, the slow one 0.5 + 0.5 sin(TAU / 13.2).
	twinkle.advance(0.5)
	var glow := 0.7 + 0.3 * (0.5 + 0.5 * sin(TAU * 0.5 / 6.6))
	assert_float(twinkle.scale.x).is_equal_approx(0.5 + glow, 0.0001)
	assert_float(twinkle.modulate.a).is_equal_approx(glow, 0.0001)
