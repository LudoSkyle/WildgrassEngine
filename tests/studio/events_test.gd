extends GdUnitTestSuite

# Studio's events written as the engine's (feature 10 quater): events built
# by the tests, as RPG Maker holds them.

const StudioEvents := preload("res://addons/wildgrass/studio/studio_events.gd")

var _events := StudioEvents.new("")


func before_test() -> void:
	_events = StudioEvents.new("")


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


func _built(code: int, parameters: Array, indent := 0) -> WgEventCommand:
	var made := _events.build_commands([{"code": code, "indent": indent, "parameters": parameters}])
	return made[0]


func test_an_event_is_written_with_every_page_its_condition_look_and_trigger() -> void:
	var sheet := ImageTexture.create_from_image(Image.create(64, 64, false, Image.FORMAT_RGBA8))
	_events.texture_of = func(path: String) -> Texture2D: return sheet if path == "res://graphics/characters/npc.png" else null
	var first := page([], {"trigger": 1, "graphic": "npc", "through": true})
	first["graphic"]["direction"] = 4
	first["graphic"]["pattern"] = 2
	first["graphic"]["opacity"] = 51
	first["direction_fix"] = true
	first["step_anime"] = true
	var second := page([])
	second["condition"] = {"class": "RPG::Event::Page::Condition", "switch1_valid": true, "switch1_id": 3, "switch2_valid": true, "switch2_id": 5,
		"variable_valid": true, "variable_id": 7, "variable_value": 2, "self_switch_valid": true, "self_switch_ch": "B"}
	var made := event([first, second], "invisible_box")
	made["id"] = 4
	made["x"] = 2
	made["y"] = 3
	var node := _events.build_event(made, 16)
	assert_array([node.name, node.event_id, node.position, node.invisible_blocker]).is_equal([&"Event4", 4, Vector2(40, 56), true])
	assert_object(node.get_node("Sprite")).is_instanceof(WgCharacterSprite)
	assert_array(node.pages.map(func(each: WgEventPage) -> String: return each.condition)).is_equal(["", "switch_3, switch_5, variable_7 >= 2, local:B"])
	var shown := node.pages[0]
	assert_object(shown.sheet).is_same(sheet)
	assert_array([shown.direction, shown.pattern, shown.trigger, shown.through, shown.fixed_direction, shown.step_animation]).is_equal([Vector2i.LEFT, 2, WgEventPage.Trigger.TOUCH, true, true, true])
	assert_float(shown.opacity).is_equal_approx(0.2, 0.001)
	assert_object(node.pages[1].sheet).is_null()
	node.free()


func test_commands_are_the_engine_s_one_to_one_with_their_indent() -> void:
	var branch := _built(111, [0, 12, 1], 1) as WgEventIf
	assert_array([branch.kind, branch.number, branch.on, branch.indent]).is_equal([WgEventIf.Kind.SWITCH, 12, false, 1])
	var compare := _built(111, [1, 3, 1, 4, 3]) as WgEventIf
	assert_array([compare.kind, compare.number, compare.against_variable, compare.value, compare.comparison]).is_equal([WgEventIf.Kind.VARIABLE, 3, true, 4, WgEventIf.Comparison.MORE])
	var local := _built(111, [2, "C", 0]) as WgEventIf
	assert_array([local.kind, local.letter, local.on]).is_equal([WgEventIf.Kind.LOCAL_SWITCH, "C", true])
	var facing := _built(111, [6, -1, 8]) as WgEventIf
	assert_array([facing.kind, facing.number, facing.direction]).is_equal([WgEventIf.Kind.FACING, -1, Vector2i.UP])
	var money := _built(111, [7, 500, 1]) as WgEventIf
	assert_array([money.kind, money.value, money.on]).is_equal([WgEventIf.Kind.MONEY, 500, false])
	assert_object(_built(411, [])).is_instanceof(WgEventElse)
	for code: int in [0, 404, 412, 604]:
		assert_object(_built(code, [])).is_instanceof(WgEventBlockEnd)
	assert_object(_built(112, [])).is_instanceof(WgEventLoop)
	assert_object(_built(413, [])).is_instanceof(WgEventRepeat)
	assert_object(_built(113, [])).is_instanceof(WgEventBreak)
	assert_object(_built(115, [])).is_instanceof(WgEventExit)
	assert_object(_built(116, [])).is_instanceof(WgEventErase)
	assert_int((_built(117, [44]) as WgEventCallCommon).common_event).is_equal(44)
	assert_str((_built(118, ["top"]) as WgEventLabel).label).is_equal("top")
	assert_str((_built(119, ["top"]) as WgEventJump).label).is_equal("top")
	assert_float((_built(106, [45]) as WgEventWait).seconds).is_equal_approx(1.5, 0.0001)
	assert_str((_built(108, ["a note"]) as WgEventComment).text).is_equal("a note")
	var switches := _built(121, [2, 4, 1]) as WgEventSetSwitches
	assert_array([switches.first, switches.last, switches.on]).is_equal([2, 4, false])
	var self_switch := _built(123, ["B", 0]) as WgEventSetLocalSwitch
	assert_array([self_switch.letter, self_switch.on]).is_equal(["B", true])


func test_variables_take_their_operand_as_rpg_maker_says() -> void:
	var Operand := WgEventSetVariables.Operand
	var constant := _built(122, [5, 6, 1, 0, 9]) as WgEventSetVariables
	assert_array([constant.first, constant.last, constant.operation, constant.operand, constant.value]).is_equal([5, 6, WgEventSetVariables.Operation.ADD, Operand.CONSTANT, 9])
	var random := _built(122, [1, 1, 0, 2, 3, 8]) as WgEventSetVariables
	assert_array([random.operand, random.value, random.value_max]).is_equal([Operand.RANDOM, 3, 8])
	var character := _built(122, [1, 1, 0, 6, -1, 2]) as WgEventSetVariables
	assert_array([character.operand, character.value, character.character_value]).is_equal([Operand.CHARACTER, -1, WgEventSetVariables.Of.FACING])
	var game := _built(122, [1, 1, 0, 7, 2]) as WgEventSetVariables
	assert_array([game.operand, game.game_value]).is_equal([Operand.GAME, WgEventSetVariables.Game.MONEY])
	var actor := _built(122, [1, 1, 0, 4, 1, 0]) as WgEventSetVariables
	assert_array([actor.operand, actor.about]).is_equal([Operand.UNSUPPORTED, "actor"])


func test_a_command_with_no_class_is_kept_raw_and_counted_by_what_it_is() -> void:
	var list := [
		command(101, ["1, 0 Hello"]), command(401, ["again"]), command(355, ["Mod::Follow.smart_disable"]), command(655, ["more"]),
		command(201, [0, 2, 3, 1, 2, 1]), command(111, [12, "gv[3] > 2"]), command(111, [4, 1, 0]),
	]
	var built := _events.build_commands(list)
	assert_array(built.slice(0, 5).map(func(made: WgEventCommand) -> int: return (made as WgEventRaw).code)).is_equal([101, 401, 355, 655, 201])
	assert_array((built[4] as WgEventRaw).parameters).is_equal([0, 2, 3, 1, 2, 1])
	assert_array([(built[5] as WgEventIf).kind, (built[5] as WgEventIf).about, (built[6] as WgEventIf).about]).is_equal([WgEventIf.Kind.UNSUPPORTED, "script gv", "actor condition"])
	var counts := {}
	counts.merge(_events.raw_counts)
	assert_dict(counts).is_equal({"Show Text": 1, "script smart_disable": 1, "Transfer Player": 1, "condition: script gv": 1, "condition: actor condition": 1})


func test_a_script_s_method_drops_its_modules_and_receivers() -> void:
	assert_str(_events.script_method("Mod::Follow.smart_disable")).is_equal("smart_disable")
	assert_str(_events.script_method("ge(2).animate_from_charset([0,1],20)")).is_equal("animate_from_charset")
	assert_str(_events.script_method("$game_player.moveto(3, 4)")).is_equal("moveto")
	assert_str(_events.script_method("set_self_switch(true, 'A', 1)")).is_equal("set_self_switch")
	assert_str(_events.script_method("  give_item(:potion)")).is_equal("give_item")
	assert_str(_events.script_method("")).is_empty()
