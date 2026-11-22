extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")

var _world: World
var _changes: Array[String] = []


func before_test() -> void:
	_world = World.new(self)
	_changes = []
	_world.weather.changed.connect(func(old: StringName, new: StringName) -> void: _changes.append("%s>%s" % [old, new]))


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _weather(id: StringName) -> WgWeather:
	var weather := WgWeather.new()
	weather.id = id
	return weather


func test_none_is_the_engine_s_and_the_weather_on_at_the_start() -> void:
	assert_str(_world.weather.current).is_equal("none")
	assert_str(_world.weather.weather().id).is_equal("none")
	assert_array(_world.weather.weather().particles).is_empty()
	var mine := _weather(&"none")
	mine.name = "Mine"
	_world.weather.register(mine)
	assert_object(_world.weather.find(&"none")).is_same(mine)


func test_weathers_are_registered_else_in_the_folder_else_a_source_s() -> void:
	DirAccess.make_dir_recursive_absolute(_world.sandbox.root + "weather")
	ResourceSaver.save(_weather(&"rain"), _world.sandbox.root + "weather/rain.tres")
	_world.weather.register(_weather(&"snow"))
	_world.weather.add_source(func(id: StringName) -> WgWeather: return _weather(&"") if id == &"fog" else null, func() -> Array: return [&"fog"])
	assert_str(_world.weather.find(&"rain").id).is_equal("rain")
	assert_str(_world.weather.find(&"fog").id).is_equal("fog")
	assert_array(_world.weather.ids()).is_equal([&"none", &"snow", &"rain", &"fog"])
	assert_object(_world.weather.find(&"hail")).is_null()
	assert_array(_world.logged).is_equal(["ERROR unknown weather 'hail'"])


func test_the_weather_on_changes_and_says_so_an_unknown_one_shows_none() -> void:
	_world.weather.register(_weather(&"rain"))
	_world.weather.current = &"rain"
	_world.weather.current = &"rain"
	assert_str(_world.weather.weather().id).is_equal("rain")
	_world.weather.current = &"gone"
	assert_str(_world.weather.weather().id).is_equal("none")
	assert_array(_changes).is_equal(["none>rain", "rain>gone"])


func test_a_map_s_own_weather_wins_while_it_is_current() -> void:
	_world.weather.register(_weather(&"rain"))
	_world.weather.register(_weather(&"sandstorm"))
	_world.weather.current = &"rain"
	var desert := _world.map()
	desert.weather = &"sandstorm"
	_world.maps.map_changed.emit(desert)
	assert_str(_world.weather.shown()).is_equal("sandstorm")
	_world.weather.current = &"none"
	assert_str(_world.weather.weather().id).is_equal("sandstorm")
	desert.weather = &""
	_world.maps.map_changed.emit(desert)
	assert_str(_world.weather.shown()).is_equal("none")
	assert_array(_changes).is_equal(["none>rain", "rain>sandstorm", "sandstorm>none"])


func test_cycle_goes_through_every_weather_then_none() -> void:
	_world.weather.register(_weather(&"rain"))
	_world.weather.register(_weather(&"snow"))
	var seen: Array[String] = []
	for step in 3:
		_world.weather.cycle()
		seen.append(String(_world.weather.current))
	assert_array(seen).is_equal(["rain", "snow", "none"])


func test_a_particle_s_picture_follows_its_rank_and_splashes_take_their_share() -> void:
	var rain := _weather(&"rain")
	var pictures: Array[Texture2D] = []
	for size: int in [1, 2, 3, 9]:
		pictures.append(ImageTexture.create_from_image(Image.create(size, 1, false, Image.FORMAT_RGBA8)))
	rain.particles.assign(pictures.slice(0, 3))
	rain.splashes.assign([pictures[3]])
	var widths: Array[int] = []
	for rank in 8:
		widths.append(rain.picture(rank).get_width())
	assert_array(widths).is_equal([1, 9, 3, 9, 2, 9, 1, 9])
	rain.splash_share = 0.0
	assert_bool(rain.is_splash(1)).is_false()
	rain.splashes.clear()
	rain.splash_share = 0.5
	assert_bool(rain.is_splash(1)).is_false()
	assert_object(_weather(&"fog").picture(0)).is_null()
