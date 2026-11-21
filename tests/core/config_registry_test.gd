extends GdUnitTestSuite

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")
const ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const Sandbox := preload("res://tests/support/sandbox.gd")
const SampleConfig := preload("res://tests/support/sample_config.gd")
const SampleSub := preload("res://tests/support/sample_sub_config.gd")
const GameDisplayConfig := preload("res://tests/support/game_display_config.gd")

var _sandbox: Sandbox
var _registry: ConfigRegistry
var _logged: Array[String]


func before_test() -> void:
	_sandbox = Sandbox.new()
	_sandbox.use_data_folder()
	var logger := Log.new()
	logger.echo = false
	_logged = []
	logger.logged.connect(func(level: Log.Level, _channel: StringName, message: String) -> void:
		_logged.append("%s %s" % [Log.Level.keys()[level], message]))
	_registry = ConfigRegistry.new(Paths.new(false), logger)
	_registry.register(&"sample", SampleConfig, "sample")


func after_test() -> void:
	_sandbox.cleanup()


func test_without_a_file_the_config_has_its_defaults() -> void:
	assert_bool(_registry.has_file(&"sample")).is_false()
	assert_int((_registry.get_config(&"sample") as SampleConfig).count).is_equal(1)
	assert_array(_logged).is_empty()


func test_the_file_is_read_from_the_config_folder_and_problems_are_logged() -> void:
	_sandbox.write_json("config/sample.json", {"count": 7, "cuont": 1})
	assert_bool(_registry.has_file(&"sample")).is_true()
	assert_int((_registry.get_config(&"sample") as SampleConfig).count).is_equal(7)
	assert_array(_logged).is_equal(["WARN sample.json: unknown key 'cuont'"])


func test_a_config_is_read_once() -> void:
	_sandbox.write_json("config/sample.json", {"count": 7})
	var first := _registry.get_config(&"sample")
	_sandbox.write_json("config/sample.json", {"count": 8})
	assert_object(_registry.get_config(&"sample")).is_same(first)


func test_a_file_that_is_not_a_json_object_falls_back_to_defaults() -> void:
	_sandbox.write("config/sample.json", "[1, 2]")
	assert_int((_registry.get_config(&"sample") as SampleConfig).count).is_equal(1)
	_registry.register(&"broken", SampleConfig, "broken")
	_sandbox.write("config/broken.json", "{ not json")
	assert_int((_registry.get_config(&"broken") as SampleConfig).count).is_equal(1)
	assert_array(_logged).is_equal(["ERROR sample.json: not a JSON object, using defaults", "ERROR broken.json: not a JSON object, using defaults"])


func test_an_unknown_config_is_null_and_logged() -> void:
	assert_object(_registry.get_config(&"nope")).is_null()
	assert_array(_logged).is_equal(["ERROR unknown config 'nope'"])


func test_a_script_must_extend_WgConfig() -> void:
	assert_bool(_registry.register(&"bad", Paths, "bad")).is_false()
	assert_bool(_registry.is_registered(&"bad")).is_false()


func test_a_game_extends_an_engine_config_under_the_same_name() -> void:
	_registry.register(&"display", WgDisplayConfig, "display")
	_sandbox.write_json("config/display.json", {"window_scale": 4, "vignette": true})
	assert_bool(_registry.register(&"display", GameDisplayConfig, "display")).is_true()
	var config := _registry.get_config(&"display") as GameDisplayConfig
	assert_int(config.window_scale).is_equal(4)
	assert_bool(config.vignette).is_true()


func test_a_replacement_must_extend_the_registered_script() -> void:
	assert_bool(_registry.register(&"sample", SampleSub, "sample")).is_false()
	assert_object(_registry.get_config(&"sample")).is_instanceof(SampleConfig)


func test_registering_again_discards_the_loaded_config() -> void:
	var first := _registry.get_config(&"sample")
	_registry.register(&"sample", SampleConfig, "sample")
	assert_object(_registry.get_config(&"sample")).is_not_same(first)


func test_sources_come_over_the_defaults_and_the_project_s_file_over_them_field_by_field() -> void:
	assert_bool(_registry.is_given(&"sample")).is_false()
	var asked := [0]
	_registry.add_source(&"sample", func() -> Dictionary:
		asked[0] += 1
		return {"count": 5, "title": "from a source", "cuont": 2})
	assert_bool(_registry.is_given(&"sample")).is_true()
	var config := _registry.get_config(&"sample") as SampleConfig
	assert_int(config.count).is_equal(5)
	assert_str(config.title).is_equal("from a source")
	_registry.get_config(&"sample")
	assert_int(asked[0]).is_equal(1)
	_sandbox.write_json("config/sample.json", {"count": 9})
	_registry.add_source(&"sample", func() -> Variant: return "not fields")
	config = _registry.get_config(&"sample") as SampleConfig
	assert_int(config.count).is_equal(9)
	assert_str(config.title).is_equal("from a source")
	assert_array(_logged).is_equal(["WARN sample (source): unknown key 'cuont'", "WARN sample (source): unknown key 'cuont'"])


func test_a_resource_of_the_project_wins_over_its_json_field_by_field() -> void:
	_registry.add_source(&"sample", func() -> Dictionary: return {"title": "from a source", "count": 5})
	_sandbox.write_json("config/sample.json", {"count": 7})
	var own := SampleConfig.new()
	own.count = 3
	DirAccess.make_dir_recursive_absolute(_sandbox.root + "config")
	ResourceSaver.save(own, _sandbox.root + "config/sample.tres")
	assert_str(_registry.file_path(&"sample")).is_equal(_sandbox.root + "config/sample.tres")
	var config := _registry.get_config(&"sample") as SampleConfig
	assert_int(config.count).is_equal(3)
	assert_str(config.title).is_equal("from a source")


func test_a_resource_of_another_class_is_ignored_and_logged() -> void:
	DirAccess.make_dir_recursive_absolute(_sandbox.root + "config")
	ResourceSaver.save(WgDisplayConfig.new(), _sandbox.root + "config/sample.tres")
	assert_int((_registry.get_config(&"sample") as SampleConfig).count).is_equal(1)
	assert_array(_logged).is_equal(["ERROR sample.tres: not a sample_config.gd, ignored"])
