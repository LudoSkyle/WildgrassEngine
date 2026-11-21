extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")

var _world: World


func before_test() -> void:
	_world = World.new(self)
	_world.sandbox.write_json("config/dialogue.json", {"frames": [{"style": "", "name": "Plain"}, {"style": "gold", "name": "Gold"}]})
	_world.sandbox.write_json("config/language.json", {"choosable": ["en", "fr"], "names": ["English", "Français"]})
	_world.options.add_engine_options(_world.dialogue, _world.texts)


func after_test() -> void:
	var bus := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_volume_db(bus, 0.0)
	AudioServer.set_bus_mute(bus, false)
	TranslationServer.set_locale("en")
	_world.root.free()
	_world.cleanup()


func _open() -> WgOptionsScreen:
	return _world.screens.open(&"options", {"options": _world.options, "dialogue": _world.dialogue, "texts": _world.texts}) as WgOptionsScreen


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_world.screens.handle_input(event)


func _rows(screen: WgOptionsScreen) -> Array:
	var shown := []
	for row: TreeItem in (screen.get_node("Box/List") as Tree).get_root().get_children():
		shown.append([row.get_text(0), row.get_text(1)])
	return shown


func _description(screen: WgOptionsScreen) -> String:
	return (screen.get_node("Box/Description") as Label).text


func test_each_option_shows_its_name_and_value_and_the_description_follows_the_cursor() -> void:
	var screen := _open()
	assert_array(_rows(screen)).is_equal([["Text speed", "Normal"], ["Message frame", "Plain"], ["Volume", "100%"], ["Language", "English"]])
	assert_float(((screen.get_node("Panel") as Panel).get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color.a).is_equal(1.0)
	assert_str(_description(screen)).is_equal("Choose how fast messages are written.")
	assert_str((screen.get_node("Box/List") as Tree).get_selected().get_text(0)).is_equal("Text speed")
	_press("ui_up")
	assert_str(screen.selected()).is_equal("message_speed")
	_press("ui_down")
	_press("ui_down")
	_press("ui_down")
	_press("ui_down")
	assert_str(screen.selected()).is_equal("language")
	assert_str(_description(screen)).is_equal("Choose the language of the game.")
	assert_int((screen.get_node("Box/List") as Tree).get_column_width(1)).is_equal(110)


func test_left_and_right_change_a_value_round_and_a_slider_stops_at_its_ends() -> void:
	var screen := _open()
	_press("ui_right")
	_press("ui_right")
	assert_int(_world.options.value(&"message_speed")).is_equal(1)
	assert_array(_rows(screen)[0]).is_equal(["Text speed", "Slow"])
	_press("ui_left")
	assert_int(_world.options.value(&"message_speed")).is_equal(3)
	_press("ui_down")
	_press("ui_down")
	_press("ui_right")
	assert_int(_world.options.value(&"volume")).is_equal(100)
	_press("ui_left")
	assert_int(_world.options.value(&"volume")).is_equal(95)
	assert_array(_rows(screen)[2]).is_equal(["Volume", "95%"])
	var kept: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_world.options.file_path))
	assert_int(int(kept["volume"])).is_equal(95)
	for step in 25:
		_press("ui_left")
	assert_int(_world.options.value(&"volume")).is_equal(0)


func test_a_language_changed_writes_the_rows_again_in_it() -> void:
	var french := Translation.new()
	french.locale = "fr"
	french.add_message("Text speed", "Vitesse du texte")
	french.add_message("Normal", "Normale")
	TranslationServer.add_translation(french)
	var screen := _open()
	assert_array(_rows(screen)[0]).is_equal(["Text speed", "Normal"])
	_world.texts.language = "fr"
	assert_array(_rows(screen)[0]).is_equal(["Vitesse du texte", "Normale"])
	TranslationServer.remove_translation(french)
	_world.texts.language = "en"
	for step in 3:
		_press("ui_down")
	_press("ui_right")
	assert_str(_world.texts.language).is_equal("fr")
	assert_array(_rows(screen)[3]).is_equal(["Language", "Français"])


func test_confirm_on_the_frame_shows_a_message_in_it_and_cancel_closes() -> void:
	var screen := _open()
	_press("ui_accept")
	assert_bool(_world.dialogue.is_open()).is_false()
	_press("ui_down")
	_press("ui_right")
	_press("ui_accept")
	assert_bool(_world.dialogue.is_open()).is_true()
	var box := _world.dialogue.box
	box.set_process(false)
	box.advance(10.0)
	assert_str(box.shown_text()).is_equal("This is how messages look.")
	assert_str((box.get_node("Frame") as Control).theme_type_variation).is_equal("MessageFrame_gold")
	_press("ui_accept")
	await get_tree().process_frame
	_press("ui_cancel")
	assert_bool(screen.is_closed()).is_true()


func test_the_menu_opens_it_and_comes_back() -> void:
	var menu := _world.menu.open() as WgMenuScreen
	_press("ui_down")
	_press("ui_accept")
	assert_str(_world.screens.top().screen_name).is_equal("options")
	_press("ui_cancel")
	assert_object(_world.screens.top()).is_same(menu)


func test_opened_alone_it_uses_the_engine_s_services() -> void:
	var engine := get_tree().root.get_node("Wildgrass")
	assert_str(engine.screens.scene_path(&"options")).is_equal("res://addons/wildgrass/options/options_screen.tscn")
	var screen := engine.screens.open(&"options") as WgOptionsScreen
	assert_object(screen.options).is_same(engine.options)
	assert_object(screen.texts).is_same(engine.texts)
	screen.close()
