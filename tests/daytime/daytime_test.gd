extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")

var _world: World


func before_test() -> void:
	_world = World.new(self)


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _settings(fields: Dictionary) -> void:
	assert_array(Array(_world.daytime.config().load_data(fields, "test"))).is_empty()


func _color(color: Color) -> String:
	return "%.2f %.2f %.2f" % [color.r, color.g, color.b]


func test_the_real_hour_is_the_player_s_clock() -> void:
	var now := Time.get_time_dict_from_system()
	var hour := _world.daytime.hour()
	assert_float(hour).is_between(float(now["hour"]), float(now["hour"]) + 1.0)
	var today := Time.get_date_dict_from_system()
	assert_int(_world.daytime.weekday()).is_equal((int(today["weekday"]) + 6) % 7)
	assert_int(_world.daytime.day()).is_between(1, 366)


func test_a_forced_hour_wins() -> void:
	_world.daytime.forced_hour = 23.0
	assert_float(_world.daytime.hour()).is_equal(23.0)
	assert_str(_world.daytime.moment()).is_equal("night")
	_settings({"source": "game"})
	assert_float(_world.daytime.hour()).is_equal(23.0)
	_world.daytime.forced_hour = -1.0
	assert_float(_world.daytime.hour()).is_equal(12.0)


func test_the_game_s_own_hour_moves_with_the_game_clock_and_counts_days() -> void:
	_settings({"source": "game", "start_hour": 22.0, "minutes_per_second": 1.0})
	assert_float(_world.daytime.hour()).is_equal(22.0)
	_world.daytime.advance(90.0)
	assert_float(_world.daytime.hour()).is_equal(23.5)
	_world.daytime.advance(60.0)
	assert_float(_world.daytime.hour()).is_equal_approx(0.5, 0.0001)
	assert_int(_world.daytime.day()).is_equal(1)
	assert_int(_world.daytime.weekday()).is_equal(1)
	_world.daytime.advance(-50.0)
	assert_float(_world.daytime.hour()).is_equal_approx(0.5, 0.0001)


func test_the_tint_glides_between_marks_and_holds_on_a_plateau() -> void:
	var daytime := _world.daytime
	assert_str(_color(daytime.tint(3.0))).is_equal("0.38 0.44 0.78")
	assert_str(_color(daytime.tint(6.0))).is_equal(_color(Color(0.38, 0.44, 0.78).lerp(Color(0.96, 0.86, 0.92), 0.5)))
	assert_str(_color(daytime.tint(12.0))).is_equal("1.00 1.00 1.00")
	assert_str(_color(daytime.tint(19.0))).is_equal("1.00 0.76 0.58")
	assert_float(daytime.light(12.0)).is_equal(0.0)
	assert_float(daytime.light(19.75)).is_equal_approx(0.5, 0.001)
	assert_float(daytime.light(23.0)).is_equal(1.0)
	var moments: Array[String] = []
	for hour: float in [5.9, 6.5, 7.0, 12.0, 18.0, 19.5, 21.0]:
		moments.append(String(daytime.moment(hour)))
	assert_array(moments).is_equal(["night", "dawn", "dawn", "day", "day", "dusk", "night"])


func test_the_day_goes_round_past_the_last_mark() -> void:
	_settings({"keys": [[6.0, "day"], [18.0, "night"]]})
	assert_str(_world.daytime.moment(3.0)).is_equal("night")
	assert_str(_world.daytime.moment(20.0)).is_equal("night")
	assert_float(_world.daytime.light(0.0)).is_equal_approx(0.5, 0.001)
	assert_float(_world.daytime.light(3.0)).is_equal_approx(0.25, 0.001)
	assert_float(_world.daytime.light(21.0)).is_equal_approx(0.75, 0.001)


func test_moments_tints_may_be_written_as_text_or_numbers() -> void:
	_settings({"moments": {"day": {"tint": "#ff8000", "light": 0}, "night": {"tint": [0.1, 0.2, 0.3], "light": 1}}, "keys": [[0, "night"], [12, "day"]]})
	assert_str(_color(_world.daytime.tint(12.0))).is_equal("1.00 0.50 0.00")
	assert_str(_color(_world.daytime.tint(0.0))).is_equal("0.10 0.20 0.30")


func test_a_moment_change_is_told_once() -> void:
	var changes: Array[String] = []
	_world.daytime.moment_changed.connect(func(old: StringName, new: StringName) -> void: changes.append("%s>%s" % [old, new]))
	_world.daytime.forced_hour = 12.0
	_world.daytime.advance(0.1)
	_world.daytime.forced_hour = 19.0
	_world.daytime.advance(0.1)
	_world.daytime.advance(0.1)
	_world.daytime.forced_hour = 23.0
	_world.daytime.advance(0.1)
	assert_array(changes).is_equal(["day>dusk", "dusk>night"])


func test_a_story_condition_reads_the_moment() -> void:
	_world.daytime.forced_hour = 23.0
	assert_bool(_world.story.check("time:night")).is_true()
	assert_bool(_world.story.check("!time:day")).is_true()
	assert_bool(_world.story.check("time:day")).is_false()
	assert_array(_world.logged).is_empty()


func test_the_game_s_own_hour_is_saved_and_a_new_game_starts_at_the_start_hour() -> void:
	_settings({"source": "game", "start_hour": 8.0, "minutes_per_second": 1.0})
	_world.save.add_part(&"daytime", _world.daytime.state, _world.daytime.restore, _world.daytime.reset)
	_world.daytime.advance(120.0)
	assert_bool(_world.save.write(1)).is_true()
	_world.save.new_game(2)
	assert_float(_world.daytime.hour()).is_equal(8.0)
	assert_bool(await _world.save.load_game(1)).is_true()
	assert_float(_world.daytime.hour()).is_equal(10.0)


func test_a_wrong_config_is_corrected() -> void:
	var settings := WgDaytimeConfig.new()
	var problems := settings.load_data({"start_hour": 30, "minutes_per_second": -1, "keys": [[5, "night"], [3, "day"], [7, "noon"], "x"]}, "daytime.json")
	assert_array(Array(problems)).is_equal([
		"daytime.json: minutes_per_second cannot be negative, got -1.0; using 1",
		"daytime.json: start_hour must be from 0 to 24, got 30.0; using 12",
		"daytime.json: keys: [3,\"day\"] is out of order; left out",
		"daytime.json: keys: [7,\"noon\"] is not [hour, a moment]; left out",
		"daytime.json: keys: \"x\" is not [hour, a moment]; left out",
	])
	assert_that(settings.keys).is_equal([[5.0, "night"]])
	var empty := WgDaytimeConfig.new()
	assert_array(Array(empty.load_data({"keys": []}, "daytime.json"))).is_equal(["daytime.json: keys needs a mark; using day all day"])
	assert_that(empty.keys).is_equal([[0.0, "day"]])
