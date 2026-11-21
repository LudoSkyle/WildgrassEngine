extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")

var _world: World


func before_test() -> void:
	_world = World.new(self)


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_world.screens.handle_input(event)


func _box() -> WgMessageBox:
	var box := _world.dialogue.box
	box.set_process(false)
	return box


func _number() -> String:
	return (_box().get_node("Number/Value") as Label).text


func _gift(_value: String) -> void:
	pass


func test_a_message_holding_a_narrating_tag_shows_no_speaker() -> void:
	_world.dialogue.add_tag(&"gift", _gift, true)
	_world.dialogue.add_tag(&"mark", _gift)
	var talk := func() -> void:
		await _world.dialogue.say("Here you go.", {"speaker": "Alix"})
		await _world.dialogue.say("You got a Potion![gift=potion]", {"speaker": "Alix"})
		await _world.dialogue.say("Use it well.[mark=x]", {"speaker": "Alix"})
	talk.call()
	var speaker := _box().get_node("Speaker") as Control
	assert_bool(speaker.visible).is_true()
	_box().advance(10.0)
	_press("ui_accept")
	assert_bool(speaker.visible).is_false()
	_box().advance(10.0)
	_press("ui_accept")
	assert_bool(speaker.visible).is_true()


func test_a_message_s_own_values_fill_its_placeholders_and_may_hold_some() -> void:
	_world.sandbox.write("Data/Text/Dialogs/100012.csv", "en,fr\nThing,Chose\nPotion,Potion\n")
	_world.texts.set_value(&"item", "nothing")
	_world.dialogue.say("Found {item} x{count}!", {"values": {"item": "{text:100012:1}", "count": 3}})
	_box().advance(10.0)
	assert_str(_box().shown_text()).is_equal("Found Potion x3!")
	_press("ui_accept")
	_world.dialogue.say("Hi {item}, {who}!", {"values": {"who": "[wait]Bob"}})
	_box().advance(10.0)
	assert_str(_box().shown_text()).is_equal("Hi nothing, [wait]Bob!")


func test_a_locked_message_once_written_goes_on_only_by_itself() -> void:
	var done := [false]
	var say := func() -> void:
		await _world.dialogue.say("Got it!", {"locked": true, "auto": 1.0})
		done[0] = true
	say.call()
	_box().advance(10.0)
	_press("ui_accept")
	assert_bool(done[0]).is_false()
	_box().advance(0.9)
	assert_bool(done[0]).is_false()
	_box().advance(0.2)
	assert_bool(done[0]).is_true()


func test_a_number_is_asked_once_written_and_moves_round_its_range() -> void:
	var answer := [false]
	var ask := func() -> void: answer[0] = await _world.dialogue.ask_number("Toss how many?", {"min": 1, "max": 12, "default": 3})
	ask.call()
	_box().advance(0.01)
	assert_bool((_box().get_node("Number") as Control).visible).is_false()
	_box().advance(10.0)
	assert_bool((_box().get_node("Number") as Control).visible).is_true()
	assert_str(_number()).is_equal("3")
	_press("ui_up")
	assert_str(_number()).is_equal("4")
	_press("ui_right")
	assert_str(_number()).is_equal("2")
	_press("ui_down")
	_press("ui_down")
	assert_str(_number()).is_equal("12")
	_press("ui_left")
	assert_str(_number()).is_equal("2")
	_press("ui_accept")
	assert_int(answer[0]).is_equal(2)
	assert_bool((_box().get_node("Number") as Control).visible).is_false()


func test_a_number_cancelled_or_cut_short_gives_null() -> void:
	var answers: Array = []
	var ask := func() -> void: answers.append(await _world.dialogue.ask_number("How many?", {"max": 5}))
	ask.call()
	_box().advance(10.0)
	assert_str(_number()).is_equal("0")
	_press("ui_cancel")
	ask.call()
	_world.dialogue.close()
	assert_array(answers).is_equal([null, null])


func test_the_number_sits_against_the_frame_and_a_bad_range_is_logged() -> void:
	_world.dialogue.ask_number("How many?", {"min": 4, "max": 2})
	_box().advance(10.0)
	var frame := (_box().get_node("Frame") as Control).get_rect()
	var shown := (_box().get_node("Number") as Control).get_rect()
	assert_float(shown.end.x).is_equal(frame.end.x)
	assert_float(shown.end.y).is_equal(frame.position.y)
	assert_str(_number()).is_equal("4")
	assert_array(_world.logged).is_equal(["WARN max 2 is below min 4; using 4"])


func test_a_message_s_values_are_translated_as_labels() -> void:
	var french := Translation.new()
	french.locale = "fr"
	french.add_message("Bell", "Clochette")
	TranslationServer.add_translation(french)
	TranslationServer.set_locale("fr")
	_world.dialogue.say("{item}!", {"values": {"item": "Bell"}})
	_box().advance(10.0)
	assert_str(_box().shown_text()).is_equal("Clochette!")
	TranslationServer.remove_translation(french)
	TranslationServer.set_locale("en")
