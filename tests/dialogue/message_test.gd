extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const MapBuilder := preload("res://tests/support/map_builder.gd")

signal jingle_done

var _world: World
var _calls: Array[String] = []


func before_test() -> void:
	_world = World.new(self)
	_calls = []


func after_test() -> void:
	TranslationServer.clear()
	_world.root.free()
	_world.cleanup()


## Starts saying `text`; the returned array holds true once `say()` returned.
func _say(text: String, options := {}) -> Array:
	var done := [false]
	_await_say(text, options, done)
	if _world.dialogue.box != null:
		_world.dialogue.box.set_process(false)
	return done


func _await_say(text: String, options: Dictionary, done: Array) -> void:
	await _world.dialogue.say(text, options)
	done[0] = true


func _box() -> WgMessageBox:
	return _world.dialogue.box


func _shown() -> String:
	return _box().shown_text()


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_world.screens.handle_input(event)


func _config(values: Dictionary) -> void:
	_world.sandbox.write_json("config/dialogue.json", values)


func _record(value: String, tag_name: String) -> void:
	_calls.append("%s %s" % [tag_name, value])


func test_text_is_written_letter_by_letter_then_the_key_shows_it_all_then_ends_it() -> void:
	var finished := [0]
	_world.dialogue.message_finished.connect(func() -> void: finished[0] += 1)
	var done := _say("Hello there")
	_box().advance(0.1)
	assert_str(_shown()).is_equal("Hello")
	_press("ui_accept")
	assert_str(_shown()).is_equal("Hello there")
	assert_bool(done[0]).is_false()
	_press("ui_accept")
	assert_bool(done[0]).is_true()
	assert_int(finished[0]).is_equal(1)


func test_the_box_stays_open_between_messages_and_closes_at_the_end_of_the_frame() -> void:
	var events: Array[String] = []
	_world.dialogue.opened.connect(func() -> void: events.append("opened"))
	_world.dialogue.closed.connect(func() -> void: events.append("closed"))
	var done := [false]
	var both := func() -> void:
		await _world.dialogue.say("First")
		await _world.dialogue.say("Second")
		done[0] = true
	both.call()
	var box := _box()
	box.set_process(false)
	_press("ui_accept")
	_press("ui_accept")
	assert_object(_box()).is_same(box)
	box.advance(1.0)
	assert_str(_shown()).is_equal("Second")
	_press("ui_accept")
	assert_bool(done[0]).is_true()
	assert_bool(_world.dialogue.is_open()).is_true()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(_world.dialogue.is_open()).is_false()
	assert_array(events).is_equal(["opened", "closed"])


func test_a_long_message_is_read_page_by_page_on_a_cleared_box() -> void:
	var pages := [0]
	_world.dialogue.page_shown.connect(func() -> void: pages[0] += 1)
	var done := _say("one\ntwo\nthree\nfour\nfive")
	var waiting := _box().get_node("Waiting") as CanvasItem
	_box().advance(10.0)
	assert_str(_shown()).is_equal("one\ntwo")
	assert_bool(waiting.visible).is_true()
	_press("ui_accept")
	assert_bool(waiting.visible).is_false()
	_box().advance(10.0)
	assert_str(_shown()).is_equal("three\nfour")
	_press("ui_accept")
	_box().advance(10.0)
	assert_str(_shown()).is_equal("five")
	# The last page shows from its own line, however short it is.
	var label := _box().get_node("Frame/Margin/Text") as RichTextLabel
	assert_float(label.get_v_scroll_bar().value).is_equal(label.get_line_offset(4))
	assert_int(pages[0]).is_equal(3)
	_press("ui_accept")
	assert_bool(done[0]).is_true()


func test_pages_break_where_the_text_wraps_and_hold_what_the_box_shows() -> void:
	var text := "The quick brown fox jumps over the lazy dog while the sleepy cat watches from the old wooden fence near the river bank."
	_say(text)
	var label := _box().get_node("Frame/Margin/Text") as RichTextLabel
	var read: Array[String] = []
	for page in 10:
		_box().advance(10.0)
		assert_int(_box()._bottom - _box()._top).is_less_equal(1)
		read.append(_shown().replace("\n", " "))
		if _box().state != WgMessageBox.State.PAGE_WRITTEN:
			break
		_press("ui_accept")
	assert_int(read.size()).is_greater(1)
	assert_bool(label.get_v_scroll_bar().visible).is_false()
	assert_str(" ".join(read)).is_equal(text)
	assert_float(label.get_v_scroll_bar().page).is_greater_equal(2.0 * label.get_line_height(0))


func test_a_page_tag_starts_a_new_page() -> void:
	_say("Hi.[page]Next.")
	_box().advance(10.0)
	assert_str(_shown()).is_equal("Hi.")
	_press("ui_accept")
	_box().advance(10.0)
	assert_str(_shown()).is_equal("Next.")


func test_in_scroll_mode_lines_slide_up_one_by_one() -> void:
	_config({"advance": "scroll", "scroll_speed": 46})
	_say("one\ntwo\nthree\nfour")
	var bar := (_box().get_node("Frame/Margin/Text") as RichTextLabel).get_v_scroll_bar()
	var line := (_box().get_node("Frame/Margin/Text") as RichTextLabel).get_line_height(0)
	_box().advance(10.0)
	_press("ui_accept")
	_box().advance(line / 92.0)
	assert_float(bar.value).is_equal_approx(line / 2.0, 0.5)
	assert_str(_shown()).is_equal("one\ntwo")
	_box().advance(line / 92.0)
	_box().advance(10.0)
	assert_str(_shown()).is_equal("two\nthree")
	_press("ui_accept")
	_box().advance(1.0)
	_box().advance(10.0)
	assert_str(_shown()).is_equal("three\nfour")


func test_a_page_tag_clears_the_box_in_scroll_mode_too() -> void:
	_config({"advance": "scroll"})
	_say("one[page]two")
	_box().advance(10.0)
	_press("ui_accept")
	assert_int(_box().state).is_equal(WgMessageBox.State.WRITING)
	_box().advance(10.0)
	assert_str(_shown()).is_equal("two")


func test_pause_stops_writing_for_its_seconds() -> void:
	_config({"letters_per_second": 10})
	_say("ab[pause=0.5]cd")
	_box().advance(0.25)
	assert_str(_shown()).is_equal("ab")
	_box().advance(0.4)
	assert_str(_shown()).is_equal("ab")
	_box().advance(0.1)
	assert_str(_shown()).is_equal("ab")
	_box().advance(0.05)
	assert_str(_shown()).is_equal("abc")


func test_speed_changes_the_pace_and_alone_brings_it_back() -> void:
	_config({"letters_per_second": 10})
	_say("ab[speed=2]cdef[speed]gh")
	_box().advance(0.3)
	assert_str(_shown()).is_equal("abcd")
	_box().advance(0.1)
	assert_str(_shown()).is_equal("abcdef")
	_box().advance(0.1)
	assert_str(_shown()).is_equal("abcdefg")


func test_wait_stops_writing_until_the_key() -> void:
	_say("ab[wait]cd")
	_box().advance(10.0)
	assert_str(_shown()).is_equal("ab")
	assert_bool((_box().get_node("Waiting") as CanvasItem).visible).is_true()
	_box().advance(10.0)
	assert_str(_shown()).is_equal("ab")
	_press("ui_accept")
	_box().advance(10.0)
	assert_str(_shown()).is_equal("abcd")


func test_every_tag_runs_once_in_order_however_the_text_is_shown() -> void:
	_world.dialogue.add_tag(&"gift", _record.bind("gift"))
	_world.dialogue.add_tag(&"mark", _record.bind("mark"))
	_say("a[gift=potion*3]b[pause=5]c[mark=x]d[wait]e[gift=ball]")
	_press("ui_accept")
	assert_str(_shown()).is_equal("abcd")
	assert_array(_calls).is_equal(["gift potion*3", "mark x"])
	_press("ui_accept")
	_press("ui_accept")
	assert_str(_shown()).is_equal("abcde")
	_box().advance(10.0)
	assert_array(_calls).is_equal(["gift potion*3", "mark x", "gift ball"])


func test_a_tag_returning_a_signal_holds_writing_and_the_key_does_nothing() -> void:
	_world.dialogue.add_tag(&"fanfare", func(_value: String) -> Signal: return jingle_done)
	_say("a[fanfare]b")
	_box().advance(10.0)
	assert_str(_shown()).is_equal("a")
	_press("ui_accept")
	_box().advance(10.0)
	assert_str(_shown()).is_equal("a")
	jingle_done.emit()
	_box().advance(10.0)
	assert_str(_shown()).is_equal("ab")


func test_a_pace_of_zero_writes_at_once_up_to_wait() -> void:
	_world.dialogue.letters_per_second = 0.0
	_say("ab[pause=1]c[wait]d")
	assert_str(_shown()).is_equal("abc")
	_press("ui_accept")
	assert_str(_shown()).is_equal("abcd")


func test_a_game_cannot_take_a_bbcode_or_engine_tag_or_one_taken() -> void:
	assert_bool(_world.dialogue.add_tag(&"color", _record.bind("color"))).is_false()
	assert_bool(_world.dialogue.add_tag(&"pause", _record.bind("pause"))).is_false()
	assert_bool(_world.dialogue.add_tag(&"gift", _record.bind("gift"))).is_true()
	assert_bool(_world.dialogue.add_tag(&"gift", _record.bind("gift"))).is_false()
	assert_array(_world.logged).is_equal([
		"ERROR cannot add the tag [color]: taken",
		"ERROR cannot add the tag [pause]: taken",
		"ERROR cannot add the tag [gift]: taken",
	])


func test_an_unknown_tag_is_shown_and_logged_and_bbcode_works() -> void:
	_say("a[nope]b [color=red]c[/color]")
	_box().advance(10.0)
	assert_str(_shown()).is_equal("a[nope]b c")
	assert_array(_world.logged).is_equal(["WARN unknown tag [nope] in \"a[nope]b [color=red]c[/color]\""])


func test_a_message_goes_through_tr_then_the_hook_which_may_change_options() -> void:
	var french := Translation.new()
	french.locale = TranslationServer.get_locale()
	french.add_message("Hello NAME", "Salut NAME")
	TranslationServer.add_translation(french)
	_world.hooks.add(&"message_text", &"names", func(text: String, options: Dictionary) -> String:
		options["speaker"] = "Bob"
		return text.replace("NAME", _world.dialogue.escape("[page]Bob")))
	_say("Hello NAME")
	_box().advance(10.0)
	assert_str(_shown()).is_equal("Salut [page]Bob")
	assert_int(_box().state).is_equal(WgMessageBox.State.WRITTEN)
	assert_str((_box().get_node("Speaker/Name") as Label).text).is_equal("Bob")


func test_messages_speakers_and_choices_are_formatted_when_shown() -> void:
	_world.texts.set_value(&"rival", "[wait]Blue")
	var answer := [null]
	var talk := func() -> void:
		await _world.dialogue.say("Hi, {rival}!", {"speaker": "{rival}"})
		answer[0] = await _world.dialogue.ask("Battle {rival}?", ["{rival}!", "No"])
	talk.call()
	_box().set_process(false)
	_box().advance(10.0)
	assert_str(_shown()).is_equal("Hi, [wait]Blue!")
	assert_str((_box().get_node("Speaker/Name") as Label).text).is_equal("[wait]Blue")
	_world.texts.set_value(&"rival", "Gary")
	_press("ui_accept")
	_box().advance(10.0)
	assert_str(_shown()).is_equal("Battle Gary?")
	assert_str((_box().get_node("Choices").get_child(0) as Button).text).is_equal("Gary!")


func test_the_speaker_shows_with_its_colour_and_hides_without() -> void:
	var name_label: Label
	var both := func() -> void:
		await _world.dialogue.say("Hi.", {"speaker": "Alix", "speaker_color": Color.RED})
		await _world.dialogue.say("Bye.")
	both.call()
	_box().set_process(false)
	var speaker := _box().get_node("Speaker") as Control
	name_label = _box().get_node("Speaker/Name") as Label
	assert_bool(speaker.visible).is_true()
	assert_str(name_label.text).is_equal("Alix")
	assert_that(name_label.get_theme_color(&"font_color")).is_equal(Color.RED)
	_press("ui_accept")
	_press("ui_accept")
	assert_bool(speaker.visible).is_false()
	assert_bool(name_label.has_theme_color_override(&"font_color")).is_false()
	assert_bool((_box().get_node("Portrait") as CanvasItem).visible).is_false()


func test_a_portrait_shows_beside_the_box() -> void:
	var texture := ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	_say("Hi.", {"portrait": texture})
	var portrait := _box().get_node("Portrait") as TextureRect
	assert_bool(portrait.visible).is_true()
	assert_object(portrait.texture).is_same(texture)
	assert_float(portrait.get_rect().end.y).is_equal((_box().get_node("Frame") as Control).get_rect().position.y)


func test_style_sets_the_frame_variation_and_defaults_to_the_dialogue_style() -> void:
	var frame: PanelContainer
	_say("Sign.", {"style": "sign"})
	frame = _box().get_node("Frame") as PanelContainer
	assert_str(frame.theme_type_variation).is_equal("MessageFrame_sign")
	_world.dialogue.style = "dark"
	_press("ui_accept")
	_press("ui_accept")
	_say("Plain.")
	assert_str(frame.theme_type_variation).is_equal("MessageFrame_dark")


func test_place_moves_the_box_and_the_speaker_keeps_to_its_outer_side() -> void:
	for place: String in ["bottom", "top", "middle"]:
		_say("Hi.", {"place": place, "speaker": "Alix"})
		var frame := (_box().get_node("Frame") as Control).get_rect()
		var speaker := (_box().get_node("Speaker") as Control).get_rect()
		match place:
			"bottom":
				assert_float(frame.end.y).is_equal(236.0)
				assert_float(speaker.end.y).is_equal(frame.position.y)
			"top":
				assert_float(frame.position.y).is_equal(4.0)
				assert_float(speaker.position.y).is_equal(frame.end.y)
			"middle":
				assert_float(frame.get_center().y).is_equal(120.0)
		_world.dialogue.close()


func test_a_game_box_names_its_own_nodes_and_may_keep_its_layout() -> void:
	var box := WgMessageBox.new()
	box.frame = ^"Window"
	box.text = ^"Window/Body"
	box.arrange = false
	var window := Panel.new()
	window.name = "Window"
	window.position = Vector2(10, 10)
	window.size = Vector2(200, 60)
	box.add_child(window)
	var body := RichTextLabel.new()
	body.name = "Body"
	body.size = Vector2(200, 60)
	window.add_child(body)
	window.owner = box
	body.owner = box
	var packed := PackedScene.new()
	packed.pack(box)
	box.free()
	var path := _world.sandbox.root + "game_box.tscn"
	ResourceSaver.save(packed, path)
	_world.screens.set_scene(&"message_box", path)
	_say("Hi there.")
	_box().advance(10.0)
	assert_str(_shown()).is_equal("Hi there.")
	assert_that((_box().get_node("Window") as Control).position).is_equal(Vector2(10, 10))


func test_auto_goes_on_without_the_key() -> void:
	var done := _say("Hi.", {"auto": 1.0})
	_box().advance(10.0)
	_box().advance(0.9)
	assert_bool(done[0]).is_false()
	assert_bool((_box().get_node("Waiting") as CanvasItem).visible).is_false()
	_box().advance(0.2)
	assert_bool(done[0]).is_true()


func test_hold_returns_once_written_and_keeps_the_box_until_the_next_message() -> void:
	var done := _say("Saving...", {"hold": true})
	var box := _box()
	assert_bool(done[0]).is_false()
	box.advance(10.0)
	assert_bool(done[0]).is_true()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(_world.dialogue.is_open()).is_true()
	_say("Saved.")
	assert_object(_box()).is_same(box)
	box.advance(10.0)
	assert_str(_shown()).is_equal("Saved.")
	_world.dialogue.close()
	assert_bool(_world.dialogue.is_open()).is_false()


func test_walk_away_ends_the_message_on_another_direction() -> void:
	var player := WgWalker.new()
	player.facing = Vector2i.UP
	_world.maps.traveller = player
	var done := _say("A sign.", {"walk_away": true})
	_press("ui_up")
	assert_bool(done[0]).is_false()
	_press("ui_down")
	assert_bool(done[0]).is_true()
	player.free()


func test_another_screen_can_show_a_message() -> void:
	_world.screens.register(&"battle_message", "res://addons/wildgrass/dialogue/message_box.tscn")
	_say("A wild Pokémon appeared!", {"screen": &"battle_message"})
	assert_str(_box().screen_name).is_equal("battle_message")


func test_close_freeing_the_box_or_a_map_change_end_pending_messages() -> void:
	var first := _say("One.")
	var second := _say("Two.")
	_world.dialogue.close()
	assert_bool(first[0] and second[0]).is_true()
	var freed := _say("Three.")
	_box().free()
	assert_bool(freed[0]).is_true()
	var build := MapBuilder.new(_world.sandbox)
	var town := build.map(&"town")
	MapBuilder.spawn(town, "Spawn", Vector2(8, 8))
	build.save("town", town)
	var warped := _say("Four.")
	await _world.maps.go_to(&"town", &"Spawn")
	assert_bool(warped[0]).is_true()
	assert_bool(_world.dialogue.is_open()).is_false()


func test_crossing_a_seam_keeps_the_box() -> void:
	var build := MapBuilder.new(_world.sandbox)
	var route := build.map(&"route")
	route.size = Vector2i(10, 8)
	MapBuilder.spawn(route, "Spawn", Vector2(32, 112))
	MapBuilder.link(route, WgMapLink.Side.SOUTH, &"island", 0)
	build.save("route", route)
	var island := build.map(&"island")
	island.size = Vector2i(10, 6)
	MapBuilder.link(island, WgMapLink.Side.NORTH, &"route", 0)
	build.save("island", island)
	var traveller := Node2D.new()
	_world.maps.traveller = traveller
	await _world.maps.go_to(&"route", &"Spawn")
	var done := _say("Watch your step.")
	traveller.global_position = Vector2(32, 136)
	assert_bool(_world.maps.cross()).is_true()
	assert_bool(_world.dialogue.is_open()).is_true()
	assert_bool(done[0]).is_false()


func test_a_click_on_the_box_confirms() -> void:
	var done := _say("Hi.")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var frame := _box().get_node("Frame") as Control
	frame.gui_input.emit(click)
	frame.gui_input.emit(click)
	assert_bool(done[0]).is_true()


func test_unknown_options_and_places_are_logged() -> void:
	_say("Hi.", {"colour": Color.RED, "place": "left"})
	assert_array(_world.logged).is_equal(["WARN unknown message option 'colour'", "WARN unknown place 'left'; using bottom"])
	assert_float((_box().get_node("Frame") as Control).get_rect().end.y).is_equal(236.0)


func test_config_errors_are_logged_and_reset() -> void:
	_config({"letters_per_second": -1, "scroll_speed": 0, "max_choices": 0, "advance": "slide", "actions": {"jump": "x"}})
	var config := _world.dialogue.config()
	assert_float(config.letters_per_second).is_equal(50.0)
	assert_float(config.scroll_speed).is_equal(60.0)
	assert_int(config.max_choices).is_equal(6)
	assert_int(config.advance).is_equal(WgDialogueConfig.Advance.PAGE)
	assert_str(config.actions["confirm"]).is_equal("ui_accept")
	assert_int(_world.logged.size()).is_equal(5)


func test_a_missing_confirm_action_is_logged_once() -> void:
	_config({"actions": {"confirm": "talk"}})
	var done := _say("Hi.")
	_press("ui_accept")
	_press("ui_accept")
	assert_bool(done[0]).is_false()
	assert_array(_world.logged).is_equal(["WARN no input action 'talk' (dialogue config, actions.confirm)"])
