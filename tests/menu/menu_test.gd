extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")

signal entry_done

var _world: World
var _player: WgWalker
var _calls: Array[String] = []


func before_test() -> void:
	_world = World.new(self)
	_calls = []
	_world.map({}, Vector2i(12, 12))
	_player = _world.walker(Vector2i(5, 5), WgPlayerInput.new())
	_world.maps.traveller = _player


func after_test() -> void:
	Input.action_release("ui_cancel")
	TranslationServer.set_locale("en")
	_world.root.free()
	_world.cleanup()


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_world.screens.handle_input(event)


func _write() -> void:
	if _world.dialogue.box != null:
		_world.dialogue.box.set_process(false)
		_world.dialogue.box.advance(10.0)


func _labels(screen: WgMenuScreen) -> Array[String]:
	var shown: Array[String] = []
	for button: Node in screen.get_node("Panel/Margin/Entries").get_children():
		shown.append((button as Button).text)
	return shown


func _pressed(screen: WgMenuScreen) -> int:
	return screen.get_node("Panel/Margin/Entries").get_children().find_custom(func(button: Button) -> bool: return button.button_pressed)


func _mark(name: String, close: bool) -> bool:
	_calls.append(name)
	return close


func test_entries_go_before_exit_or_another_and_an_id_taken_again_stays_in_place() -> void:
	var menu := _world.menu
	assert_array(menu.entries()).is_equal([&"bag", &"save", &"exit"])
	menu.add_entry(&"dex", "Pokédex", _mark.bind("dex", false), "", &"bag")
	menu.add_entry(&"card", "Card", _mark.bind("card", false))
	menu.add_entry(&"last", "Last", _mark.bind("last", false), "", &"nowhere")
	menu.add_entry(&"dex", "Dex", _mark.bind("dex", true))
	assert_array(menu.entries()).is_equal([&"dex", &"bag", &"save", &"card", &"exit", &"last"])
	assert_bool(menu.remove_entry(&"last")).is_true()
	assert_bool(menu.remove_entry(&"last")).is_false()
	assert_str(menu.shown()[0]["text"]).is_equal("Dex")


func test_the_menu_key_opens_it_with_the_entries_whose_condition_holds() -> void:
	_world.story.set_flag(&"save_disabled")
	Input.action_press("ui_cancel")
	_player.advance(0.0)
	Input.action_release("ui_cancel")
	var screen := _world.screens.top() as WgMenuScreen
	assert_object(screen).is_not_null()
	assert_array(_labels(screen)).is_equal(["Bag", "Exit"])
	assert_object(_world.menu.open()).is_null()


func test_it_stays_shut_while_disabled() -> void:
	_world.menu.enabled = false
	assert_object(_world.menu.open()).is_null()
	assert_array(_world.screens.stack()).is_empty()


func test_the_cursor_moves_round_and_is_kept_then_falls_back_when_its_entry_is_gone() -> void:
	var screen := _world.menu.open() as WgMenuScreen
	assert_str(screen.selected()).is_equal("bag")
	_press("ui_up")
	assert_str(screen.selected()).is_equal("exit")
	assert_int(_pressed(screen)).is_equal(2)
	_press("ui_down")
	_press("ui_down")
	assert_str(screen.selected()).is_equal("save")
	_press("ui_cancel")
	assert_bool(screen.is_closed()).is_true()
	screen = _world.menu.open() as WgMenuScreen
	assert_str(screen.selected()).is_equal("save")
	screen.close()
	_world.story.set_flag(&"save_disabled")
	screen = _world.menu.open() as WgMenuScreen
	assert_str(screen.selected()).is_equal("bag")


func test_an_entry_is_awaited_keys_waiting_then_it_closes_the_menu_or_stays() -> void:
	_world.menu.add_entry(&"wait", "Wait", func() -> bool:
		await entry_done
		_world.story.set_flag(&"save_disabled")
		return false, "", &"bag")
	_world.menu.add_entry(&"leave", "Leave", _mark.bind("leave", true), "", &"bag")
	var screen := _world.menu.open() as WgMenuScreen
	_press("ui_accept")
	_press("ui_cancel")
	assert_bool(screen.is_closed()).is_false()
	entry_done.emit()
	assert_bool(screen.is_closed()).is_false()
	assert_array(_labels(screen)).is_equal(["Wait", "Leave", "Bag", "Exit"])
	_press("ui_down")
	_press("ui_accept")
	assert_bool(screen.is_closed()).is_true()
	assert_array(_calls).is_equal(["leave"])


func test_bag_opens_above_and_comes_back_to_the_menu_and_exit_closes() -> void:
	var screen := _world.menu.open() as WgMenuScreen
	_press("ui_accept")
	assert_str(_world.screens.top().screen_name).is_equal("bag")
	assert_bool(screen.visible).is_false()
	_press("ui_cancel")
	assert_object(_world.screens.top()).is_same(screen)
	assert_bool(screen.visible).is_true()
	_press("ui_up")
	_press("ui_accept")
	assert_bool(screen.is_closed()).is_true()


func test_save_closes_the_menu_once_saved_only() -> void:
	var screen := _world.menu.open() as WgMenuScreen
	_press("ui_down")
	_press("ui_accept")
	await get_tree().process_frame
	_write()
	assert_bool(screen.visible).is_false()
	_press("ui_cancel")
	await get_tree().process_frame
	assert_object(_world.screens.top()).is_same(screen)
	assert_bool(screen.visible).is_true()
	assert_bool(screen.is_closed()).is_false()
	_press("ui_accept")
	await get_tree().process_frame
	_write()
	_press("ui_accept")
	_write()
	_world.dialogue.box.advance(2.0)
	assert_bool(_world.save.has(1)).is_true()
	assert_bool(screen.is_closed()).is_true()


func test_its_labels_follow_the_language() -> void:
	_world.sandbox.write("Data/Text/Dialogs/100014.csv", "en,fr\nPOKÉMON,Pokémon\nPOKÉDEX,Pokédex\nBAG,Sac\n")
	var screen := _world.menu.open() as WgMenuScreen
	assert_array(_labels(screen)).is_equal(["BAG", "Save", "Exit"])
	_world.texts.language = "fr"
	assert_array(_labels(screen)).is_equal(["Sac", "Save", "Exit"])


func test_opened_alone_the_screen_uses_the_engine_s_services() -> void:
	var engine := get_tree().root.get_node("Wildgrass")
	assert_str(engine.screens.scene_path(&"menu")).is_equal("res://addons/wildgrass/menu/menu_screen.tscn")
	var screen := engine.screens.open(&"menu") as WgMenuScreen
	assert_object(screen.menu).is_same(engine.menu)
	assert_object(screen.texts).is_same(engine.texts)
	screen.close()
