extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const CustomSaveSlots := preload("res://tests/support/custom_save_slots.gd")

signal restored_late

var _world: World
var _chosen: Array[String] = []


func before_test() -> void:
	_world = World.new(self)
	_chosen = []
	_world.map().zone = &"harbour"


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _open() -> WgSaveSlotsScreen:
	var screen := _world.screens.open(&"save_slots", {"save": _world.save, "dialogue": _world.dialogue, "texts": _world.texts}) as WgSaveSlotsScreen
	screen.chosen.connect(func(slot: int, action: StringName) -> void: _chosen.append("%d %s" % [slot, action]))
	return screen


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_world.screens.handle_input(event)


func _write() -> void:
	if _world.dialogue.box != null:
		_world.dialogue.box.set_process(false)
		_world.dialogue.box.advance(10.0)


func _answer(action := "ui_accept") -> void:
	_press(action)
	_write()


func _choices() -> Array[String]:
	var shown: Array[String] = []
	for child: Node in _world.dialogue.box.get_node("Choices").get_children():
		if (child as Button).visible:
			shown.append((child as Button).text)
	return shown


func _cards(screen: WgSaveSlotsScreen) -> Array[String]:
	var shown: Array[String] = []
	for card: Node in screen.get_node("Cards/List").get_children():
		shown.append((card as Button).text)
	return shown


func _pressed(screen: WgSaveSlotsScreen) -> int:
	return screen.get_node("Cards/List").get_children().find_custom(func(card: Button) -> bool: return card.button_pressed)


func test_each_slot_shows_a_card_from_its_summary_the_game_s_selected() -> void:
	_world.sandbox.write_json("config/save.json", {"slots": 3})
	_world.hooks.add(&"save_summary", &"test", func(summary: Dictionary, _slot: int) -> Dictionary:
		summary["name"] = "Ludo"
		return summary)
	_world.clock.advance(3725.0)
	_world.save.write(2)
	_world.sandbox.write("saves/saves/game-3.json", "nope")
	var screen := _open()
	assert_array(_cards(screen)).is_equal(["File 1\nNew game", "File 2\nharbour   1:02", "File 3\nThis file is damaged."])
	assert_float(((screen.get_node("Panel") as Panel).get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color.a).is_equal(1.0)
	assert_int(screen.selected()).is_equal(2)
	assert_int(_pressed(screen)).is_equal(1)
	screen.card_text = "{name}, {place}"
	assert_str(screen.card_of(2)).is_equal("Ludo, harbour")
	_press("ui_down")
	_press("ui_down")
	assert_int(screen.selected()).is_equal(3)
	assert_int(_pressed(screen)).is_equal(2)
	_press("ui_up")
	_press("ui_up")
	_press("ui_up")
	assert_int(screen.selected()).is_equal(1)


func test_continue_plays_the_game_and_closes() -> void:
	_world.story.set_flag(&"bell_told")
	_world.save.write(1)
	_world.save.new_game(2)
	var screen := _open()
	assert_int(screen.selected()).is_equal(2)
	_press("ui_up")
	_answer()
	assert_str(_world.dialogue.box.shown_text()).is_equal("File 1\nharbour   0:00")
	assert_array(_choices()).is_equal(["Continue", "Erase", "Cancel"])
	_press("ui_accept")
	assert_bool(screen.is_closed()).is_true()
	await get_tree().process_frame
	assert_bool(_world.story.has(&"bell_told")).is_true()
	assert_array(_chosen).is_equal(["1 continue"])


func test_a_free_slot_starts_a_new_game() -> void:
	_world.save.write(1)
	_world.story.set_flag(&"old")
	var screen := _open()
	_press("ui_down")
	_answer()
	assert_array(_choices()).is_equal(["New game", "Cancel"])
	_press("ui_accept")
	assert_int(_world.save.slot).is_equal(2)
	assert_bool(_world.story.has(&"old")).is_false()
	assert_bool(screen.is_closed()).is_true()
	assert_array(_chosen).is_equal(["2 new_game"])


func test_erasing_asks_no_first_then_empties_the_card() -> void:
	_world.save.write(1)
	var screen := _open()
	_answer()
	_press("ui_down")
	_answer()
	assert_str(_world.dialogue.box.shown_text()).is_equal("Erase file 1?")
	_answer()
	assert_bool(_world.save.has(1)).is_true()
	await get_tree().process_frame
	_answer()
	_press("ui_down")
	_answer()
	_press("ui_up")
	_answer()
	assert_bool(_world.save.has(1)).is_false()
	assert_array(_cards(screen)).is_equal(["File 1\nNew game"])
	assert_bool(screen.is_closed()).is_false()
	assert_array(_chosen).is_equal(["1 erase"])


func test_a_damaged_file_may_only_be_erased_and_a_failed_load_says_so() -> void:
	_world.sandbox.write("saves/saves/game-1.json", "nope")
	_world.save.add_part(&"guard", func() -> Dictionary: return {}, func(_state: Dictionary) -> void: pass, func() -> void: pass,
		func(_state: Dictionary) -> bool: return false)
	_world.save.write(2)
	var screen := _open()
	_press("ui_up")
	_answer()
	assert_array(_choices()).is_equal(["Erase", "Cancel"])
	_answer("ui_cancel")
	await get_tree().process_frame
	_press("ui_down")
	_answer()
	_answer()
	assert_str(_world.dialogue.box.shown_text()).is_equal("This file could not be loaded.")
	_press("ui_accept")
	await get_tree().process_frame
	assert_bool(screen.is_closed()).is_false()
	_press("ui_cancel")
	assert_bool(screen.is_closed()).is_true()
	assert_array(_chosen).is_equal(["0 cancel"])


func test_keys_wait_while_a_game_loads() -> void:
	_world.save.add_part(&"late", func() -> Dictionary: return {}, func(_state: Dictionary) -> void:
		await restored_late, func() -> void: pass)
	_world.save.write(1)
	var screen := _open()
	_answer()
	_press("ui_accept")
	await get_tree().process_frame
	_press("ui_cancel")
	assert_bool(screen.is_closed()).is_false()
	restored_late.emit()
	assert_bool(screen.is_closed()).is_true()
	assert_array(_chosen).is_equal(["1 continue"])


func test_a_row_moves_left_and_right_and_may_go_round() -> void:
	_world.sandbox.write_json("config/save.json", {"slots": 3})
	var screen := _open()
	screen.horizontal = true
	_press("ui_down")
	assert_int(screen.selected()).is_equal(1)
	_press("ui_right")
	_press("ui_right")
	_press("ui_right")
	assert_int(screen.selected()).is_equal(3)
	_press("ui_left")
	assert_int(screen.selected()).is_equal(2)
	screen.wrap = true
	_press("ui_right")
	_press("ui_right")
	assert_int(screen.selected()).is_equal(1)
	_press("ui_left")
	assert_int(screen.selected()).is_equal(3)


func test_one_new_game_card_for_the_first_free_slot_after_the_games() -> void:
	_world.sandbox.write_json("config/save.json", {"slots": 3})
	_world.save.write(3)
	var screen := _open()
	screen.new_game_card = "first_free"
	screen.refresh()
	assert_array(screen.slots).is_equal([3, 1])
	assert_array(_cards(screen)).is_equal(["File 3\nharbour   0:00", "File 1\nNew game"])
	_world.save.write(1)
	_world.save.write(2)
	screen.refresh()
	assert_array(screen.slots).is_equal([1, 2, 3])


func test_with_no_maximum_the_new_game_card_is_the_next_slot() -> void:
	_world.save.write(1)
	_world.save.write(2)
	var screen := _open()
	screen.new_game_card = "first_free"
	screen.refresh()
	assert_array(screen.slots).is_equal([1, 2, 3])


func test_an_options_card_comes_last_and_writes_the_cards_again_once_back() -> void:
	var translation := Translation.new()
	translation.locale = "fr"
	translation.add_message("wg.slots.options", "Réglages")
	TranslationServer.add_translation(translation)
	_world.texts.language = "en"
	var screen := _open()
	screen.options_card = true
	screen.refresh()
	assert_array(screen.slots).is_equal([1])
	screen.close()
	var opened: Array[String] = []
	screen = _world.screens.open(&"save_slots", {"save": _world.save, "dialogue": _world.dialogue, "texts": _world.texts, "open_options": func() -> void:
		opened.append("options")
		_world.texts.language = "fr"}) as WgSaveSlotsScreen
	screen.options_card = true
	screen.refresh()
	assert_array(screen.slots).is_equal([1, WgSaveSlotsScreen.OPTIONS_CARD])
	assert_array(_cards(screen)).is_equal(["File 1\nNew game", "Options"])
	_press("ui_down")
	assert_int(screen.selected()).is_equal(WgSaveSlotsScreen.OPTIONS_CARD)
	_press("ui_accept")
	await get_tree().process_frame
	assert_array(opened).is_equal(["options"])
	assert_array(_cards(screen)).is_equal(["File 1\nNew game", "Réglages"])
	assert_bool(screen.is_closed()).is_false()
	TranslationServer.remove_translation(translation)
	TranslationServer.set_locale("en")


func test_a_game_s_scene_makes_its_cards_and_asks_its_own_questions() -> void:
	_world.sandbox.write_json("config/save.json", {"slots": 3})
	_world.save.write(2)
	_world.sandbox.write("saves/saves/game-3.json", "nope")
	_world.screens.set_scene(&"save_slots", _world.sandbox.scene("slots.tscn", CustomSaveSlots))
	var screen := _open() as CustomSaveSlots
	assert_array(screen.made).is_equal(["1 []", "2 [\"seconds\", \"map\", \"zone\"]", "3 [\"damaged\"]"])
	assert_array(screen.selections.slice(-1)).is_equal(["Card2"])
	_press("ui_accept")
	screen.erase = true
	screen.action = &"erase"
	_press("ui_accept")
	assert_array(screen.asked).is_equal(["action 2", "action 2", "erase 2"])
	assert_bool(_world.save.has(2)).is_false()
	_press("ui_up")
	_press("ui_accept")
	assert_array(screen.asked.slice(-1)).is_equal(["new 1"])
	assert_array(_chosen).is_equal(["2 erase", "1 new_game"])


func test_opened_by_name_alone_it_uses_the_engine_s_services() -> void:
	var engine := get_tree().root.get_node("Wildgrass")
	assert_str(engine.screens.scene_path(&"save_slots")).is_equal("res://addons/wildgrass/save/save_slots_screen.tscn")
	var screen := engine.screens.open(&"save_slots") as WgSaveSlotsScreen
	assert_object(screen.save).is_same(engine.save)
	assert_object(screen.dialogue).is_same(engine.dialogue)
	assert_object(screen.texts).is_same(engine.texts)
	screen.close()
