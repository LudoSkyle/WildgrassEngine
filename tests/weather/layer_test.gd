extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")

var _world: World
var _layer: WgWeatherLayer


func before_test() -> void:
	_world = World.new(self)
	_layer = WgWeatherLayer.new()
	_world.root.add_child(_layer)
	_layer.set_process(false)
	_layer.seed(11)


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _picture(width: int, height: int) -> Texture2D:
	return ImageTexture.create_from_image(Image.create(width, height, false, Image.FORMAT_RGBA8))


func _rain() -> WgWeather:
	var rain := WgWeather.new()
	rain.id = &"rain"
	rain.particles.assign([_picture(2, 8), _picture(2, 12), _picture(2, 16)])
	rain.splashes.assign([_picture(6, 2)])
	rain.particle_velocity = Vector2(-90, 360)
	rain.tone = Vector3(-30, -30, -30) / 255.0
	rain.gray = 10.0 / 255.0
	return rain


func test_sixty_particles_half_of_them_splashes_by_rank() -> void:
	_layer.show_weather(_rain())
	assert_int(_layer.sprites.size()).is_equal(60)
	var drops := 0
	for rank in 60:
		if _layer.sprites[rank].texture.get_height() >= 8:
			drops += 1
	assert_int(drops).is_equal(30)


func test_a_drop_falls_along_its_slope_and_is_born_again_after_its_distance() -> void:
	_layer.show_weather(_rain())
	_layer.advance(0.01)
	_layer.advance(0.01)
	var before: Array[Vector2] = []
	for rank in 60:
		before.append(_layer.sprites[rank].position)
	_layer.advance(0.1)
	var along := 0
	for rank in range(0, 60, 2):
		var moved := _layer.sprites[rank].position - before[rank]
		if moved.y > 0.0 and absf(moved.x / moved.y + 0.25) < 0.05:
			along += 1
	assert_int(along).is_greater(20)
	var reborn := 0
	for step in 100:
		var at := _layer.sprites[0].position
		_layer.advance(0.05)
		var jump := _layer.sprites[0].position - at
		if jump.length() > 40.0:
			reborn += 1
	assert_int(reborn).is_greater(2)


func test_drops_are_born_around_the_view_and_splashes_show_only_their_last_moment() -> void:
	_layer.show_weather(_rain())
	_layer.view = Rect2(1000, 2000, 320, 240)
	var shown_splash := 0
	var hidden_splash := 0
	for step in 40:
		_layer.advance(0.05)
		for rank in 60:
			var sprite := _layer.sprites[rank]
			if rank % 2 == 0:
				assert_bool(Rect2(1000 - 330, 2000 - 260, 980, 740).has_point(sprite.position)).override_failure_message(str(sprite.position)).is_true()
			elif sprite.modulate.a > 0.0:
				shown_splash += 1
			else:
				hidden_splash += 1
	assert_int(shown_splash).is_greater(0)
	assert_int(hidden_splash).is_greater(shown_splash)


func test_particles_stay_anchored_to_the_map_when_the_view_moves() -> void:
	var still := _rain()
	still.particle_velocity = Vector2(0, 0.0001)
	still.splashes.clear()
	_layer.show_weather(still)
	_layer.advance(0.01)
	_layer.advance(0.01)
	var before: Array[Vector2] = []
	for rank in 60:
		before.append(_layer.sprites[rank].position)
	_layer.view = Rect2(16, 8, 320, 240)
	_layer.advance(0.01)
	var kept := 0
	for rank in 60:
		if _layer.sprites[rank].position == before[rank]:
			kept += 1
	assert_int(kept).is_greater(50)


func test_snow_floats_off_its_line() -> void:
	var snow := WgWeather.new()
	snow.particles.assign([_picture(3, 3)])
	snow.particle_velocity = Vector2(-120, 120)
	_layer.show_weather(snow)
	_layer.advance(0.01)
	var straight := [0]
	for step in 20:
		var at := _layer.sprites[5].position
		_layer.advance(0.05)
		var moved := _layer.sprites[5].position - at
		if moved.length() < 30.0 and absf(moved.x + moved.y) < 0.5:
			straight[0] += 1
	snow.floating = true
	var floating := 0
	for step in 20:
		var at := _layer.sprites[5].position
		_layer.advance(0.05)
		var moved := _layer.sprites[5].position - at
		if moved.length() < 30.0 and absf(moved.x + moved.y) >= 0.5:
			floating += 1
	assert_int(straight[0]).is_greater(10)
	assert_int(floating).is_greater(5)


func test_the_layer_tiles_the_view_plus_one_and_drifts() -> void:
	var fog := WgWeather.new()
	fog.layer = _picture(64, 64)
	fog.layer_velocity = Vector2(-16, 0)
	_layer.show_weather(fog)
	assert_int(_layer.tiles.size()).is_equal(6 * 5)
	_layer.advance(0.0)
	var first := _layer.tiles[0].position
	_layer.advance(1.0)
	assert_float(_layer.tiles[0].position.x).is_equal(first.x - 16.0)
	for step in 10:
		_layer.advance(1.0)
	var covered := Rect2()
	for tile in _layer.tiles:
		covered = covered.merge(Rect2(tile.position, Vector2(64, 64))) if covered.has_area() else Rect2(tile.position, Vector2(64, 64))
	assert_bool(covered.encloses(_layer.view)).is_true()


func test_the_tone_is_set_shown_and_hidden_without_one() -> void:
	_layer.show_weather(_rain())
	_layer.advance(0.1)
	var material := _layer.tone_rect.material as ShaderMaterial
	assert_that(material.get_shader_parameter(&"tone")).is_equal(Vector3(-30, -30, -30) / 255.0)
	assert_float(material.get_shader_parameter(&"gray")).is_equal_approx(10.0 / 255.0, 0.0001)
	assert_bool(_layer.tone_rect.visible).is_true()
	assert_that(_layer.tone_rect.size).is_equal(Vector2(384, 304))
	_layer.show_weather(WgWeather.new())
	_layer.advance(0.1)
	assert_bool(_layer.tone_rect.visible).is_false()
	_layer.show_weather(null)
	_layer.advance(0.1)
	assert_bool(_layer.tone_rect.visible).is_false()
	assert_int(_layer.sprites.size()).is_equal(0)


func test_the_sun_beats_and_fades_as_night_falls() -> void:
	var sun := WgWeather.new()
	sun.tone = Vector3(64, 64, 32) / 255.0
	sun.pulse = 60.0 / 255.0
	sun.sunlight = true
	_layer.daytime = _world.daytime
	var map := _world.map()
	map.outside = true
	_world.daytime.forced_hour = 12.0
	_layer.show_weather(sun)
	var reds: Array[float] = []
	for step in 20:
		_layer.advance(0.1)
		reds.append((_layer.tone_rect.material as ShaderMaterial).get_shader_parameter(&"tone").x * 255.0)
	assert_float(reds.max()).is_between(120.0, 132.0)
	assert_float(reds.min()).is_less(70.0)
	assert_float(reds[7]).is_greater(reds[0])
	assert_float(reds[12]).is_less(reds[8])
	_world.daytime.forced_hour = 23.0
	_layer.advance(0.1)
	assert_that((_layer.tone_rect.material as ShaderMaterial).get_shader_parameter(&"tone")).is_equal(Vector3.ZERO)
	assert_bool(_layer.tone_rect.visible).is_false()


func test_the_weather_shows_on_maps_outside_only() -> void:
	_world.weather.register(_rain())
	_world.weather.current = &"rain"
	var map := _world.map()
	map.outside = true
	_world.maps.map_changed.emit(map)
	var layer := _world.weather.layer
	assert_object(layer.get_parent()).is_same(_world.maps.host)
	assert_int(layer.sprites.size()).is_equal(60)
	map.outside = false
	_world.maps.map_changed.emit(map)
	assert_int(layer.sprites.size()).is_equal(0)
	map.outside = true
	_world.maps.map_changed.emit(map)
	_world.weather.current = &"none"
	assert_int(layer.sprites.size()).is_equal(0)
