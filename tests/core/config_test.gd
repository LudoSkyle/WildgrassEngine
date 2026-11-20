extends GdUnitTestSuite

const SampleConfig := preload("res://tests/support/sample_config.gd")

var _config: SampleConfig


func before_test() -> void:
	_config = SampleConfig.new()


func test_missing_keys_keep_their_defaults() -> void:
	assert_array(_config.load_data({}, "s.json")).is_empty()
	assert_int(_config.count).is_equal(1)
	assert_str(_config.title).is_equal("default")


func test_camel_case_keys_fill_snake_case_fields() -> void:
	var problems := _config.load_data({"layer2Name": "top", "ratio": 2, "enabled": true, "title": "t", "id": "x"}, "s.json")
	assert_array(problems).is_empty()
	assert_str(_config.layer_2_name).is_equal("top")
	assert_float(_config.ratio).is_equal(2.0)
	assert_bool(_config.enabled).is_true()
	assert_str(_config.title).is_equal("t")
	assert_that(_config.id).is_equal(&"x")


func test_an_int_accepts_a_whole_number_only() -> void:
	assert_array(_config.load_data({"count": 4.0}, "s.json")).is_empty()
	assert_int(_config.count).is_equal(4)
	assert_array(_config.load_data({"count": 4.5}, "s.json")).contains(["s.json.count: expected int, got 4.5"])
	assert_int(_config.count).is_equal(4)


func test_an_unknown_key_is_reported_and_ignored() -> void:
	assert_array(_config.load_data({"cuont": 3}, "s.json")).is_equal(["s.json: unknown key 'cuont'"])
	assert_int(_config.count).is_equal(1)


func test_a_non_exported_variable_is_not_a_field() -> void:
	assert_array(_config.load_data({"internal": 3}, "s.json")).has_size(1)
	assert_int(_config.internal).is_equal(0)


func test_a_wrong_type_is_reported_and_the_value_kept() -> void:
	assert_array(_config.load_data({"enabled": "yes", "title": 3}, "s.json")).has_size(2)
	assert_bool(_config.enabled).is_false()
	assert_str(_config.title).is_equal("default")


func test_vectors_and_colors_are_read_from_json() -> void:
	var problems := _config.load_data({"size": {"x": 320, "y": 240}, "offset": {"x": 0.25, "y": 1}, "tint": "#ff000080"}, "s.json")
	assert_array(problems).is_empty()
	assert_that(_config.size).is_equal(Vector2i(320, 240))
	assert_that(_config.offset).is_equal(Vector2(0.25, 1.0))
	assert_that(_config.tint).is_equal(Color.html("#ff000080"))


func test_an_incomplete_vector_or_a_bad_color_is_rejected() -> void:
	var problems := _config.load_data({"size": {"x": 2}, "offset": {"x": 1, "y": 1, "z": 1}, "tint": "red-ish"}, "s.json")
	assert_array(problems).has_size(3)
	assert_that(_config.size).is_equal(Vector2i(1, 1))
	assert_that(_config.tint).is_equal(Color.WHITE)


func test_typed_arrays_and_dictionaries_keep_their_element_types() -> void:
	var problems := _config.load_data({"tags": ["x", "y"], "weights": [2.0, 3], "labels": {"a": 1.0}}, "s.json")
	assert_array(problems).is_empty()
	assert_array(_config.tags).is_equal(["x", "y"])
	assert_int(_config.weights.get_typed_builtin()).is_equal(TYPE_INT)
	assert_array(_config.weights).is_equal([2, 3])
	assert_dict(_config.labels).is_equal({"a": 1})


func test_an_array_with_one_wrong_element_is_rejected_whole() -> void:
	assert_array(_config.load_data({"weights": [1, "two"]}, "s.json")).is_equal(["s.json.weights[1]: expected int, got \"two\""])
	assert_array(_config.weights).is_equal([1])


func test_an_enum_is_read_by_name() -> void:
	assert_array(_config.load_data({"mode": "fast_forward"}, "s.json")).is_empty()
	assert_int(_config.mode).is_equal(SampleConfig.Mode.FAST_FORWARD)
	assert_array(_config.load_data({"mode": "FastForward"}, "s.json")).is_empty()


func test_an_unknown_enum_name_lists_the_choices() -> void:
	assert_array(_config.load_data({"mode": "warp"}, "s.json")).is_equal(["s.json.mode: expected one of slow, fast_forward, got \"warp\""])
	assert_int(_config.mode).is_equal(SampleConfig.Mode.SLOW)


func test_a_sub_config_is_read_and_reports_with_its_path() -> void:
	assert_array(_config.load_data({"sub": {"depth": 3}}, "s.json")).is_empty()
	assert_int(_config.sub.depth).is_equal(3)
	assert_array(_config.load_data({"sub": {"dpth": 3}}, "s.json")).is_equal(["s.json.sub: unknown key 'dpth'"])
	assert_array(_config.load_data({"sub": 3}, "s.json")).is_equal(["s.json.sub: expected an object"])
