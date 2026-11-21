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
	for service: Object in [engine.paths, engine.log, engine.config, engine.display, engine.hooks, engine.clock, engine.texts, engine.screens, engine.maps, engine.tiles, engine.walkers, engine.dialogue, engine.story, engine.quests, engine.items, engine.bag, engine.save, engine.menu, engine.options, engine.title, engine.species]:
		assert_object(service).is_not_null()
	assert_bool(engine.config.is_registered(&"display")).is_true()
	assert_bool(engine.config.is_registered(&"log")).is_true()
	assert_bool(engine.config.is_registered(&"dialogue")).is_true()
	assert_bool(engine.config.is_registered(&"language")).is_true()
	assert_bool(engine.config.is_registered(&"save")).is_true()
	assert_bool(engine.config.is_registered(&"title")).is_true()
	assert_array(engine.save.part_names()).is_equal([&"story", &"quests", &"bag", &"clock", &"map"])
	assert_array(engine.hooks.names(&"save_summary")).is_equal([&"wildgrass_clock", &"wildgrass_map"])
	assert_array(engine.menu.entries()).is_equal([&"bag", &"options", &"save", &"exit"])
	assert_object(engine.walkers.menu).is_same(engine.menu)
	assert_bool(engine.config.is_registered(&"options")).is_true()
	for id: StringName in [&"message_speed", &"message_frame", &"volume", &"language"]:
		assert_bool(engine.options.has_option(id)).is_true()
	assert_str(engine.options.file_path).is_equal("user://test_options.json")
	assert_str(engine.screens.scene_path(&"message_box")).is_equal("res://addons/wildgrass/dialogue/message_box.tscn")


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
	assert_array(names).is_equal(["WgBagConfig", "WgBagScreen", "WgCamera", "WgCharacterSprite", "WgConfig", "WgDialogueConfig", "WgDisplayConfig", "WgDoor", "WgInteractable", "WgItem", "WgItemBall", "WgItemReveal", "WgLanguageChoiceScreen", "WgLanguageConfig", "WgLogConfig", "WgMap", "WgMapConfig", "WgMapLink", "WgMenuScreen", "WgMessageBox", "WgMovementConfig", "WgOptionsConfig", "WgOptionsScreen", "WgPatrol", "WgPlayerInput", "WgQuest", "WgQuestEarning", "WgQuestObjective", "WgRoadblock", "WgSaveConfig", "WgSaveScreen", "WgSaveSlotsScreen", "WgScreen", "WgShowIf", "WgSign", "WgSpawnPoint", "WgSpecies", "WgSpeciesForm", "WgSplashScreen", "WgStudioConfig", "WgTalk", "WgTitleConfig", "WgTitleScreen", "WgTransition", "WgTrigger", "WgWalker", "WgWalkerController", "WgWander"])
	for class_name_ in names:
		assert_bool(ClassDB.class_exists(class_name_)).override_failure_message("%s is a Godot class" % class_name_).is_false()


func test_the_map_host_is_y_sorted_so_the_lower_map_draws_on_top() -> void:
	assert_bool(_start_engine().map_host.y_sort_enabled).is_true()


func test_display_config_and_log_config_are_applied_at_start() -> void:
	_sandbox.set_setting("wildgrass/services/display", "res://tests/support/recording_display.gd")
	_sandbox.write_json("config/display.json", {"window_scale": 3})
	_sandbox.write_json("config/log.json", {"level": "error"})
	var engine := _start_engine()
	add_child(engine)
	var display := engine.display as RecordingDisplay
	assert_array(display.applied).has_size(1)
	assert_int(display.applied[0].window_scale).is_equal(3)
	assert_int(engine.log.level).is_equal(engine.log.Level.ERROR)


func test_a_traveller_left_out_of_the_tree_goes_with_the_engine() -> void:
	var engine := Engine_.new()
	engine.log.echo = false
	var traveller := Node2D.new()
	engine.maps.traveller = traveller
	engine.free()
	assert_bool(is_instance_valid(traveller)).is_false()
	var kept := _start_engine()
	var standing := Node2D.new()
	add_child(standing)
	kept.maps.traveller = standing
	kept.free()
	assert_bool(is_instance_valid(standing)).is_true()
	standing.free()


func test_the_title_shows_once_ready_only_when_the_config_says_so() -> void:
	var quiet := _start_engine()
	add_child(quiet)
	await await_idle_frame()
	assert_array(quiet.screens.stack()).is_empty()
	_sandbox.write_json("config/title.json", {"show_at_start": true})
	var engine := _start_engine()
	add_child(engine)
	await await_idle_frame()
	assert_object(engine.screens.top()).is_instanceof(WgTitleScreen)
	assert_object(engine.title.screen).is_same(engine.screens.top())


func test_a_studio_project_is_read_through_the_layer_from_the_start() -> void:
	_sandbox.set_setting("wildgrass/services/display", "res://tests/support/recording_display.gd")
	_sandbox.set_setting("wildgrass/paths/studio", _sandbox.root)
	_sandbox.write("project.studio", "{}")
	_sandbox.write_json("Data/configs/display_config.json", {"klass": "Configs::Project::Display", "windowScale": 4})
	var engine := _start_engine()
	add_child(engine)
	assert_bool(engine.studio.installed).is_true()
	var display := engine.display as RecordingDisplay
	assert_array(display.applied).has_size(1)
	assert_int(display.applied[0].window_scale).is_equal(4)
	engine.studio.uninstall()


func test_the_default_language_is_set_at_start() -> void:
	var locale := TranslationServer.get_locale()
	_sandbox.write_json("config/language.json", {"default": "es"})
	add_child(_start_engine())
	assert_str(TranslationServer.get_locale()).is_equal("es")
	TranslationServer.set_locale(locale)


func test_a_missing_asset_is_logged_once() -> void:
	var engine := _start_engine()
	add_child(engine)
	var warnings: Array[String] = []
	engine.log.logged.connect(func(_level: int, channel: StringName, message: String) -> void: warnings.append("%s %s" % [channel, message]))
	engine.paths.report_missing("res://graphics/a.png", "WgMessageBox")
	engine.paths.report_missing("res://graphics/a.png", "WgMessageBox")
	assert_array(warnings).is_equal(["paths res://graphics/a.png, requested by WgMessageBox"])
