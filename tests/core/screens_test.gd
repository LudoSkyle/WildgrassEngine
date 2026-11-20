extends GdUnitTestSuite

const Log := preload("res://addons/wildgrass/core/log/log.gd")
const ScreenRegistry := preload("res://addons/wildgrass/core/screens/screen_registry.gd")
const Sandbox := preload("res://tests/support/sandbox.gd")
const RecordingScreen := preload("res://tests/support/recording_screen.gd")
const SelfClosingScreen := preload("res://tests/support/self_closing_screen.gd")

var _sandbox: Sandbox
var _layer: Node
var _screens: ScreenRegistry
var _errors: Array[String]


func before_test() -> void:
	_sandbox = Sandbox.new()
	_layer = auto_free(Node.new())
	add_child(_layer)
	var logger := Log.new()
	logger.echo = false
	_errors = []
	logger.logged.connect(func(_level: Log.Level, _channel: StringName, message: String) -> void: _errors.append(message))
	_screens = ScreenRegistry.new(logger, _layer)


func after_test() -> void:
	_sandbox.cleanup()


func test_the_scene_set_during_play_wins_then_the_setting_then_the_default() -> void:
	_screens.register(&"bag", "res://default.tscn")
	assert_str(_screens.scene_path(&"bag")).is_equal("res://default.tscn")
	_sandbox.set_setting("wildgrass/screens/bag", "res://setting.tscn")
	assert_str(_screens.scene_path(&"bag")).is_equal("res://setting.tscn")
	_screens.set_scene(&"bag", "res://play.tscn")
	assert_str(_screens.scene_path(&"bag")).is_equal("res://play.tscn")
	_screens.set_scene(&"bag", "")
	assert_str(_screens.scene_path(&"bag")).is_equal("res://setting.tscn")


func test_open_passes_its_arguments_and_announces_the_screen() -> void:
	_screens.register(&"bag", _sandbox.scene("bag.tscn", RecordingScreen))
	var opened: Array[StringName] = []
	_screens.screen_opened.connect(func(screen_name: StringName, _screen: WgScreen) -> void: opened.append(screen_name))
	var screen := _screens.open(&"bag", {"pocket": &"items"}) as RecordingScreen
	assert_dict(screen.opened_with).is_equal({"pocket": &"items"})
	assert_that(screen.screen_name).is_equal(&"bag")
	assert_object(screen.get_parent()).is_same(_layer)
	assert_array(opened).is_equal([&"bag"])


func test_open_returns_null_when_the_screen_cannot_be_opened() -> void:
	_screens.register(&"missing", _sandbox.root + "missing.tscn")
	_screens.register(&"plain", _sandbox.scene("plain.tscn"))
	assert_object(_screens.open(&"unknown")).is_null()
	assert_object(_screens.open(&"missing")).is_null()
	assert_object(_screens.open(&"plain")).is_null()
	assert_array(_errors).has_size(3)
	assert_int(_layer.get_child_count()).is_equal(0)


func test_only_the_top_screen_gets_input() -> void:
	var path := _sandbox.scene("s.tscn", RecordingScreen)
	_screens.register(&"a", path)
	_screens.register(&"b", path)
	var bottom := _screens.open(&"a") as RecordingScreen
	var top := _screens.open(&"b") as RecordingScreen
	var event := InputEventKey.new()
	assert_bool(_screens.handle_input(event)).is_true()
	assert_array(top.inputs).has_size(1)
	assert_array(bottom.inputs).is_empty()
	assert_int(bottom.mouse_behavior_recursive).is_equal(Control.MOUSE_BEHAVIOR_DISABLED)
	assert_int(bottom.focus_behavior_recursive).is_equal(Control.FOCUS_BEHAVIOR_DISABLED)


func test_closing_the_top_screen_gives_input_back_to_the_one_below() -> void:
	var path := _sandbox.scene("s.tscn", RecordingScreen)
	_screens.register(&"a", path)
	_screens.register(&"b", path)
	var bottom := _screens.open(&"a") as RecordingScreen
	_screens.open(&"b").close()
	assert_object(_screens.top()).is_same(bottom)
	assert_int(bottom.mouse_behavior_recursive).is_equal(Control.MOUSE_BEHAVIOR_INHERITED)
	assert_int(bottom.focus_behavior_recursive).is_equal(Control.FOCUS_BEHAVIOR_INHERITED)
	_screens.handle_input(InputEventKey.new())
	assert_array(bottom.inputs).has_size(1)


func test_closing_a_screen_below_keeps_the_top_one_active() -> void:
	var path := _sandbox.scene("s.tscn", RecordingScreen)
	_screens.register(&"a", path)
	_screens.register(&"b", path)
	var bottom := _screens.open(&"a")
	var top := _screens.open(&"b")
	bottom.close()
	assert_array(_screens.stack()).is_equal([top])
	assert_bool(_screens.is_open(&"a")).is_false()
	assert_int(top.mouse_behavior_recursive).is_equal(Control.MOUSE_BEHAVIOR_INHERITED)


func test_close_runs_once_and_announces_it() -> void:
	_screens.register(&"bag", _sandbox.scene("bag.tscn", RecordingScreen))
	var screen := _screens.open(&"bag") as RecordingScreen
	var closed_names: Array[StringName] = []
	var closed_signals: Array[bool] = []
	_screens.screen_closed.connect(func(screen_name: StringName) -> void: closed_names.append(screen_name))
	screen.closed.connect(func() -> void: closed_signals.append(true))
	screen.close()
	screen.close()
	assert_int(screen.close_calls).is_equal(1)
	assert_array(closed_signals).has_size(1)
	assert_array(closed_names).is_equal([&"bag"])
	assert_object(_screens.top()).is_null()


func test_without_screens_input_is_not_handled() -> void:
	assert_bool(_screens.handle_input(InputEventKey.new())).is_false()


func test_a_screen_freed_without_close_still_closes() -> void:
	var path := _sandbox.scene("s.tscn", RecordingScreen)
	_screens.register(&"a", path)
	_screens.register(&"b", path)
	var bottom := _screens.open(&"a") as RecordingScreen
	var top := _screens.open(&"b")
	var closed_names: Array[StringName] = []
	_screens.screen_closed.connect(func(screen_name: StringName) -> void: closed_names.append(screen_name))
	top.free()
	assert_array(closed_names).is_equal([&"b"])
	assert_object(_screens.top()).is_same(bottom)
	assert_bool(_screens.handle_input(InputEventKey.new())).is_true()
	assert_array(bottom.inputs).has_size(1)


func test_a_screen_closing_itself_on_open_comes_back_closed_and_unannounced() -> void:
	_screens.register(&"empty", _sandbox.scene("empty.tscn", SelfClosingScreen))
	var opened: Array[StringName] = []
	_screens.screen_opened.connect(func(screen_name: StringName, _screen: WgScreen) -> void: opened.append(screen_name))
	var screen := _screens.open(&"empty")
	assert_bool(screen.is_closed()).is_true()
	assert_array(opened).is_empty()
	assert_array(_screens.stack()).is_empty()
