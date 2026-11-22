extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")

signal choice_done(close_title: bool)

var _world: World
var _ran: Array[String] = []
var _translation: Translation


func before_test() -> void:
	_world = World.new(self)
	_ran = []
	_world.screens.register(&"title", "res://addons/wildgrass/title/title_screen.tscn")


func after_test() -> void:
	if _translation != null:
		TranslationServer.remove_translation(_translation)
	TranslationServer.set_locale("en")
	_world.root.free()
	_world.cleanup()


func _settings(fields: Dictionary) -> void:
	assert_array(Array(_world.title.config().load_data(fields, "test"))).is_empty()


func _open() -> WgTitleScreen:
	var screen := _world.title.show_title() as WgTitleScreen
	screen.set_process(false)
	return screen


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_world.screens.handle_input(event)


func _node(screen: WgTitleScreen, path: String) -> CanvasItem:
	return screen.get_node(path) as CanvasItem


func _labels(screen: WgTitleScreen) -> Array[String]:
	var shown: Array[String] = []
	for button: Node in screen.get_node("Choices/Margin/List").get_children():
		shown.append(("[%s]" if (button as Button).button_pressed else "%s") % (button as Button).text)
	return shown


func _image(file_name: String) -> String:
	var path := _world.sandbox.root + file_name
	Image.create(4, 4, false, Image.FORMAT_RGBA8).save_png(path)
	return path


## A choice that runs until the test says how it ends.
func _waiting_choice(id: StringName) -> void:
	_world.title.add_choice(id, String(id), func() -> bool:
		_ran.append(String(id))
		return await choice_done, "", &"play")


func test_black_lifts_then_the_arrival_plays_then_the_prompt() -> void:
	var screen := _open()
	var seen: Array[String] = []
	for step: float in [0.0, 0.25, 0.25, 0.3, 0.3]:
		screen.advance(step)
		seen.append("veil %.2f name %.2f %s" % [_node(screen, "Veil").modulate.a, _node(screen, "Name").modulate.a, WgTitleScreen.Stage.keys()[screen.stage]])
	assert_array(seen).is_equal([
		"veil 1.00 name 0.00 ARRIVAL",
		"veil 0.50 name 0.00 ARRIVAL",
		"veil 0.00 name 0.00 ARRIVAL",
		"veil 0.00 name 0.50 ARRIVAL",
		"veil 0.00 name 1.00 PROMPT",
	])
	assert_bool(_node(screen, "Prompt").visible).is_true()
	assert_bool(_node(screen, "Choices").visible).is_false()


func test_a_key_cuts_the_arrival_short_opening_nothing() -> void:
	var screen := _open()
	screen.advance(0.1)
	_press("ui_accept")
	assert_float(_node(screen, "Veil").modulate.a).is_equal(0.0)
	assert_float(_node(screen, "Name").modulate.a).is_equal(1.0)
	assert_int(screen.stage).is_equal(WgTitleScreen.Stage.PROMPT)
	assert_bool(_node(screen, "Choices").visible).is_false()
	_press("ui_cancel")
	assert_int(screen.stage).is_equal(WgTitleScreen.Stage.PROMPT)


func test_the_prompt_blinks_and_says_the_key() -> void:
	var screen := _open()
	_press("ui_accept")
	assert_str((screen.get_node("Prompt") as Label).text).is_equal("Press %s" % _world.texts.label("{key:ui_accept}"))
	var seen: Array[bool] = []
	for step: float in [0.0, 0.6, 0.2, 0.2, 0.2]:
		screen.advance(step)
		seen.append(_node(screen, "Prompt").visible)
	assert_array(seen).is_equal([true, true, false, false, true])


func test_the_engine_s_scene_shows_the_config_s_pictures_else_the_name() -> void:
	var screen := _open()
	assert_str((screen.get_node("Name") as Label).text).is_equal(_world.title.config().game_name())
	assert_bool(_node(screen, "Name").visible).is_true()
	screen.close()
	_settings({"background": _image("sky.png"), "logo": _image("logo.png"), "name": "Mirage"})
	var pictured := _open()
	assert_object((pictured.get_node("Background") as TextureRect).texture).is_not_null()
	assert_object((pictured.get_node("Logo") as TextureRect).texture).is_not_null()
	assert_bool(_node(pictured, "Name").visible).is_false()


func test_a_key_opens_the_choices_cancel_comes_back_to_the_prompt() -> void:
	var screen := _open()
	_press("ui_accept")
	_press("ui_accept")
	assert_int(screen.stage).is_equal(WgTitleScreen.Stage.CHOICES)
	assert_bool(_node(screen, "Choices").visible).is_true()
	assert_bool(_node(screen, "Prompt").visible).is_false()
	assert_array(_labels(screen)).is_equal(["[Play]", "Options", "Quit"])
	_press("ui_up")
	assert_array(_labels(screen)).is_equal(["Play", "Options", "[Quit]"])
	_press("ui_down")
	assert_str(screen.selected()).is_equal("play")
	_press("ui_cancel")
	assert_int(screen.stage).is_equal(WgTitleScreen.Stage.PROMPT)
	assert_bool(_node(screen, "Choices").visible).is_false()


func test_without_a_prompt_the_choices_come_after_the_arrival_and_cancel_stays() -> void:
	_settings({"show_prompt": false})
	var screen := _open()
	screen.advance(1.1)
	assert_int(screen.stage).is_equal(WgTitleScreen.Stage.CHOICES)
	assert_bool(_node(screen, "Prompt").visible).is_false()
	_press("ui_cancel")
	assert_int(screen.stage).is_equal(WgTitleScreen.Stage.CHOICES)


func test_the_choices_take_keys_after_the_controls_delay_once() -> void:
	_settings({"show_prompt": false, "controls_delay": 0.5})
	_waiting_choice(&"credits")
	var screen := _open()
	_press("ui_accept")
	_press("ui_down")
	assert_str(screen.selected()).is_equal("credits")
	screen.advance(0.5)
	_press("ui_accept")
	choice_done.emit(false)
	_press("ui_down")
	assert_str(screen.selected()).is_equal("play")


func test_without_choices_the_key_goes_straight_to_play() -> void:
	_settings({"show_choices": false})
	_world.title.add_choice(&"play", "Play", func() -> bool:
		_ran.append("play")
		return false)
	var screen := _open()
	_press("ui_accept")
	_press("ui_accept")
	assert_array(_ran).is_equal(["play"])
	assert_int(screen.stage).is_equal(WgTitleScreen.Stage.PROMPT)


func test_with_neither_prompt_nor_choices_the_title_waits_for_a_key_then_plays() -> void:
	_settings({"show_prompt": false, "show_choices": false})
	_world.title.add_choice(&"play", "Play", func() -> bool:
		_ran.append("play")
		return false)
	var screen := _open()
	screen.advance(1.1)
	screen.advance(0.8)
	assert_int(screen.stage).is_equal(WgTitleScreen.Stage.PROMPT)
	assert_bool(_node(screen, "Prompt").visible).is_false()
	assert_array(_ran).is_empty()
	_press("ui_accept")
	assert_array(_ran).is_equal(["play"])


func test_a_choice_hides_the_logo_and_the_prompt_while_it_runs_then_shows_them_again() -> void:
	_settings({"show_choices": false})
	_waiting_choice(&"play")
	var screen := _open()
	_press("ui_accept")
	_press("ui_accept")
	assert_int(screen.stage).is_equal(WgTitleScreen.Stage.BUSY)
	for path: String in ["Name", "Prompt"]:
		assert_bool(_node(screen, path).visible).override_failure_message(path).is_false()
	_press("ui_accept")
	assert_array(_ran).is_equal(["play"])
	choice_done.emit(false)
	assert_int(screen.stage).is_equal(WgTitleScreen.Stage.PROMPT)
	assert_bool(_node(screen, "Name").visible).is_true()
	assert_bool(_node(screen, "Prompt").visible).is_true()


func test_a_node_already_hidden_stays_hidden_and_a_choice_returning_true_closes_the_title() -> void:
	_settings({"logo": _image("logo.png")})
	_waiting_choice(&"credits")
	_world.title.add_choice(&"bonus", "Bonus", func() -> bool: return false, "credits_seen")
	var screen := _open()
	_press("ui_accept")
	_press("ui_accept")
	_press("ui_accept")
	assert_bool(_node(screen, "Logo").visible).is_false()
	_world.story.set_flag(&"credits_seen")
	choice_done.emit(false)
	assert_array(_labels(screen)).is_equal(["[credits]", "Play", "Options", "Bonus", "Quit"])
	assert_bool(_node(screen, "Logo").visible).is_true()
	assert_bool(_node(screen, "Name").visible).is_false()
	assert_int(screen.stage).is_equal(WgTitleScreen.Stage.CHOICES)
	_press("ui_accept")
	choice_done.emit(true)
	assert_bool(screen.is_closed()).is_true()


func test_from_the_choice_of_a_game_cancel_comes_back_to_the_prompt() -> void:
	_settings({"show_choices": false})
	assert_bool(_world.save.write(1)).is_true()
	var screen := _open()
	_press("ui_accept")
	_press("ui_accept")
	assert_object(_world.screens.top()).is_instanceof(WgSaveSlotsScreen)
	assert_bool(_node(screen, "Prompt").visible).is_false()
	_press("ui_cancel")
	await get_tree().process_frame
	assert_object(_world.screens.top()).is_same(screen)
	assert_int(screen.stage).is_equal(WgTitleScreen.Stage.PROMPT)
	assert_bool(_node(screen, "Prompt").visible).is_true()


func test_the_choices_follow_the_language() -> void:
	_translation = Translation.new()
	_translation.locale = "fr"
	_translation.add_message("Play", "Jouer")
	_translation.add_message("Press {key:ui_accept}", "Appuyez sur {key:ui_accept}")
	TranslationServer.add_translation(_translation)
	var screen := _open()
	_world.texts.language = "fr"
	assert_str(_labels(screen)[0]).is_equal("[Jouer]")
	assert_str((screen.get_node("Prompt") as Label).text).is_equal("Appuyez sur %s" % _world.texts.label("{key:ui_accept}"))


func test_a_scene_without_a_list_leaves_no_button_without_a_parent() -> void:
	var screen := _open()
	screen.list = ^"Missing"
	screen.refresh()
	assert_array(screen._buttons).is_empty()
	assert_that(screen.selected()).is_equal(&"play")
