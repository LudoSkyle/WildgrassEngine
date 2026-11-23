extends GdUnitTestSuite

# Keys held on a screen go again: after a delay, then at a steady pace
# (feature 4, the dialogue config's `repeating`).

const World := preload("res://tests/support/walking_world.gd")

var _world: World


func before_test() -> void:
	_world = World.new(self)


func after_test() -> void:
	for action: String in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		Input.action_release(action)
	for screen in _world.screens.stack():
		screen.close()
	_world.root.free()
	_world.cleanup()


## Presses `action` and keeps it held, as a player does.
func _hold(action: String) -> void:
	Input.action_press(action)
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_world.screens.handle_input(event)


func _menu() -> WgMenuScreen:
	return _world.menu.open() as WgMenuScreen


func test_a_held_key_goes_again_after_the_delay_then_at_its_pace_until_released() -> void:
	var menu := _menu()
	assert_array(_world.menu.entries()).is_equal([&"bag", &"options", &"save", &"exit"])
	_hold("ui_down")
	assert_that(menu.selected()).is_equal(&"options")
	_world.dialogue.repeat_keys(0.3)
	assert_that(menu.selected()).is_equal(&"options")
	_world.dialogue.repeat_keys(0.06)
	assert_that(menu.selected()).is_equal(&"save")
	_world.dialogue.repeat_keys(0.08)
	assert_that(menu.selected()).is_equal(&"save")
	_world.dialogue.repeat_keys(0.04)
	assert_that(menu.selected()).is_equal(&"exit")
	Input.action_release("ui_down")
	_world.dialogue.repeat_keys(1.0)
	assert_that(menu.selected()).is_equal(&"exit")


func test_a_key_held_before_the_screen_opened_or_on_another_screen_does_not_go_again() -> void:
	Input.action_press("ui_down")
	var menu := _menu()
	_world.dialogue.repeat_keys(1.0)
	assert_that(menu.selected()).is_equal(&"bag")
	Input.action_release("ui_down")
	_hold("ui_down")
	var options := _world.screens.open(&"options", {"options": _world.options, "dialogue": _world.dialogue, "texts": _world.texts})
	_world.dialogue.repeat_keys(1.0)
	options.close()
	_world.dialogue.repeat_keys(1.0)
	assert_that(menu.selected()).is_equal(&"options")


func test_a_screen_keeps_a_key_from_repeating_the_bag_its_pockets() -> void:
	_world.bag.add(&"potion")
	var bag := _world.screens.open(&"bag", {"pocket": &"items", "bag": _world.bag, "dialogue": _world.dialogue, "texts": _world.texts}) as WgBagScreen
	_hold("ui_right")
	var turned := bag.pocket
	_world.dialogue.repeat_keys(1.0)
	_world.dialogue.repeat_keys(1.0)
	assert_that(bag.pocket).is_equal(turned)


func test_the_config_says_which_keys_repeat_and_refuses_what_it_cannot_use() -> void:
	_world.sandbox.write_json("config/dialogue.json", {"repeating": ["up", "jump"], "repeat_delay": -1, "repeat_interval": 0})
	var config := _world.dialogue.config()
	assert_array(config.repeating).is_equal(["up"])
	assert_float(config.repeat_delay).is_equal(0.35)
	assert_float(config.repeat_interval).is_equal(0.11)
	assert_array(_world.logged).is_equal([
		"WARN dialogue.json: repeating: unknown key 'jump'",
		"WARN dialogue.json: repeat_delay cannot be negative, got -1.0; using 0.35",
		"WARN dialogue.json: repeat_interval must be positive, got 0.0; using 0.11",
	])
	var menu := _menu()
	_hold("ui_down")
	_world.dialogue.repeat_keys(1.0)
	assert_that(menu.selected()).is_equal(&"options")
