extends GdUnitTestSuite

const TextWorld := preload("res://tests/support/text_world.gd")

var _world: TextWorld
var _added_actions: Array[String] = []


func before_test() -> void:
	_world = TextWorld.new()
	_added_actions = []


func after_test() -> void:
	for action in _added_actions:
		InputMap.erase_action(action)
	_world.cleanup()


func _format(text: String, escape := false) -> String:
	return _world.texts.format(text, escape)


func _action(action: String, event: InputEvent) -> void:
	InputMap.add_action(action)
	InputMap.action_add_event(action, event)
	_added_actions.append(action)


func test_a_value_fills_its_placeholder_and_a_callable_is_called_each_time() -> void:
	var calls := [0]
	_world.texts.set_value(&"player", "Ludo")
	_world.texts.set_value(&"steps", func() -> int:
		calls[0] += 1
		return calls[0])
	assert_str(_format("{player} walked {steps} steps.")).is_equal("Ludo walked 1 steps.")
	assert_str(_format("{steps}")).is_equal("2")
	_world.texts.set_value(&"player", null)
	assert_str(_format("{player}")).is_equal("{player}")


func test_a_choice_follows_the_truth_of_its_value() -> void:
	var cases := {true: "yes", false: "no", 1: "yes", 0: "no", 0.5: "yes", "x": "yes", "": "no", Vector2.ZERO: "yes"}
	for shown: Variant in cases:
		_world.texts.set_value(&"it", shown)
		assert_str(_format("{it?yes|no}")).override_failure_message(str(shown)).is_equal(cases[shown])
	_world.texts.set_value(&"player_girl", true)
	assert_str(_format("Ready{player_girl?e|}?")).is_equal("Readye?")


func test_the_text_value_hook_gives_computed_values() -> void:
	_world.texts.set_value(&"badges", 1)
	_world.hooks.add(&"text_value", &"game", func(found: Variant, value_name: StringName) -> Variant:
		return 8 if value_name == &"badges" else found)
	assert_str(_format("{badges} badges")).is_equal("8 badges")


func test_key_names_the_key_bound_to_an_action_else_its_first_input() -> void:
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	_action("wg_talk", space)
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	_action("wg_pad", button)
	assert_str(_format("Press {key:wg_talk}.")).is_equal("Press Space.")
	assert_str(_format("{key:wg_pad}")).is_equal(button.as_text())
	_world.hooks.add(&"key_name", &"glyphs", func(shown: String, action: String) -> String:
		return "Ⓐ" if action == "wg_pad" else shown)
	assert_str(_format("{key:wg_pad}")).is_equal("Ⓐ")
	assert_str(_format("{key:wg_none}")).is_equal("{key:wg_none}")


func test_what_is_missing_stays_as_written_and_is_logged_once() -> void:
	_format("{nobody} {nobody} {it?a|b} {key:wg_none}")
	_format("{nobody}")
	assert_array(_world.logged).is_equal([
		"WARN no value for {nobody}",
		"WARN no value for {it?a|b}",
		"WARN no value for {key:wg_none}",
	])


func test_escaping_applies_to_what_values_put_in_only() -> void:
	_world.texts.set_value(&"player", "[page]Bob")
	_world.texts.set_value(&"flag", true)
	assert_str(_format("{player} [b]x[/b] {flag?[i]y[/i]|}", true)).is_equal("[lb]page]Bob [b]x[/b] [i]y[/i]")
	assert_str(_format("{player}")).is_equal("[page]Bob")


func _shout(argument: String) -> Variant:
	return argument.to_upper() if argument != "none" else null


func test_a_plugin_adds_placeholders_and_rewrites_texts_first() -> void:
	_world.texts.add_placeholder("shout", _shout)
	assert_str(_format("Hey {shout:you}! {shout:none}")).is_equal("Hey YOU! {shout:none}")
	_world.hooks.add(&"text_tokens", &"test", func(text: String) -> String: return text.replace("<<", "{shout:").replace(">>", "}"))
	assert_str(_format("<<loud>>")).is_equal("LOUD")
	assert_array(_world.logged).is_equal(["WARN no value for {shout:none}"])


func test_a_label_is_translated_then_filled() -> void:
	var french := Translation.new()
	french.locale = "fr"
	french.add_message("File {slot}", "Partie {slot}")
	TranslationServer.add_translation(french)
	_world.texts.language = "fr"
	assert_str(_world.texts.label("File {slot}", {"slot": 2})).is_equal("Partie 2")
	TranslationServer.remove_translation(french)
