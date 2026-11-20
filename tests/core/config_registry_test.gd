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
	_registry.register(&"sample", SampleConfig, "sample_config")


func after_test() -> void:
	_sandbox.cleanup()


func test_without_a_file_the_config_has_its_defaults() -> void:
	assert_bool(_registry.has_file(&"sample")).is_false()
	assert_int((_registry.get_config(&"sample") as SampleConfig).count).is_equal(1)
	assert_array(_logged).is_empty()


func test_the_file_is_read_from_data_configs_and_problems_are_logged() -> void:
	_sandbox.write_json("Data/configs/sample_config.json", {"count": 7, "cuont": 1})
	assert_bool(_registry.has_file(&"sample")).is_true()
	assert_int((_registry.get_config(&"sample") as SampleConfig).count).is_equal(7)
	assert_array(_logged).is_equal(["WARN sample_config.json: unknown key 'cuont'"])


func test_a_config_is_read_once() -> void:
	_sandbox.write_json("Data/configs/sample_config.json", {"count": 7})
	var first := _registry.get_config(&"sample")
	_sandbox.write_json("Data/configs/sample_config.json", {"count": 8})
	assert_object(_registry.get_config(&"sample")).is_same(first)


func test_a_file_that_is_not_a_json_object_falls_back_to_defaults() -> void:
	_sandbox.write("Data/configs/sample_config.json", "[1, 2]")
	assert_int((_registry.get_config(&"sample") as SampleConfig).count).is_equal(1)
	_registry.register(&"broken", SampleConfig, "broken")
	_sandbox.write("Data/configs/broken.json", "{ not json")
	assert_int((_registry.get_config(&"broken") as SampleConfig).count).is_equal(1)
	assert_array(_logged).is_equal(["ERROR sample_config.json: not a JSON object, using defaults", "ERROR broken.json: not a JSON object, using defaults"])


func test_an_unknown_config_is_null_and_logged() -> void:
	assert_object(_registry.get_config(&"nope")).is_null()
	assert_array(_logged).is_equal(["ERROR unknown config 'nope'"])


func test_a_script_must_extend_WgConfig() -> void:
	assert_bool(_registry.register(&"bad", Paths, "bad")).is_false()
	assert_bool(_registry.is_registered(&"bad")).is_false()


func test_a_game_extends_an_engine_config_under_the_same_name() -> void:
	_registry.register(&"display", WgDisplayConfig, "display_config")
	_sandbox.write_json("Data/configs/display_config.json", {"windowScale": 4, "vignette": true})
	assert_bool(_registry.register(&"display", GameDisplayConfig, "display_config")).is_true()
	var config := _registry.get_config(&"display") as GameDisplayConfig
	assert_int(config.window_scale).is_equal(4)
	assert_bool(config.vignette).is_true()


func test_a_replacement_must_extend_the_registered_script() -> void:
	assert_bool(_registry.register(&"sample", SampleSub, "sample_config")).is_false()
	assert_object(_registry.get_config(&"sample")).is_instanceof(SampleConfig)


func test_registering_again_discards_the_loaded_config() -> void:
	var first := _registry.get_config(&"sample")
	_registry.register(&"sample", SampleConfig, "sample_config")
	assert_object(_registry.get_config(&"sample")).is_not_same(first)
