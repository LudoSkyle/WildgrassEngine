extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")

var _world: World
var _results: Array[bool] = []


func before_test() -> void:
	_world = World.new(self)
	_results = []
	_world.map().zone = &"harbour"


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _open() -> WgSaveScreen:
	var screen := _world.screens.open(&"save", {"save": _world.save, "dialogue": _world.dialogue, "texts": _world.texts}) as WgSaveScreen
	screen.done.connect(func(saved: bool) -> void: _results.append(saved))
	await get_tree().process_frame
	_write()
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


func _text() -> String:
	return _world.dialogue.box.shown_text()


func _choices() -> Array[String]:
	var shown: Array[String] = []
	for child: Node in _world.dialogue.box.get_node("Choices").get_children():
		if (child as Button).visible:
			shown.append((child as Button).text)
	return shown


func test_yes_saves_and_the_saved_text_stays_its_time_then_the_screen_closes() -> void:
	_world.clock.advance(3725.0)
	var screen := await _open()
	assert_str((screen.get_node("Summary/Margin/Box/Place") as Label).text).is_equal("harbour")
	assert_str((screen.get_node("Summary/Margin/Box/Time") as Label).text).is_equal("1:02")
	assert_str(_text()).is_equal("Would you like to save the game?")
	assert_array(_choices()).is_equal(["Yes", "No"])
	_answer()
	assert_bool(_world.save.has(1)).is_true()
	assert_str(_text()).is_equal("The game was saved.")
	_press("ui_accept")
	_world.dialogue.box.advance(0.9)
	assert_bool(screen.is_closed()).is_false()
	_world.dialogue.box.advance(0.2)
	assert_bool(screen.is_closed()).is_true()
	assert_array(_results).is_equal([true])


func test_a_game_already_in_the_file_is_overwritten_only_on_yes() -> void:
	_world.save.write(1)
	var before := FileAccess.get_file_as_string(_world.save.path_of(1))
	_world.clock.advance(30.0)
	var screen := await _open()
	_answer()
	assert_str(_text()).is_equal("There is already a saved file. Is it OK to overwrite it?")
	_press("ui_down")
	_answer()
	assert_str(FileAccess.get_file_as_string(_world.save.path_of(1))).is_equal(before)
	assert_bool(screen.is_closed()).is_true()
	screen = await _open()
	_answer()
	_answer()
	assert_str(FileAccess.get_file_as_string(_world.save.path_of(1))).is_not_equal(before)
	assert_array(_results).is_equal([false])


func test_no_or_cancel_writes_nothing() -> void:
	var screen := await _open()
	_answer("ui_cancel")
	assert_bool(screen.is_closed()).is_true()
	assert_bool(_world.save.has(1)).is_false()
	assert_array(_results).is_equal([false])


func test_a_game_that_cannot_be_written_says_so_and_the_key_closes_it() -> void:
	_world.save.add_part(&"bad", func() -> Dictionary: return {"at": Vector2.ONE}, func(_state: Dictionary) -> void: pass, func() -> void: pass)
	var screen := await _open()
	_answer()
	assert_str(_text()).is_equal("The game could not be saved.")
	_press("ui_accept")
	assert_bool(screen.is_closed()).is_true()
	assert_array(_results).is_equal([false])


func test_when_any_file_may_be_written_the_player_picks_one() -> void:
	_world.sandbox.write_json("config/save.json", {"save_anywhere": true, "slots": 2})
	_world.save.write(1)
	var screen := await _open()
	assert_str(_text()).is_equal("Save in which file?")
	assert_array(_choices()).is_equal(["File 1: harbour, 0:00", "File 2: new", "Cancel"])
	_press("ui_down")
	_answer()
	_answer()
	assert_bool(_world.save.has(2)).is_true()
	assert_int(_world.save.slot).is_equal(2)
	_press("ui_accept")
	_world.dialogue.box.advance(2.0)
	assert_bool(screen.is_closed()).is_true()
	screen = await _open()
	var buttons := _world.dialogue.box.get_node("Choices").get_children()
	assert_int(buttons.find_custom(func(button: Button) -> bool: return button.button_pressed)).is_equal(1)
	_answer("ui_cancel")
	assert_bool(screen.is_closed()).is_true()
	assert_array(_results).is_equal([true, false])


func test_a_game_with_no_zone_is_shown_by_its_map() -> void:
	assert_that(WgSaveScreen.describe({"map": "town", "zone": "", "seconds": 7259.0})).is_equal({"place": "town", "time": "2:00"})
	assert_that(WgSaveScreen.describe({})).is_equal({"place": "", "time": "0:00"})


func test_opened_by_name_alone_it_uses_the_engine_s_services() -> void:
	var engine := get_tree().root.get_node("Wildgrass")
	assert_str(engine.screens.scene_path(&"save")).is_equal("res://addons/wildgrass/save/save_screen.tscn")
	var screen := engine.screens.open(&"save") as WgSaveScreen
	assert_object(screen.save).is_same(engine.save)
	assert_object(screen.dialogue).is_same(engine.dialogue)
	assert_object(screen.texts).is_same(engine.texts)
	screen.close()
	await get_tree().process_frame
	assert_bool(engine.dialogue.is_open()).is_false()
