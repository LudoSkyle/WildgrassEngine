extends GdUnitTestSuite

# Studio's events sorted into the engine's forms (feature 10 quater): events
# built by the tests, as RPG Maker holds them.

const StudioEvents := preload("res://addons/wildgrass/studio/studio_events.gd")

var _events := StudioEvents.new("")


static func command(code: int, parameters: Array = []) -> Dictionary:
	return {"class": "RPG::EventCommand", "code": code, "indent": 0, "parameters": parameters}


## A page saying `list`; options: trigger, graphic, through, self_switch,
## switch (a condition on switch 1).
static func page(list: Array, options := {}) -> Dictionary:
	return {"class": "RPG::Event::Page", "trigger": options.get("trigger", 0), "through": options.get("through", false),
		"condition": {"class": "RPG::Event::Page::Condition", "switch1_valid": options.get("switch", false), "switch1_id": 1,
			"switch2_valid": false, "variable_valid": false, "self_switch_valid": options.get("self_switch", false), "self_switch_ch": "A"},
		"graphic": {"class": "RPG::Event::Page::Graphic", "character_name": options.get("graphic", ""), "tile_id": 0, "direction": 2, "pattern": 0},
		"list": list + [command(0)]}


static func event(pages: Array, name := "EV") -> Dictionary:
	return {"class": "RPG::Event", "id": 1, "name": name, "x": 1, "y": 1, "pages": pages}


static func words(text := "1, 0 Hello") -> Array:
	return [command(101, [text]), command(401, ["again"])]


static func transfer(map_id := 2, cell := Vector2i(3, 1), direction := 2, by_variables := false) -> Dictionary:
	return command(201, [1 if by_variables else 0, map_id, cell.x, cell.y, direction, 1])


func _form(pages: Array, name := "EV", blocked := false) -> String:
	return _events.classify(event(pages, name), blocked)["form"]


func test_events_are_sorted_into_the_forms_the_engine_says() -> void:
	assert_str(_form([page(words(), {"graphic": "npc"})])).is_equal("character")
	assert_str(_form([page(words())])).is_equal("sign")
	assert_str(_form([page(words(), {"graphic": "npc"})], "[sprite=off] voice")).is_equal("sign")
	assert_str(_form([page(words() + [command(355, ["pick_item(:potion, 1)"])], {"graphic": "ball"})])).is_equal("item")
	assert_str(_form([page([command(108, ["a lamp"])], {"graphic": "lamp"})])).is_equal("still")
	assert_str(_form([page([])])).is_equal("nothing")
	assert_str(_form([])).is_equal("nothing")


func test_a_door_is_one_transfer_with_only_shows_sounds_and_moves_around_it() -> void:
	var around := [command(250, [{"class": "RPG::AudioFile", "name": "door"}]), command(209, [-1, {"class": "RPG::MoveRoute", "list": []}]),
		command(210), command(221), command(223, [null, 10]), command(355, ["Mod::Follow.smart_disable"]), command(655, ["ge(2).animate_from_charset([0,1],20)"]), transfer(), command(106, [5])]
	var door := _events.classify(event([page(around, {"trigger": 1})]), false)
	assert_str(door["form"]).is_equal("door")
	assert_array([door["map"], door["cell"], door["direction"], door["bumped"], door["notes"]]).is_equal([2, Vector2i(3, 1), 2, false, []])


func test_a_door_is_bumped_when_it_shows_and_blocks_or_its_cell_does_stepped_on_else() -> void:
	var list := [transfer()]
	assert_bool(_events.classify(event([page(list, {"trigger": 2, "graphic": "door"})]), false)["bumped"]).is_true()
	assert_bool(_events.classify(event([page(list, {"trigger": 1, "graphic": "pad", "through": true})]), false)["bumped"]).is_false()
	assert_bool(_events.classify(event([page(list, {"trigger": 1})]), true)["bumped"]).is_true()
	assert_bool(_events.classify(event([page(list, {"trigger": 1})], "invisible_door"), false)["bumped"]).is_true()


func test_what_a_door_changes_besides_and_its_arrival_page_are_noted() -> void:
	var list := [command(122, [5, 5, 0, 0, 1]), command(122, [5, 5, 0, 0, 1]), command(121, [2, 4, 0]), command(117, [44]),
		command(355, ["set_self_switch(true, 'A', 1, map_id = 2)"]), transfer(), command(123, ["B", 0])]
	var arrival := page([command(209, [-1, {"class": "RPG::MoveRoute", "list": []}]), command(123, ["A", 1])], {"trigger": 3, "self_switch": true})
	var door := _events.classify(event([page(list, {"trigger": 1}), arrival]), false)
	assert_str(door["form"]).is_equal("door")
	assert_array(door["notes"]).is_equal(["sets variable 5", "sets switch 2 to 4", "calls common event 44", "sets another event's self switch", "sets its self switch B", "its arrival page 2"])


func test_what_a_door_cannot_say_is_left_by_hand_with_why() -> void:
	var cases := {
		"a transfer on the action key": [page([transfer()], {"graphic": "door"})],
		"a transfer to a place held in variables": [page([transfer(2, Vector2i.ZERO, 2, true)], {"trigger": 1})],
		"a transfer, and a command 111 (Conditional Branch)": [page([command(111, [0, 1, 0]), transfer()], {"trigger": 1})],
		"a transfer, and a script (open_shop)": [page([command(355, ["open_shop(1)"]), transfer()], {"trigger": 1})],
		"a transfer, and a page 2 that is not its arrival": [page([transfer()], {"trigger": 1}), page(words(), {"switch": true})],
	}
	for reason: String in cases:
		var sorted_as := _events.classify(event(cases[reason]), false)
		assert_array([sorted_as["form"], sorted_as["reason"]]).is_equal(["", reason])


func test_anything_else_is_left_by_hand_with_why() -> void:
	var cases := {
		"2 pages": [page(words()), page(words(), {"switch": true})],
		"a page condition": [page(words(), {"switch": true})],
		"its trigger (autorun)": [page(words(), {"trigger": 3})],
		"a command 102 (Show Choices)": [page(words() + [command(102, [["Yes", "No"], 2])], {"graphic": "npc"})],
		"a script (open_shop)": [page([command(355, ["open_shop(1)"])], {"graphic": "npc"})],
	}
	for reason: String in cases:
		var sorted_as := _events.classify(event(cases[reason]), false)
		assert_array([sorted_as["form"], sorted_as["reason"]]).is_equal(["", reason])


func test_a_script_s_method_drops_its_modules_and_receivers() -> void:
	assert_str(_events.script_method("Mod::Follow.smart_disable")).is_equal("smart_disable")
	assert_str(_events.script_method("ge(2).animate_from_charset([0,1],20)")).is_equal("animate_from_charset")
	assert_str(_events.script_method("$game_player.moveto(3, 4)")).is_equal("moveto")
	assert_str(_events.script_method("set_self_switch(true, 'A', 1)")).is_equal("set_self_switch")
	assert_str(_events.script_method("  give_item(:potion)")).is_equal("give_item")
	assert_str(_events.script_method("")).is_empty()
