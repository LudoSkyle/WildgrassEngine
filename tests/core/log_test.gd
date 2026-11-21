extends GdUnitTestSuite

const Log := preload("res://addons/wildgrass/core/log/log.gd")

var _log: Log
var _received: Array[String]


func before_test() -> void:
	_log = Log.new()
	_log.echo = false
	_received = []
	_log.logged.connect(func(level: Log.Level, channel: StringName, message: String) -> void:
		_received.append("%s %s %s" % [Log.Level.keys()[level], channel, message]))


func test_messages_below_the_level_are_dropped() -> void:
	_log.level = Log.Level.WARN
	_log.debug(&"a", "1")
	_log.info(&"a", "2")
	_log.warn(&"a", "3")
	_log.error(&"a", "4")
	assert_array(_received).is_equal(["WARN a 3", "ERROR a 4"])


func test_a_channel_level_overrides_the_global_level_both_ways() -> void:
	_log.level = Log.Level.INFO
	_log.channel_levels = {&"loud": Log.Level.DEBUG, &"quiet": Log.Level.ERROR}
	_log.debug(&"loud", "1")
	_log.warn(&"quiet", "2")
	_log.debug(&"other", "3")
	assert_array(_received).is_equal(["DEBUG loud 1"])


func test_configure_applies_the_levels_of_log_config() -> void:
	var config := WgLogConfig.new()
	config.load_data({"level": "warn", "channels": {"screens": "debug"}}, "log.json")
	_log.configure(config)
	_log.info(&"config", "1")
	_log.debug(&"screens", "2")
	assert_array(_received).is_equal(["DEBUG screens 2"])


func test_log_config_drops_an_unknown_channel_level() -> void:
	var config := WgLogConfig.new()
	var problems := config.load_data({"channels": {"screens": "loud", "map": "info"}}, "log.json")
	assert_array(problems).has_size(1)
	assert_dict(config.channels).is_equal({"map": "info"})
