extends GdUnitTestSuite

const Engine_ := preload("res://addons/wildgrass/wildgrass.gd")
const Sandbox := preload("res://tests/support/sandbox.gd")
const GameHooks := preload("res://tests/support/game_hooks.gd")
const RecordingDisplay := preload("res://tests/support/recording_display.gd")

var _sandbox: Sandbox


func before_test() -> void:
	_sandbox = Sandbox.new()
	_sandbox.use_data_folder()


func after_test() -> void:
	_sandbox.cleanup()


func _start_engine() -> Engine_:
	var engine: Engine_ = auto_free(Engine_.new())
	engine.log.echo = false
	return engine


func test_the_autoload_provides_every_service() -> void:
	var engine: Engine_ = get_tree().root.get_node("Wildgrass")
	for service: Object in [engine.paths, engine.log, engine.config, engine.display, engine.hooks, engine.clock, engine.screens]:
		assert_object(service).is_not_null()
	assert_bool(engine.config.is_registered(&"display")).is_true()
	assert_bool(engine.config.is_registered(&"log")).is_true()


func test_engine_ready_hooks_run_after_the_scene_is_ready_then_the_signal() -> void:
	var engine := _start_engine()
	var order: Array[String] = []
	engine.hooks.add(&"engine_ready", &"test", func() -> void: order.append("hook"))
	engine.ready_for_game.connect(func() -> void: order.append("signal"))
	add_child(engine)
	order.append("ready")
	await engine.ready_for_game
	assert_array(order).is_equal(["ready", "hook", "signal"])


func test_a_project_setting_replaces_a_service() -> void:
	_sandbox.set_setting("wildgrass/services/hooks", "res://tests/support/game_hooks.gd")
	assert_object(_start_engine().hooks).is_instanceof(GameHooks)


func test_a_replacement_that_does_not_extend_the_service_is_refused() -> void:
	_sandbox.set_setting("wildgrass/services/hooks", "res://tests/support/sample_config.gd")
	var engine := _start_engine()
	assert_object(engine.hooks).is_not_instanceof(GameHooks)
	assert_object(engine.hooks).is_instanceof(preload("res://addons/wildgrass/core/hooks/hooks.gd"))


func test_without_display_config_the_display_is_left_alone() -> void:
	_sandbox.set_setting("wildgrass/services/display", "res://tests/support/recording_display.gd")
	var engine := _start_engine()
	add_child(engine)
	assert_array((engine.display as RecordingDisplay).applied).is_empty()


func test_game_time_advances_with_frames() -> void:
	var engine := _start_engine()
	add_child(engine)
	await await_idle_frame()
	await await_idle_frame()
	assert_float(engine.clock.seconds).is_greater(0.0)


func test_game_time_stops_while_the_tree_is_paused() -> void:
	var engine := _start_engine()
	add_child(engine)
	await await_idle_frame()
	get_tree().paused = true
	var before := engine.clock.seconds
	await await_idle_frame()
	await await_idle_frame()
	var during := engine.clock.seconds
	get_tree().paused = false
	assert_float(during).is_equal(before)


func test_the_engine_declares_exactly_its_public_classes_none_of_them_godot_ones() -> void:
	var names: Array[String] = []
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if str(entry["path"]).begins_with("res://addons/wildgrass/"):
			names.append(str(entry["class"]))
	names.sort()
	assert_array(names).is_equal(["WgConfig", "WgDisplayConfig", "WgLogConfig", "WgScreen"])
	for class_name_ in names:
		assert_bool(ClassDB.class_exists(class_name_)).override_failure_message("%s is a Godot class" % class_name_).is_false()


func test_display_config_and_log_config_are_applied_at_start() -> void:
	_sandbox.set_setting("wildgrass/services/display", "res://tests/support/recording_display.gd")
	_sandbox.write_json("Data/configs/display_config.json", {"windowScale": 3})
	_sandbox.write_json("Data/configs/log_config.json", {"level": "error"})
	var engine := _start_engine()
	add_child(engine)
	var display := engine.display as RecordingDisplay
	assert_array(display.applied).has_size(1)
	assert_int(display.applied[0].window_scale).is_equal(3)
	assert_int(engine.log.level).is_equal(engine.log.Level.ERROR)


func test_a_missing_asset_is_logged_once() -> void:
	var engine := _start_engine()
	add_child(engine)
	var warnings: Array[String] = []
	engine.log.logged.connect(func(_level: int, channel: StringName, message: String) -> void: warnings.append("%s %s" % [channel, message]))
	engine.paths.report_missing("res://graphics/a.png", "WgMessageBox")
	engine.paths.report_missing("res://graphics/a.png", "WgMessageBox")
	assert_array(warnings).is_equal(["paths res://graphics/a.png, requested by WgMessageBox"])
