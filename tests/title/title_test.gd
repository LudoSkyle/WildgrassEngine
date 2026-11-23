extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const MapBuilder := preload("res://tests/support/map_builder.gd")
const RecordingScreen := preload("res://tests/support/recording_screen.gd")
const RecordingTransition := preload("res://tests/support/recording_transition.gd")

var _world: World
var _player: WgWalker
var _events: Array[String] = []


func before_test() -> void:
	_world = World.new(self)
	_events = []
	RecordingTransition.calls.clear()
	_world.screens.register(&"title", _world.sandbox.scene("title.tscn", RecordingScreen))
	_world.screens.set_scene(&"transition_fade", _world.sandbox.scene("fade.tscn", RecordingTransition))
	var build := MapBuilder.new(_world.sandbox)
	var home := build.map(&"home", Vector2i(10, 10))
	MapBuilder.spawn(home, "Door", Vector2(24, 24))
	MapBuilder.spawn(home, "Bed", Vector2(72, 40), Vector2i.LEFT)
	build.save("home", home)
	_player = WgWalker.new()
	_player.name = "Player"
	_player.walkers = _world.walkers
	_world.maps.traveller = _player
	var title := _world.title
	title.title_shown.connect(func() -> void: _events.append("title shown"))
	title.back_to_title.connect(func() -> void: _events.append("back to title"))
	title.game_started.connect(func(slot: int, new: bool) -> void: _events.append("started %d new=%s" % [slot, new]))
	_world.hooks.add(&"new_game", &"test", func(slot: int) -> void: _events.append("new game hook %d" % slot))


func after_test() -> void:
	TranslationServer.set_locale("en")
	_world.root.free()
	_world.cleanup()
	if is_instance_valid(_player):
		_player.free()


## Sets fields of the title config, already read.
func _settings(fields: Dictionary) -> void:
	assert_array(Array(_world.title.config().load_data(fields, "test"))).is_empty()


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_world.screens.handle_input(event)


func _write() -> void:
	if _world.dialogue.box != null:
		_world.dialogue.box.set_process(false)
		_world.dialogue.box.advance(10.0)


func _open_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for screen in _world.screens.stack():
		names.append(screen.screen_name)
	return names


func _image(file_name: String) -> String:
	var path := _world.sandbox.root + file_name
	Image.create(4, 4, false, Image.FORMAT_RGBA8).save_png(path)
	return path


func test_the_config_has_its_defaults_and_refuses_negative_times() -> void:
	var defaults := _world.config.get_config(&"title") as WgTitleConfig
	assert_bool(defaults.show_at_start).is_false()
	assert_bool(defaults.show_prompt).is_true()
	assert_bool(defaults.show_choices).is_true()
	assert_float(defaults.fade_seconds).is_equal(0.6)
	assert_str(defaults.game_name()).is_equal(str(ProjectSettings.get_setting("application/config/name")))
	var settings := WgTitleConfig.new()
	var problems := settings.load_data({"controls_delay": -1, "fade_seconds": -0.5, "name": "Mirage"}, "title.json")
	assert_int(problems.size()).is_equal(2)
	assert_float(settings.controls_delay).is_equal(0.0)
	assert_float(settings.fade_seconds).is_equal(0.0)
	assert_str(settings.game_name()).is_equal("Mirage")


func test_start_shows_each_splash_then_the_title_and_skips_a_missing_one_reported_once() -> void:
	var missing: Array[String] = []
	_world.paths.asset_missing.connect(func(path: String, _requester: String) -> void: missing.append(path.get_file()))
	_settings({"splashes": [_image("studio.png"), _world.sandbox.root + "gone.png", _image("engine.png")]})
	var opened: Array[String] = []
	_world.screens.screen_opened.connect(func(screen_name: StringName, screen: WgScreen) -> void:
		var image := screen.get_node_or_null("Image") as TextureRect
		opened.append("%s %s" % [screen_name, image.texture.get_size() if image != null else ""]))
	_world.title.start()
	_world.title.start()
	assert_array(opened).is_equal(["splash (4.0, 4.0)"])
	(_world.screens.top() as WgSplashScreen).advance(2.0)
	assert_array(opened).is_equal(["splash (4.0, 4.0)", "splash (4.0, 4.0)"])
	_press("ui_accept")
	await get_tree().process_frame
	assert_array(opened).is_equal(["splash (4.0, 4.0)", "splash (4.0, 4.0)", "title "])
	assert_array(missing).is_equal(["gone.png"])
	assert_array(_events).is_equal(["title shown"])
	assert_object(_world.title.screen).is_same(_world.screens.top())


func test_the_title_screen_is_given_the_services_and_the_title_and_opens_once() -> void:
	var screen := _world.title.show_title() as RecordingScreen
	assert_object(_world.title.show_title()).is_same(screen)
	assert_array(_open_names()).is_equal([&"title"])
	assert_object(screen.opened_with["title"]).is_same(_world.title)
	assert_object(screen.opened_with["save"]).is_same(_world.save)
	assert_object(screen.opened_with["dialogue"]).is_same(_world.dialogue)
	assert_object(screen.opened_with["texts"]).is_same(_world.texts)
	assert_object(screen.opened_with["options"]).is_same(_world.options)


func _languages() -> void:
	_world.sandbox.write_json("config/language.json", {"choosable": ["en", "fr"], "names": ["English", "Français"]})
	_world.options.read()
	_world.options.add_engine_options(_world.dialogue, _world.texts)


func test_the_language_is_asked_at_first_launch_and_kept_as_the_option() -> void:
	_settings({"choose_language": true})
	_languages()
	assert_bool(_world.title.must_choose_language()).is_true()
	_world.title.start()
	var choice := _world.screens.top() as WgLanguageChoiceScreen
	assert_object(choice).is_not_null()
	assert_array(_events).is_empty()
	_press("ui_down")
	_press("ui_accept")
	await get_tree().process_frame
	assert_str(_world.texts.language).is_equal("fr")
	assert_that(JSON.parse_string(FileAccess.get_file_as_string(_world.options.file_path))["language"]).is_equal("fr")
	assert_array(_open_names()).is_equal([&"title"])
	assert_bool(_world.title.must_choose_language()).is_false()


func test_the_language_is_not_asked_unless_wanted_once_kept_with_a_game_saved_or_with_one_language() -> void:
	_languages()
	assert_bool(_world.title.must_choose_language()).is_false()
	_settings({"choose_language": true})
	assert_bool(_world.title.must_choose_language()).is_true()
	_world.sandbox.write_json("options.json", {"language": "en"})
	_world.options.read()
	assert_bool(_world.title.must_choose_language()).is_false()
	DirAccess.remove_absolute(_world.options.file_path)
	_world.options.read()
	assert_bool(_world.save.write(1)).is_true()
	assert_bool(_world.title.must_choose_language()).is_false()
	_world.save.erase(1)
	assert_bool(_world.title.must_choose_language()).is_true()
	(_world.config.get_config(&"language") as WgLanguageConfig).choosable.assign(["en"])
	assert_bool(_world.title.must_choose_language()).is_false()


func test_the_engine_choices_and_a_game_s_go_before_quit_or_another() -> void:
	var title := _world.title
	assert_array(title.choices()).is_equal([&"play", &"options", &"quit"])
	title.add_choice(&"credits", "Credits", func() -> bool: return false)
	title.add_choice(&"mystery", "Mystery", func() -> bool: return false, "met_ghost", &"play")
	title.add_choice(&"credits", "Thanks", func() -> bool: return false)
	assert_array(title.choices()).is_equal([&"mystery", &"play", &"options", &"credits", &"quit"])
	assert_array(title.shown().map(func(choice: Dictionary) -> String: return choice["text"])).is_equal(["wg.title.play", "wg.title.options", "Thanks", "wg.title.quit"])
	_world.story.set_flag(&"met_ghost")
	assert_str(title.shown()[0]["text"]).is_equal("Mystery")
	assert_bool(title.remove_choice(&"mystery")).is_true()
	assert_bool(title.remove_choice(&"mystery")).is_false()


func test_play_with_no_game_starts_one_in_slot_1_on_the_start_map_behind_the_fade() -> void:
	_settings({"start_map": "home", "start_point": "Bed", "fade_seconds": 0.25})
	_world.story.set_flag(&"old_flag")
	_world.clock.advance(30.0)
	var title_screen := _world.title.show_title()
	_world.screens.screen_closed.connect(func(screen_name: StringName) -> void: RecordingTransition.calls.append("closed %s" % screen_name))
	_world.hooks.add(&"map_loaded", &"test", func(_map: WgMap) -> void: RecordingTransition.calls.append("map loaded, title shown: %s" % title_screen.visible))
	assert_bool(await _world.title.play()).is_true()
	assert_array(RecordingTransition.calls).is_equal(["cover 0.25", "map loaded, title shown: false", "closed transition_none", "uncover", "closed transition_fade", "closed title"])
	assert_str(_world.maps.current_id).is_equal("home")
	assert_that(_player.cell).is_equal(Vector2i(4, 2))
	assert_that(_player.facing).is_equal(Vector2i.LEFT)
	assert_int(_world.save.slot).is_equal(1)
	assert_bool(_world.story.check("old_flag")).is_false()
	assert_float(_world.clock.seconds).is_equal(0.0)
	assert_array(_events).is_equal(["title shown", "new game hook 1", "started 1 new=true"])
	assert_array(_open_names()).is_empty()


func test_with_no_point_a_new_game_starts_on_the_start_cell_facing_its_way() -> void:
	_settings({"start_map": "home", "start_cell": {"x": 2, "y": 3}, "start_direction": {"x": 0, "y": -1}})
	_world.title.show_title()
	assert_bool(await _world.title.new_game(1)).is_true()
	assert_str(_world.maps.current_id).is_equal("home")
	assert_that(_player.cell).is_equal(Vector2i(2, 3))
	assert_that(_player.facing).is_equal(Vector2i.UP)
	# A point wins over the cell.
	_settings({"start_map": "home", "start_point": "Bed", "start_cell": {"x": 2, "y": 3}})
	_world.title.show_title()
	assert_bool(await _world.title.new_game(1)).is_true()
	assert_that(_player.cell).is_equal(Vector2i(4, 2))


func test_a_new_game_with_no_start_map_or_no_traveller_is_logged_and_the_title_stays() -> void:
	_world.title.show_title()
	_world.story.set_flag(&"kept")
	assert_bool(await _world.title.new_game(1)).is_false()
	_settings({"start_map": "home"})
	_world.maps.traveller = null
	assert_bool(await _world.title.new_game(1)).is_false()
	assert_array(_world.logged).is_equal([
		"ERROR no start map '' for a new game (title config, start_map)",
		"ERROR no traveller for a new game: set Wildgrass.maps.traveller",
	])
	assert_array(_open_names()).is_equal([&"title"])
	assert_bool(_world.story.check("kept")).is_true()
	assert_array(RecordingTransition.calls).is_empty()


func test_a_start_map_that_cannot_be_reached_lifts_the_black_over_the_title_again() -> void:
	_world.sandbox.scene("maps/broken.tscn")
	_settings({"start_map": "broken"})
	var title_screen := _world.title.show_title()
	assert_bool(await _world.title.new_game(1)).is_false()
	assert_array(RecordingTransition.calls).is_equal(["cover 0.6", "uncover"])
	assert_array(_open_names()).is_equal([&"title"])
	assert_bool(title_screen.visible).is_true()
	assert_int(_world.save.slot).is_equal(0)
	assert_str(_world.logged.back()).is_equal("ERROR the new game could not reach 'broken'")
	assert_array(_events).is_equal(["title shown", "new game hook 1"])


func _saved_game() -> void:
	_settings({"start_map": "home", "fade_seconds": 0.0})
	await _world.title.new_game(1)
	_player.place_at(Vector2i(6, 7), 0, Vector2i.UP)
	_world.story.set_flag(&"saved_flag")
	assert_bool(_world.save.write(1)).is_true()


func test_play_with_a_game_opens_the_choice_of_a_game_and_continuing_leaves_the_title() -> void:
	await _saved_game()
	assert_bool(_world.title.back()).is_true()
	assert_bool(_world.story.check("saved_flag")).is_false()
	var played := [null]
	var playing := func() -> void: played[0] = await _world.title.play()
	playing.call()
	assert_array(_open_names()).is_equal([&"title", &"save_slots"])
	var slots_screen := _world.screens.top() as WgSaveSlotsScreen
	slots_screen.options_card = true
	slots_screen.refresh()
	assert_array(slots_screen.slots).is_equal([1, 2, WgSaveSlotsScreen.OPTIONS_CARD])
	RecordingTransition.calls.clear()
	var title_screen := _world.title.screen
	_world.screens.screen_closed.connect(func(screen_name: StringName) -> void:
		if screen_name == &"transition_fade":
			RecordingTransition.calls.append("title shown: %s" % title_screen.visible))
	_press("ui_accept")
	_write()
	_press("ui_accept")
	await get_tree().process_frame
	assert_bool(played[0]).is_true()
	assert_array(RecordingTransition.calls).is_equal(["cover 0.0", "uncover", "title shown: false"])
	assert_str(_world.maps.current_id).is_equal("home")
	assert_that(_player.cell).is_equal(Vector2i(6, 7))
	assert_bool(_world.story.check("saved_flag")).is_true()
	assert_array(_open_names()).is_empty()
	assert_array(_events.slice(-2)).is_equal(["title shown", "started 1 new=false"])


func test_with_a_real_fade_the_choice_of_a_game_announces_it_before_closing() -> void:
	await _saved_game()
	_world.title.back()
	_world.title.config().fade_seconds = 0.05
	_world.screens.set_scene(&"transition_fade", "res://addons/wildgrass/maps/transitions/fade.tscn")
	var chosen: Array[String] = []
	_world.screens.screen_opened.connect(func(screen_name: StringName, screen: WgScreen) -> void:
		if screen_name == &"save_slots":
			screen.chosen.connect(func(slot: int, action: StringName) -> void: chosen.append("%d %s" % [slot, action])))
	var playing := func() -> void: await _world.title.play()
	playing.call()
	_press("ui_accept")
	_write()
	_press("ui_accept")
	for frame in 60:
		if _events.back() == "started 1 new=false":
			break
		await get_tree().process_frame
	assert_str(_events.back()).is_equal("started 1 new=false")
	assert_array(chosen).is_equal(["1 continue"])
	assert_array(_open_names()).is_empty()


func test_a_game_that_cannot_be_loaded_says_so_and_the_choice_stays() -> void:
	await _saved_game()
	_world.title.back()
	FileAccess.open(_world.save.path_of(1), FileAccess.WRITE).store_string("{broken")
	var playing := func() -> void: await _world.title.play()
	playing.call()
	_press("ui_accept")
	_write()
	_press("ui_accept")
	await get_tree().process_frame
	assert_array(_open_names()).contains_exactly([&"title", &"save_slots", &"message_box"])
	assert_object(_world.maps.current).is_null()


func test_a_free_slot_chosen_starts_a_new_game_in_it() -> void:
	await _saved_game()
	_world.title.back()
	var playing := func() -> void: await _world.title.play()
	playing.call()
	_press("ui_down")
	_press("ui_accept")
	_write()
	_press("ui_accept")
	await get_tree().process_frame
	assert_int(_world.save.slot).is_equal(2)
	assert_array(_events.slice(-2)).is_equal(["new game hook 2", "started 2 new=true"])
	assert_array(_open_names()).is_empty()


func test_options_opens_its_screen_over_the_title_and_quit_quits() -> void:
	_world.title.show_title()
	var opening := func() -> void: _events.append("options closes the title: %s" % await _world.title.open_options())
	opening.call()
	assert_array(_open_names()).is_equal([&"title", &"options"])
	_world.screens.top().close()
	assert_array(_events.slice(-1)).is_equal(["options closes the title: false"])
	_world.title.quit_game = func() -> void: _events.append("quit")
	assert_bool(_world.title.quit()).is_true()
	assert_array(_events.slice(-1)).is_equal(["quit"])


func test_back_to_the_title_closes_everything_drops_the_maps_and_resets_the_game() -> void:
	await _saved_game()
	_world.title.add_choice(&"x", "X", func() -> bool: return false)
	_world.screens.open(&"save")
	_world.dialogue.say("Hello")
	_world.dialogue.say("Still there?")
	_settings({"start_map": "home", "splashes": [_image("splash.png")]})
	assert_bool(_world.title.back()).is_true()
	assert_object(_world.maps.current).is_null()
	assert_str(_world.maps.current_id).is_empty()
	assert_object(_player.get_parent()).is_null()
	assert_bool(_world.dialogue.is_open()).is_false()
	assert_int(_world.save.slot).is_equal(0)
	assert_bool(_world.story.check("saved_flag")).is_false()
	assert_array(_open_names()).is_equal([&"title"])
	assert_array(_events.slice(-2)).is_equal(["back to title", "title shown"])


func test_back_in_the_middle_of_a_message_or_a_walk_leaves_the_next_game_free() -> void:
	await _saved_game()
	var sign_node := WgSign.new()
	sign_node.text = "[reload]The bell is hung."
	sign_node.position = _world.tiles.center_of(Vector2i(6, 6))
	_world.maps.current.entities_node().add_child(sign_node)
	_world.walkers.interact(_player)
	_write()
	var walked := [null]
	var walking := func() -> void: walked[0] = await _world.walkers.walk(_player, [Vector2i.DOWN, Vector2i.DOWN])
	walking.call()
	var loaded := [0]
	_world.hooks.add(&"map_loaded", &"test", func(_map: WgMap) -> void: loaded[0] += 1)
	_world.title.back()
	assert_int(loaded[0]).is_equal(0)
	assert_bool(_world.walkers.is_scripted(_player)).is_false()
	assert_bool(walked[0]).is_false()
	assert_array(_open_names()).is_equal([&"title"])
	assert_bool(await _world.title.new_game(1)).is_true()
	assert_bool(_world.walkers.may_act(_player)).is_true()
	assert_object(_world.menu.open()).is_not_null()


func test_back_is_refused_while_the_map_changes() -> void:
	await _saved_game()
	_world.maps.is_changing = true
	assert_bool(_world.title.back()).is_false()
	assert_str(_world.maps.current_id).is_equal("home")
	_world.maps.is_changing = false
