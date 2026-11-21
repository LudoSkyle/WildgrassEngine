extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")

var _world: World


func before_test() -> void:
	_world = World.new(self)


func after_test() -> void:
	TranslationServer.set_locale("en")
	_world.root.free()
	_world.cleanup()


func _press(action: String) -> bool:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return _world.screens.handle_input(event)


func _splash() -> WgSplashScreen:
	var texture := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	var screen := _world.screens.open(&"splash", {"texture": texture, "dialogue": _world.dialogue}) as WgSplashScreen
	screen.set_process(false)
	return screen


func test_a_splash_fades_in_stays_fades_out_then_closes() -> void:
	var screen := _splash()
	var image := screen.get_node("Image") as TextureRect
	assert_object(image.texture).is_not_null()
	var seen: Array[float] = []
	for step: float in [0.0, 0.2, 0.2, 1.0, 0.2, 0.1]:
		screen.advance(step)
		seen.append(snappedf(image.modulate.a, 0.01))
	assert_array(seen).is_equal([0.0, 0.5, 1.0, 1.0, 0.5, 0.25])
	assert_bool(screen.is_closed()).is_false()
	screen.advance(0.1)
	assert_bool(screen.is_closed()).is_true()


func test_confirm_skips_a_splash_and_it_takes_every_other_key() -> void:
	var screen := _splash()
	assert_bool(_press("ui_down")).is_true()
	assert_bool(screen.is_closed()).is_false()
	assert_bool(_press("ui_accept")).is_true()
	assert_bool(screen.is_closed()).is_true()


func _choice() -> WgLanguageChoiceScreen:
	_world.sandbox.write_json("config/language.json", {"choosable": ["en", "fr", "es"], "names": ["English", "Français", "Español"]})
	_world.texts.language = "fr"
	var screen := _world.screens.open(&"language_choice", {"languages": _world.texts.languages(), "texts": _world.texts, "dialogue": _world.dialogue}) as WgLanguageChoiceScreen
	return screen


func _pressed(screen: WgLanguageChoiceScreen) -> Array[String]:
	var shown: Array[String] = []
	for button: Node in screen.get_node("Panel/Margin/Languages").get_children():
		shown.append(("[%s]" if (button as Button).button_pressed else "%s") % (button as Button).text)
	return shown


func test_the_languages_show_by_their_names_from_the_current_one_and_go_round() -> void:
	var screen := _choice()
	assert_array(_pressed(screen)).is_equal(["English", "[Français]", "Español"])
	_press("ui_down")
	_press("ui_down")
	assert_array(_pressed(screen)).is_equal(["[English]", "Français", "Español"])
	_press("ui_up")
	assert_str(screen.selected()).is_equal("es")


func test_a_language_is_picked_with_confirm_and_cancel_does_nothing() -> void:
	var screen := _choice()
	var picked: Array[String] = []
	screen.chosen.connect(func(code: String) -> void: picked.append(code))
	assert_bool(_press("ui_cancel")).is_true()
	assert_bool(screen.is_closed()).is_false()
	_press("ui_up")
	_press("ui_accept")
	assert_array(picked).is_equal(["en"])
	assert_bool(screen.is_closed()).is_true()
