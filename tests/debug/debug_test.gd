extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const ReleaseDebug := preload("res://tests/support/release_debug.gd")
const ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")

var _world: World
var _calls: Array[String] = []


func before_test() -> void:
	_world = World.new(self)
	_calls = []
	_world.map({}, Vector2i(12, 12))
	_world.maps.traveller = _world.walker(Vector2i(5, 5))


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_world.screens.handle_input(event)


func _mark(name: String, stay: bool) -> bool:
	_calls.append(name)
	return stay


func _labels(page: StringName) -> Array[String]:
	var found: Array[String] = []
	for line in _world.debug.lines(page):
		found.append(_world.debug.label_of(line, _world.texts))
	return found


func _open() -> WgDebugScreen:
	return _world.debug.open() as WgDebugScreen


func test_a_game_s_tools_go_to_its_page_before_another_hidden_or_removed() -> void:
	var shown := [true]
	_world.debug.add_tool(&"rod", "Give the rod", _mark.bind("rod", false))
	_world.debug.add_tool(&"heal", "Heal", _mark.bind("heal", false))
	_world.debug.add_tool(&"skip", "Skip", _mark.bind("skip", false), {"before": &"heal", "shown": func() -> bool: return shown[0]})
	assert_array(_labels(&"game")).is_equal(["Give the rod", "Skip", "Heal"])
	shown[0] = false
	assert_array(_labels(&"game")).is_equal(["Give the rod", "Heal"])
	_world.debug.add_tool(&"rod", "Give the old rod", _mark.bind("rod", false))
	assert_array(_labels(&"game")).is_equal(["Give the old rod", "Heal"])
	assert_bool(_world.debug.remove_tool(&"heal")).is_true()
	assert_bool(_world.debug.remove_tool(&"heal")).is_false()
	assert_bool(_world.debug.remove_tool(&"engine")).is_false()
	assert_array(_labels(&"game")).is_equal(["Give the old rod"])
	_world.debug.add_tool(&"sun", "Always sunny", _mark.bind("sun", true), {"page": &"engine", "before": &"hour"})
	assert_int(_labels(&"engine").find("Always sunny")).is_equal(_labels(&"engine").find("Hour: real") - 1)


func test_the_first_page_keeps_the_engine_and_the_game_apart_the_game_hidden_while_empty() -> void:
	assert_array(_labels(_world.debug.FIRST)).is_equal(["Engine"])
	assert_that(_world.debug.first_page()).is_equal(&"engine")
	var screen := _open()
	assert_array(screen.labels().slice(0, 1)).is_equal(["Fill the bag"])
	assert_str(screen.labels().back()).is_equal("Back")
	screen.close()
	_world.debug.add_page(&"bell", "Bell quest", {"lines": func() -> Array: return [{"label": "Ring", "action": _mark.bind("ring", false)}]})
	assert_array(_labels(_world.debug.FIRST)).is_equal(["Engine", "Game"])
	assert_array(_labels(&"game")).is_equal(["Bell quest"])
	assert_array(_labels(&"bell")).is_equal(["Ring"])
	assert_that(_world.debug.first_page()).is_equal(_world.debug.FIRST)
	_world.debug.add_page(&"engine", "Mine")
	assert_array(_world.logged).contains(["ERROR 'engine' is the engine's page"])


func test_pages_open_and_back_and_cancel_go_up_then_close() -> void:
	_world.debug.add_page(&"bell", "Bell quest")
	_world.debug.add_tool(&"ring", "Ring", _mark.bind("ring", false), {"page": &"bell"})
	_world.debug.add_tool(&"nested", "Steps", Callable())
	var screen := _open()
	assert_array(screen.labels()).is_equal(["Engine", "Game", "Back"])
	_press("ui_down")
	_press("ui_accept")
	assert_array(screen.labels()).is_equal(["Bell quest", "Steps", "Back"])
	assert_str((screen.get_node("Panel/Margin/Column/Title") as Label).text).is_equal("Game")
	_press("ui_accept")
	assert_array(screen.labels()).is_equal(["Ring", "Back"])
	_press("ui_down")
	_press("ui_accept")
	assert_array(screen.labels()).is_equal(["Bell quest", "Steps", "Back"])
	_press("ui_cancel")
	assert_array(screen.labels()).is_equal(["Engine", "Game", "Back"])
	_press("ui_cancel")
	assert_bool(screen.is_closed()).is_true()
	assert_bool(screen.closed_by_tool).is_false()


func test_a_tool_keeping_the_page_has_its_label_read_again_and_one_closing_runs_what_it_asked_after() -> void:
	var times := [0]
	_world.debug.add_tool(&"count", func() -> String: return "Count: %d" % times[0], func() -> bool:
		times[0] += 1
		return true)
	_world.debug.add_tool(&"done", "Done", func() -> bool:
		_world.debug.then(func() -> void: _calls.append("after"))
		return false)
	var screen := _open()
	assert_array(screen.labels()).is_equal(["Engine", "Game", "Back"])
	_press("ui_down")
	_press("ui_accept")
	assert_array(screen.labels()).is_equal(["Count: 0", "Done", "Back"])
	_press("ui_accept")
	assert_array(screen.labels()).is_equal(["Count: 1", "Done", "Back"])
	assert_bool(screen.is_closed()).is_false()
	_press("ui_down")
	_press("ui_accept")
	assert_bool(screen.closed_by_tool).is_true()
	assert_array(_calls).is_empty()
	await get_tree().process_frame
	assert_array(_calls).is_equal(["after"])


func test_from_the_pause_menu_a_tool_closing_closes_the_menu_and_back_returns_to_it() -> void:
	_world.debug.add_tool(&"done", "Done", _mark.bind("done", false))
	_world.menu.add_entry(&"debug", "Debug", func() -> bool: return await _world.debug.open_from_menu(_world.menu), "", &"exit")
	var menu := _world.menu.open() as WgMenuScreen
	_world.menu.cursor = &"debug"
	menu.refresh()
	_press("ui_accept")
	var screen := _world.screens.top() as WgDebugScreen
	assert_bool(menu.visible).is_false()
	_press("ui_cancel")
	await get_tree().process_frame
	assert_bool(menu.is_closed()).is_false()
	assert_bool(menu.visible).is_true()
	_press("ui_accept")
	screen = _world.screens.top() as WgDebugScreen
	_press("ui_down")
	_press("ui_accept")
	_press("ui_accept")
	await get_tree().process_frame
	assert_array(_calls).is_equal(["done"])
	assert_array(_world.screens.stack()).is_empty()


func test_a_page_taller_than_the_screen_scrolls_with_the_cursor() -> void:
	for index in 30:
		_world.debug.add_tool(StringName("t%d" % index), "Tool %d" % index, _mark.bind("t", true))
	var screen := _open()
	_press("ui_down")
	_press("ui_accept")
	var scroll := screen.get_node("Panel/Margin/Column/Scroll") as ScrollContainer
	await get_tree().process_frame
	assert_int(scroll.scroll_vertical).is_equal(0)
	_press("ui_up")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(screen.cursor).is_equal(30)
	assert_int(scroll.scroll_vertical).is_greater(0)


## The debug tools as a build would have them, with `config` written first.
func _built(config: Dictionary, debug_build: bool) -> ReleaseDebug:
	if config.is_empty():
		DirAccess.remove_absolute(_world.sandbox.root + "config/debug.json")
	else:
		_world.sandbox.write_json("config/debug.json", config)
	var registry := ConfigRegistry.new(Paths.new(false), _world.logger)
	registry.register(&"debug", WgDebugConfig, "debug")
	var debug := ReleaseDebug.new(_world.logger, registry, _world.screens)
	debug.debug_build = debug_build
	return debug


func test_the_entry_shows_as_enabled_says_auto_meaning_a_debug_build() -> void:
	assert_bool(_built({}, true).is_enabled()).is_true()
	assert_bool(_built({}, false).is_enabled()).is_false()
	assert_bool(_built({"enabled": true}, false).is_enabled()).is_true()
	assert_bool(_built({"enabled": false}, true).is_enabled()).is_false()
	assert_bool(_built({"enabled": "true"}, false).is_enabled()).is_true()


func test_a_wrong_config_is_corrected() -> void:
	_world.sandbox.write_json("config/debug.json", {"enabled": "sometimes", "hours": [["dawn", 6], ["late", 25], "noon"], "speeds": [2, 0, -1]})
	var config := _world.debug.config()
	assert_str(config.enabled).is_equal("auto")
	assert_array(config.hours).is_equal([["dawn", 6.0]])
	assert_array(config.speeds).is_equal([2.0])
	assert_int(_world.logged.filter(func(line: String) -> bool: return line.contains("debug.json")).size()).is_equal(5)


func test_the_first_page_is_titled_debug_and_a_tool_s_lines_stay_its_own() -> void:
	_world.debug.add_tool(&"odd", "Odd", _mark.bind("odd", false), {"lines": func() -> Array: return [{"label": "Stray", "action": _mark.bind("stray", false)}]})
	var screen := _open()
	assert_str((screen.get_node("Panel/Margin/Column/Title") as Label).text).is_equal("Debug")
	assert_array(screen.labels()).is_equal(["Engine", "Game", "Back"])


func test_the_tools_open_once_at_a_time() -> void:
	var screen := _open()
	assert_object(screen).is_not_null()
	assert_object(_open()).is_null()
	screen.close()
	assert_object(_open()).is_not_null()


func test_an_hour_given_twice_is_kept_once() -> void:
	_world.sandbox.write_json("config/debug.json", {"hours": [["dawn", 6], ["morning", 6], ["day", 12]]})
	assert_array(_world.debug.config().hours).is_equal([["dawn", 6.0], ["day", 12.0]])
