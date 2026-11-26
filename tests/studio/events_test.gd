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
		command(231, [1, "picture"]), command(355, ["Mod::Follow.smart_disable"]), command(655, ["more"]),
		command(203, [2, 3, 4]), command(111, [12, "$bag.contain_item?(:potion)"]), command(111, [4, 1, 0]),
	]
	var built := _events.build_commands(list)
	assert_array(built.slice(0, 4).map(func(made: WgEventCommand) -> int: return (made as WgEventRaw).code)).is_equal([231, 355, 655, 203])
	assert_array((built[3] as WgEventRaw).parameters).is_equal([2, 3, 4])
	assert_array([(built[4] as WgEventIf).kind, (built[4] as WgEventIf).about, (built[5] as WgEventIf).about]).is_equal([WgEventIf.Kind.UNSUPPORTED, "script contain_item?", "actor condition"])
	var counts := {}
	counts.merge(_events.raw_counts)
	assert_dict(counts).is_equal({"Show Picture": 1, "script smart_disable": 1, "Scroll Map": 1, "condition: script contain_item?": 1, "condition: actor condition": 1})


func test_a_transfer_goes_to_the_map_of_studio_s_number_or_by_variables() -> void:
	_events.map_symbols = {2: &"map002"}
	var built := _events.build_commands([transfer(2, Vector2i(3, 1), 4), command(201, [1, 5, 6, 7, 0, 0]), transfer(9)])
	var direct := built[0] as WgEventTransfer
	assert_array([direct.map, direct.cell, direct.by_variables, direct.direction, direct.transition]).is_equal([&"map002", Vector2i(3, 1), false, Vector2i.LEFT, &"none"])
	var by := built[1] as WgEventTransfer
	assert_array([by.by_variables, by.map_variable, by.x_variable, by.y_variable, by.direction, by.transition]).is_equal([true, 5, 6, 7, Vector2i.ZERO, &"dissolve"])
	assert_int((built[2] as WgEventRaw).code).is_equal(201)
	assert_int(_events.raw_counts.get("Transfer Player to a map not in the project", 0)).is_equal(1)


func test_an_event_location_is_set_by_cell_by_variables_or_by_swapping() -> void:
	var built := _events.build_commands([command(202, [3, 0, 4, 5, 8]), command(202, [0, 1, 10, 11, 0]), command(202, [-1, 2, 4, 0, 6])])
	var by_cell := built[0] as WgEventSetEventLocation
	assert_array([by_cell.character, by_cell.mode, by_cell.cell, by_cell.direction]).is_equal([3, WgEventSetEventLocation.Mode.CELL, Vector2i(4, 5), Vector2i.UP])
	var by_variables := built[1] as WgEventSetEventLocation
	assert_array([by_variables.mode, by_variables.x_variable, by_variables.y_variable, by_variables.direction]).is_equal([WgEventSetEventLocation.Mode.VARIABLES, 10, 11, Vector2i.ZERO])
	var swap := built[2] as WgEventSetEventLocation
	assert_array([swap.character, swap.mode, swap.other, swap.direction]).is_equal([-1, WgEventSetEventLocation.Mode.SWAP, 4, Vector2i.RIGHT])


func test_a_script_of_studio_s_words_is_written_in_gdscript_others_kept_raw() -> void:
	var cases := {
		"set_self_switch(true, \"A\", 7)": "set_self_switch(true, \"A\", 7)",
		"set_self_switch(false,'B',1, 19)": "set_self_switch(false, \"B\", 1, 19)",
		"set_self_switch(true,\"C\",3,map_id = 19)": "set_self_switch(true, \"C\", 3, 19)",
		"$game_player.moveto(3, 4); $game_player.direction = 6": "gp.moveto(3, 4)\ngp.direction = 6",
		"PFM::Text.set_variable(\"[TEAM]\", gv[2])": "text.set_variable(\"[TEAM]\", gv(2))",
		"@choices = nil": "memory[\"choices\"] = null",
		"cry_pokemon(:pikachu, volume: 80, form: 1)": "cry_pokemon(&\"pikachu\", {volume = 80, form = 1})",
		"delete_this_event_forever": "delete_this_event_forever()",
		"$game_switches[4] = gv[1] >= 2": "set_gs(4, gv(1) >= 2)",
		"get_character(3).direction = 2": "get_character(3).direction = 2",
	}
	for ruby: String in cases:
		var made := _built(355, [ruby]) as WgEventScript
		assert_object(made).override_failure_message(ruby).is_not_null()
		assert_str(made.source).override_failure_message(ruby).is_equal(cases[ruby])
	var lines := _events.build_commands([command(355, ["gv[26] = 3"]), command(655, ["gv[26] += 2"]), command(655, ["gv[27] -= gv[26] * 2"])])
	assert_int(lines.size()).is_equal(1)
	assert_str((lines[0] as WgEventScript).source).is_equal("set_gv(26, 3)\nset_gv(26, gv(26) + 2)\nset_gv(27, gv(27) - gv(26) * 2)")
	var kept := _events.build_commands([
		command(355, ["(1..3).each { |id| set_self_switch(true, 'A', id) }"]),
		command(355, ["set_self_switch(true, \"A\", id_event)"]),
		command(355, ["Mod::Follow.smart_enable"]), command(655, ["gv[1] = 2"]),
		command(355, ["gs[3] += 1"]),
	])
	assert_array(kept.map(func(built: WgEventCommand) -> bool: return built is WgEventRaw)).is_equal([true, true, true, true, true])


func test_a_script_condition_is_written_as_a_gdscript_expression() -> void:
	var cases := {
		"trainer_spotted(4)": "trainer_spotted(4)",
		"player_spotted_rect?(3, 2)": "player_spotted_rect(3, 2)",
		"player_spotted_directional?(up: 3, down: 4)": "player_spotted_directional({up = 3, down = 4})",
		"detect_player(4, :right) && gp.direction == 8": "detect_player(4, &\"right\") and gp.direction == 8",
		"!gs[17] && !gs[23]": "not gs(17) and not gs(23)",
		"gs[37] || gs[38]": "gs(37) or gs(38)",
		"$game_switches[17] == true && gp.direction == 6": "gs(17) == true and gp.direction == 6",
		"gv[26] >= 16 && get_self_switch('A', 17, 21) == false": "gv(26) >= 16 and get_self_switch(\"A\", 17, 21) == false",
		"(gs[1] || gs[2]) && !(gv[4] > 1)": "(gs(1) or gs(2)) and not gv(4) > 1",
		"gs[1] && (gs[2] && gs[3])": "gs(1) and (gs(2) and gs(3))",
		"gv[26] % 3 == 0": "gv(26) % 3 == 0",
		"gv[1] - (gv[2] - 3) < -gv[4]": "gv(1) - (gv(2) - 3) < -gv(4)",
		"$game_map.events[6].x == 24": "get_character(6).x == 24",
		"ge.x == 22 && ge.y == 33": "ge().x == 22 and ge().y == 33",
		"!gs[1] == false": "(not gs(1)) == false",
		"(gv[1] == 1) == true": "(gv(1) == 1) == true",
		"!(gs[1] || gs[2])": "not (gs(1) or gs(2))",
		"get_self_switch(\"B\")": "get_self_switch(\"B\")",
	}
	for ruby: String in cases:
		var made := _built(111, [12, ruby]) as WgEventIf
		assert_int(made.kind).override_failure_message(ruby).is_equal(WgEventIf.Kind.SCRIPT)
		assert_str(made.source).override_failure_message(ruby).is_equal(cases[ruby])
	for ruby: String in ["$bag.contain_item?(:coin_case)", "gv[1] == 2 == true", "x ? 1 : 2"]:
		assert_int((_built(111, [12, ruby]) as WgEventIf).kind).override_failure_message(ruby).is_equal(WgEventIf.Kind.UNSUPPORTED)
	assert_int(_events.raw_counts.get("condition: script contain_item?", 0)).is_equal(1)


func test_the_party_s_words_are_written_as_studio_s_context_names_them() -> void:
	var conditions := {
		"player_spotted?(3) && $actors.empty?": "player_spotted(3) and actors.empty()",
		"$actors.size < 6": "actors.size() < 6",
		"$actors[gv[43]].form == 5": "actors.at(gv(43)).form == 5",
		"gv[43] >= 0 && $actors[gv[43]].db_symbol == :rotom": "gv(43) >= 0 and actors.at(gv(43)).db_symbol == &\"rotom\"",
		"$actors[0].loyalty < 192": "actors.at(0).loyalty < 192",
		"$actors[gv[45]].egg?": "actors.at(gv(45)).egg()",
		"$actors[gv[43]].shiny": "actors.at(gv(43)).shiny",
		"$pokemon_party.pokemon_alive == 1 && !$actors[gv[45]].dead?": "pokemon_party.pokemon_alive() == 1 and not actors.at(gv(45)).dead()",
	}
	for ruby: String in conditions:
		var made := _built(111, [12, ruby]) as WgEventIf
		assert_int(made.kind).override_failure_message(ruby).is_equal(WgEventIf.Kind.SCRIPT)
		assert_str(made.source).override_failure_message(ruby).is_equal(conditions[ruby])
	var scripts := {
		"$pokemon_party.heal_party": "pokemon_party.heal_party()",
		"$actors[gv[43]].form = 4": "actors.at(gv(43)).form = 4",
		"add_pokemon(:caterpie, 5)": "add_pokemon(&\"caterpie\", 5)",
		"add_specific_pokemon(id: :heliolisk, level: 35, given_name: \"Smaug\", moves: [:surf], shiny: true)":
			"add_specific_pokemon({id = &\"heliolisk\", level = 35, given_name = \"Smaug\", moves = [&\"surf\"], shiny = true})",
		"@froslass = PFM::Pokemon.generate_from_hash(id: :froslass, level: 30)": "memory[\"froslass\"] = pokemon_from_hash({id = &\"froslass\", level = 30})",
		"PFM::Text.set_variable(\"[POKE]\", $actors[gv[43]].given_name)": "text.set_variable(\"[POKE]\", actors.at(gv(43)).given_name)",
		"@choices = [ext_text(3, 147),\next_text(3, 148)]": "memory[\"choices\"] = [ext_text(3, 147), ext_text(3, 148)]",
		"choice(26, 5, \"19, 168 Morning\", \"19,169 Midday\", \"Night\")": "choice(26, 5, \"19, 168 Morning\", \"19,169 Midday\", \"Night\")",
	}
	for ruby: String in scripts:
		var made := _built(355, [ruby]) as WgEventScript
		assert_object(made).override_failure_message(ruby).is_not_null()
		assert_str(made.source).override_failure_message(ruby).is_equal(scripts[ruby])
	assert_bool(_events.messages.translations.has("dialogs.3.147")).is_true()
	assert_bool(_events.messages.translations.has("dialogs.3.148")).is_true()
	assert_bool(_events.messages.translations.has("dialogs.19.168")).is_true()
	assert_bool(_events.messages.translations.has("dialogs.19.169")).is_true()
	var kept := _events.build_commands([
		command(355, ["$actors.any? { |pkm| pkm.db_symbol == :rotom }"]),
		command(355, ["$actors[0].forget_skill(:surf)"]),
		command(355, ["@team[0].name"]),
		command(355, ["$actors[0].level = 5"]),
		command(355, ["$actors[0].form.to_s"]),
		command(355, ["$actors.first.form"]),
		command(355, ["set_gv(1, $actors[0].form.level)"]),
		command(355, ["choice(26, -1, *@choices)"]),
	])
	assert_array(kept.map(func(built: WgEventCommand) -> bool: return built is WgEventRaw)).is_equal([true, true, true, true, true, true, true, true])


func test_the_project_s_translation_wins_and_a_script_not_translated_gets_its_file() -> void:
	var folder := "user://studio_scripts_test"
	_events.scripts_folder = folder
	DirAccess.make_dir_recursive_absolute(folder + "/to_translate")
	var ruby := "choice(26, -1, *@choices)"
	var mine := FileAccess.open("%s/%s.gd" % [folder, StudioEvents.hash_of(ruby)], FileAccess.WRITE)
	mine.store_string("extends WgScriptContext\n# Ruby: choice(26, -1, *@choices)\n\n\nfunc run() -> void:\n\tvar answer := await ask(\"?\", [ext_text(5, 6)])\n\n\tset_value(&\"variable_26\", answer + 1)\n\n\nfunc other() -> void:\n\tpass\n")
	mine.close()
	var seen := FileAccess.open("%s/%s.gd" % [folder, StudioEvents.hash_of("seen_by(3)")], FileAccess.WRITE)
	seen.store_string("extends WgScriptContext\n\nfunc check():\n\treturn sees_player(3)\n")
	seen.close()
	assert_str((_built(355, [ruby]) as WgEventScript).source).is_equal("var answer := await ask(\"?\", [ext_text(5, 6)])\n\nset_value(&\"variable_26\", answer + 1)")
	assert_bool(_events.messages.translations.has("dialogs.5.6")).is_true()
	assert_str((_built(111, [12, "seen_by(3)"]) as WgEventIf).source).is_equal("sees_player(3)")
	assert_object(_built(355, ["wave(1)\nwave(2)"]) as WgEventRaw).is_not_null()
	var waiting := "%s/to_translate/%s.gd" % [folder, StudioEvents.hash_of("wave(1)\nwave(2)")]
	assert_bool(FileAccess.file_exists(waiting)).is_true()
	assert_str(FileAccess.get_file_as_string(waiting)).contains("#   wave(1)\n#   wave(2)").contains("func run() -> void:\n\tpass")
	_events.build_commands([command(111, [12, "nope?(1)"])])
	var condition := "%s/to_translate/%s.gd" % [folder, StudioEvents.hash_of("nope?(1)")]
	assert_str(FileAccess.get_file_as_string(condition)).contains("func check():\n\treturn false")
	FileAccess.open(waiting, FileAccess.WRITE).store_string("kept")
	_built(355, ["wave(1)\nwave(2)"])
	assert_str(FileAccess.get_file_as_string(waiting)).is_equal("kept")
	assert_dict(_events.to_translate).contains_keys([StudioEvents.hash_of("wave(1)\nwave(2)"), StudioEvents.hash_of("nope?(1)")])
	for file in DirAccess.get_files_at(folder + "/to_translate"):
		DirAccess.remove_absolute(folder + "/to_translate/" + file)
	for file in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder + "/" + file)
	DirAccess.remove_absolute(folder + "/to_translate")
	DirAccess.remove_absolute(folder)


func test_files_to_translate_no_longer_waiting_and_untouched_are_removed() -> void:
	const StudioMaps := preload("res://addons/wildgrass/studio/studio_maps.gd")
	var folder := "user://studio_prune_test"
	DirAccess.make_dir_recursive_absolute(folder)
	var files := {
		"done.gd": "extends X\n#   ruby\n\n\nfunc run() -> void:\n\tpass\n", "done.gd.uid": "uid://a",
		"waiting.gd": "extends X\n\n\nfunc run() -> void:\n\tpass\n",
		"started.gd": "extends X\n\n\nfunc run() -> void:\n\tgive_item(&\"potion\")\n",
		"seen.gd": "extends X\n\n\nfunc check():\n\treturn false\n", "lost.gd.uid": "uid://b",
	}
	for file: String in files:
		FileAccess.open(folder.path_join(file), FileAccess.WRITE).store_string(files[file])
	var waiting: Dictionary[String, bool] = {"waiting": true}
	assert_int(StudioMaps.prune_to_translate(folder, waiting)).is_equal(2)
	var left := Array(DirAccess.get_files_at(folder))
	left.sort()
	assert_array(left).is_equal(["started.gd", "waiting.gd"])
	for file: String in left:
		DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)


func test_a_script_s_method_drops_its_modules_and_receivers() -> void:
	assert_str(_events.script_method("Mod::Follow.smart_disable")).is_equal("smart_disable")
	assert_str(_events.script_method("ge(2).animate_from_charset([0,1],20)")).is_equal("animate_from_charset")
	assert_str(_events.script_method("$game_player.moveto(3, 4)")).is_equal("moveto")
	assert_str(_events.script_method("set_self_switch(true, 'A', 1)")).is_equal("set_self_switch")
	assert_str(_events.script_method("  give_item(:potion)")).is_equal("give_item")
	assert_str(_events.script_method("")).is_empty()


static func move_route(steps: Array, repeat := false) -> Dictionary:
	var made := {"class": "RPG::MoveRoute", "repeat": repeat, "skippable": false, "list": []}
	for step: Array in steps:
		made["list"].append({"class": "RPG::MoveCommand", "code": step[0], "parameters": step.slice(1)})
	made["list"].append({"class": "RPG::MoveCommand", "code": 0, "parameters": []})
	return made


func test_a_page_s_way_of_moving_and_its_route_are_the_engine_s() -> void:
	var moving := page([])
	moving["move_type"] = 3
	moving["move_speed"] = 4
	moving["move_frequency"] = 6
	moving["move_route"] = move_route([[1], [15, 10], [14, -1, 2], [29, 5], [27, 12], [42, 128], [45, "Mod::Thing.wave(1)"]], true)
	var made := _events.build_page(moving)
	assert_array([made.move_type, made.move_speed, made.move_frequency, made.move_route.repeat]).is_equal([WgEventPage.MoveType.ROUTE, 4, 6, true])
	var steps := made.move_route.steps
	assert_array(steps.map(func(step: WgMoveStep) -> int: return step.kind)).is_equal([1, 15, 14, 29, 27, 42, 45])
	assert_array([steps[1].value, steps[2].offset, steps[3].value, steps[4].value, steps[5].value, steps[6].original, steps[6].call]).is_equal([10, Vector2i(-1, 2), 5, 12, 128, "Mod::Thing.wave(1)", ""])
	var counts := {}
	counts.merge(_events.raw_counts)
	assert_dict(counts).is_equal({"route script wave": 1})


func test_a_route_imposed_drops_its_editor_lines_and_a_wait_for_moves_follows() -> void:
	var route := move_route([[4], [44, {"class": "RPG::AudioFile", "name": "nowhere", "volume": 80, "pitch": 100}]])
	var built := _events.build_commands([command(209, [-1, route]), command(509, [route["list"][0]]), command(509, [route["list"][1]]), command(210, [])])
	assert_int(built.size()).is_equal(2)
	var move := built[0] as WgEventMoveRoute
	assert_int(move.character).is_equal(-1)
	assert_array(move.route.steps.map(func(step: WgMoveStep) -> int: return step.kind)).is_equal([4, 44])
	assert_int(move.route.steps[1].volume).is_equal(80)
	assert_object(built[1]).is_instanceof(WgEventWaitForMoves)
	# A sound with no file is told, never kept.
	assert_str(String(move.route.steps[1].sound)).is_empty()
	assert_int(_events.raw_counts.get("route: a sound with no file Godot plays", 0)).is_equal(1)


func test_the_sheets_and_sounds_routes_name_are_listed_to_be_copied() -> void:
	var graphic := move_route([[41, "walker_b", 0, 4, 1], [44, {"class": "RPG::AudioFile", "name": "door", "volume": 100, "pitch": 100}]])
	var moving := page([command(209, [0, graphic])], {"graphic": "walker_a"})
	moving["move_route"] = move_route([[41, "walker_c", 0, 2, 0]])
	assert_array(StudioEvents.sheets_of([event([moving])])).is_equal(["walker_a", "walker_b", "walker_c"])
	assert_array(StudioEvents.effects_of([[command(209, [0, graphic])]])).is_equal(["door"])
