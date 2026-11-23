extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const EngineWords := preload("res://tests/support/engine_words.gd")

var _world: World


func before_test() -> void:
	_world = World.new(self)


func after_test() -> void:
	EngineWords.reset()
	_world.root.free()
	_world.cleanup()


## Starts asking; the returned array holds the answer once `ask()` returned.
func _ask(text: String, choices: Array, options := {}) -> Array:
	var answer := [null]
	_await_ask(text, choices, options, answer)
	if _world.dialogue.box != null:
		_world.dialogue.box.set_process(false)
	return answer


func _await_ask(text: String, choices: Array, options: Dictionary, answer: Array) -> void:
	answer[0] = await _world.dialogue.ask(text, choices, options)


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_world.screens.handle_input(event)


func _choices() -> Control:
	return _world.dialogue.box.get_node("Choices") as Control


func _buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child: Node in _choices().get_children():
		buttons.append(child as Button)
	return buttons


func _selected() -> int:
	return _buttons().find_custom(func(button: Button) -> bool: return button.button_pressed)


func _shown() -> Array[String]:
	var texts: Array[String] = []
	for button in _buttons():
		if button.visible:
			texts.append(button.text)
	return texts


func test_choices_appear_once_the_question_is_written_with_the_default_selected() -> void:
	var french := Translation.new()
	french.locale = TranslationServer.get_locale()
	french.add_message("Apple", "Pomme")
	TranslationServer.add_translation(french)
	var answer := _ask("Which one would you like to take with you?", ["Apple", "Pear", "Plum"], {"default": 1})
	_world.dialogue.box.advance(0.1)
	assert_bool(_choices().visible).is_false()
	_press("ui_accept")
	assert_that(answer[0]).is_null()
	assert_bool(_choices().visible).is_true()
	assert_array(_shown()).is_equal(["Pomme", "Pear", "Plum"])
	assert_int(_selected()).is_equal(1)


func test_up_and_down_move_round_and_confirm_takes_the_choice() -> void:
	var moved: Array[int] = []
	var made: Array[int] = []
	_world.dialogue.choice_moved.connect(func(index: int) -> void: moved.append(index))
	_world.dialogue.choice_made.connect(func(index: int) -> void: made.append(index))
	var answer := _ask("Pick?", ["A", "B", "C"])
	_world.dialogue.box.advance(1.0)
	_press("ui_up")
	_press("ui_down")
	_press("ui_down")
	assert_int(_selected()).is_equal(1)
	assert_array(moved).is_equal([2, 0, 1])
	_press("ui_accept")
	assert_int(answer[0]).is_equal(1)
	assert_array(made).is_equal([1])
	assert_bool(_choices().visible).is_false()


func test_cancel_answers_the_last_choice_unless_told_otherwise() -> void:
	var last := _ask("Pick?", ["A", "B", "C"])
	_world.dialogue.box.advance(1.0)
	_press("ui_cancel")
	assert_int(last[0]).is_equal(2)
	var first := _ask("Pick?", ["A", "B", "C"], {"cancel": 0})
	_world.dialogue.box.advance(1.0)
	_press("ui_cancel")
	assert_int(first[0]).is_equal(0)
	var none := _ask("Pick?", ["A", "B", "C"], {"cancel": -1})
	_world.dialogue.box.advance(1.0)
	_press("ui_cancel")
	assert_that(none[0]).is_null()
	assert_bool(_choices().visible).is_true()


func test_confirm_answers_true_for_yes_and_cancel_is_no() -> void:
	var answers: Array[bool] = []
	var both := func() -> void:
		answers.append(await _world.dialogue.confirm("Save?", {"cancel": 0}))
		answers.append(await _world.dialogue.confirm("Quit?"))
	both.call()
	_world.dialogue.box.set_process(false)
	_world.dialogue.box.advance(1.0)
	assert_array(_shown()).is_equal(["Yes", "No"])
	_press("ui_cancel")
	_world.dialogue.box.advance(1.0)
	_press("ui_accept")
	assert_array(answers).is_equal([false, true])


func test_a_disabled_choice_is_shown_but_never_taken() -> void:
	var refused: Array[int] = []
	_world.dialogue.choice_refused.connect(func(index: int) -> void: refused.append(index))
	var answer := _ask("Buy?", ["Potion", {"text": "Ball", "disabled": true}])
	_world.dialogue.box.advance(1.0)
	assert_bool(_buttons()[1].disabled).is_true()
	_press("ui_down")
	_press("ui_accept")
	assert_that(answer[0]).is_null()
	assert_array(refused).is_equal([1])
	assert_int(_selected()).is_equal(1)


func test_the_mouse_takes_a_choice() -> void:
	var answer := _ask("Pick?", ["A", "B"])
	_world.dialogue.box.advance(1.0)
	_buttons()[1].pressed.emit()
	assert_int(answer[0]).is_equal(1)


func test_only_the_actions_of_the_config_move_the_selection() -> void:
	_world.sandbox.write_json("config/dialogue.json", {"actions": {"down": "ui_page_down"}})
	_ask("Pick?", ["A", "B"])
	_world.dialogue.box.advance(1.0)
	assert_int(_buttons()[0].focus_mode).is_equal(Control.FOCUS_NONE)
	_press("ui_down")
	assert_int(_selected()).is_equal(0)
	_press("ui_page_down")
	assert_int(_selected()).is_equal(1)


func test_a_long_list_scrolls_keeping_the_selection_in_view() -> void:
	_world.sandbox.write_json("config/dialogue.json", {"max_choices": 3})
	_ask("Pick?", ["A", "B", "C", "D", "E"])
	_world.dialogue.box.advance(1.0)
	assert_array(_shown()).is_equal(["A", "B", "C"])
	for press in 3:
		_press("ui_down")
	assert_array(_shown()).is_equal(["B", "C", "D"])
	for press in 4:
		_press("ui_down")
	assert_int(_selected()).is_equal(2)
	assert_array(_shown()).is_equal(["A", "B", "C"])
	_press("ui_up")
	_press("ui_up")
	_press("ui_up")
	assert_int(_selected()).is_equal(4)
	assert_array(_shown()).is_equal(["C", "D", "E"])


func test_choices_never_leave_the_screen() -> void:
	var names: Array[String] = []
	for index in 10:
		names.append("Choice %d" % index)
	for place: String in ["bottom", "top"]:
		_ask("Pick?", names, {"place": place})
		_world.dialogue.box.advance(1.0)
		var choices := _choices().get_rect()
		assert_float(choices.position.y).is_greater_equal(0.0)
		assert_float(choices.end.y).is_less_equal(240.0)
		assert_int(_shown().size()).is_between(1, 5)
		_world.dialogue.close()


func test_choices_sit_against_the_frame_right_edge_on_its_outer_side() -> void:
	for place: String in ["bottom", "top"]:
		_ask("Pick?", ["A", "B"], {"place": place})
		_world.dialogue.box.advance(1.0)
		var frame := (_world.dialogue.box.get_node("Frame") as Control).get_rect()
		var choices := _choices().get_rect()
		assert_float(choices.end.x).is_equal(frame.end.x)
		if place == "top":
			assert_float(choices.position.y).is_equal(frame.end.y)
		else:
			assert_float(choices.end.y).is_equal(frame.position.y)
		_world.dialogue.close()


func test_a_question_cut_short_answers_its_cancel() -> void:
	var last := _ask("Pick?", ["A", "B", "C"])
	var none := _ask("Pick?", ["A", "B"], {"cancel": -1})
	_world.dialogue.close()
	assert_int(last[0]).is_equal(2)
	assert_int(none[0]).is_equal(-1)


func test_a_question_whose_box_cannot_open_answers_its_cancel() -> void:
	var answer := _ask("Pick?", ["A", "B"], {"screen": &"nowhere"})
	assert_int(answer[0]).is_equal(1)
	assert_array(_world.logged).is_equal(["ERROR unknown screen 'nowhere'"])


func test_wrong_questions_are_logged() -> void:
	var empty := _ask("Pick?", [])
	assert_int(empty[0]).is_equal(-1)
	_ask("Pick?", ["A", "B"], {"default": 5, "cancel": 7})
	_world.dialogue.box.advance(1.0)
	assert_int(_selected()).is_equal(0)
	assert_array(_world.logged).is_equal([
		"ERROR a question needs choices: \"Pick?\"",
		"WARN default 5 is not a choice; using 0",
		"WARN cancel 7 is not a choice; using 1",
	])


## A game's box: its choices in a frame (a column inside a panel), and a
## cursor pointing at the selected one.
func _framed_box() -> void:
	var box := (load("res://addons/wildgrass/dialogue/message_box.tscn") as PackedScene).instantiate()
	var column := box.get_node("Choices")
	box.remove_child(column)
	var frame := PanelContainer.new()
	frame.name = "Framed"
	box.add_child(frame)
	frame.add_child(column)
	var cursor := ColorRect.new()
	cursor.name = "Cursor"
	cursor.size = Vector2(6, 10)
	box.add_child(cursor)
	box.set(&"choices", ^"Framed")
	box.set(&"choice_cursor", ^"Cursor")
	for node: Node in [frame, column, column.get_child(0), cursor]:
		node.owner = box
	var packed := PackedScene.new()
	packed.pack(box)
	box.free()
	var path := _world.sandbox.root + "framed_box.tscn"
	ResourceSaver.save(packed, path)
	_world.screens.set_scene(&"message_box", path)


func test_a_game_s_box_frames_its_choices_and_points_at_the_selected_one() -> void:
	_framed_box()
	var answer := _ask("Which one?", ["Apple", "Pear", "Plum"], {"default": 1})
	_press("ui_accept")
	var box := _world.dialogue.box
	var frame := box.get_node("Framed") as Control
	var column := box.get_node("Framed/Choices") as Control
	var cursor := box.get_node("Cursor") as Control
	assert_bool(frame.visible).is_true()
	assert_int(column.get_child_count()).is_equal(3)
	await get_tree().process_frame
	var pear := column.get_child(1) as Button
	assert_bool(cursor.visible).is_true()
	assert_float(cursor.get_global_rect().end.x).is_equal_approx(pear.get_global_rect().position.x, 0.01)
	assert_float(cursor.get_global_rect().get_center().y).is_equal_approx(pear.get_global_rect().get_center().y, 0.01)
	_press("ui_down")
	await get_tree().process_frame
	var plum := column.get_child(2) as Button
	assert_float(cursor.get_global_rect().get_center().y).is_equal_approx(plum.get_global_rect().get_center().y, 0.01)
	_press("ui_accept")
	assert_that(answer[0]).is_equal(2)
	assert_bool(frame.visible).is_false()
	assert_bool(cursor.visible).is_false()
