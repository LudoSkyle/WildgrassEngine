extends GdUnitTestSuite

# Studio's words for events' scripts (feature 22): scripts as the importer
# writes them, run in a world whose script context is Studio's.

const World := preload("res://tests/support/walking_world.gd")
const Events := preload("res://tests/events/events_test.gd")
const T := preload("res://tests/support/tile_builder.gd")
const _Run := preload("res://addons/wildgrass/events/event_run.gd")
const _Studio := preload("res://addons/wildgrass/studio/studio.gd")
const _PokemonMaker := preload("res://addons/wildgrass/party/pokemon_maker.gd")


## A maker whose draws the test writes, in order; none left: 0.
class ScriptedMaker extends _PokemonMaker:
	var rolls: Array[int] = []

	func draw(_from: int, _to: int) -> int:
		return rolls.pop_front() if not rolls.is_empty() else 0

var _world: World
var _player: WgWalker
var _sheet: Texture2D


func before_test() -> void:
	_world = World.new(self, {"numbers": {"19": "hub"}})
	_world.sandbox.set_setting(WgScriptContext.SETTING, _Studio.SCRIPT_CONTEXT)
	_world.map({Vector2i(9, 9): T.WALL}, Vector2i(12, 12))
	_player = _world.walker(Vector2i(5, 6), WgPlayerInput.new())
	_player.facing = Vector2i.UP
	_world.maps.traveller = _player
	_sheet = ImageTexture.create_from_image(Image.create(64, 64, false, Image.FORMAT_RGBA8))


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _event(cell: Vector2i, number := 1, facing := Vector2i.DOWN) -> WgEvent:
	var event := WgEvent.new()
	event.name = "Event%d" % number
	event.event_id = number
	event.walkers = _world.walkers
	event.position = _world.tiles.center_of(cell)
	var page := Events.page([], {"direction": facing})
	page.sheet = _sheet
	event.pages = [page]
	var sprite := WgCharacterSprite.new()
	sprite.name = "Sprite"
	event.add_child(sprite)
	_world.maps.current.entities_node().add_child(event)
	event.set_process(false)
	_world.events.refresh(event)
	return event


## Runs `source` as a list of `event` would, and waits for it.
func _script(source: String, event: WgEvent = null) -> void:
	var run := _Run.new(_world.events)
	run.setup([] as Array[WgEventCommand], event)
	await run.run_script(source)


func _holds(source: String, event: WgEvent) -> bool:
	var run := _Run.new(_world.events)
	run.setup([] as Array[WgEventCommand], event)
	return run.check_script(source)


func test_variables_and_switches_by_number() -> void:
	await _script("set_gv(26, 3)\nset_gv(26, gv(26) + 2)\nset_gs(4, gv(26) == 5)")
	assert_int(int(_world.story.value(&"variable_26"))).is_equal(5)
	assert_bool(_world.story.has(&"switch_4")).is_true()
	assert_bool(_holds("gs(4) and not gs(5) and gv(7) == 0", null)).is_true()


func test_characters_as_studio_sees_them_from_their_map_s_origin() -> void:
	var event := _event(Vector2i(2, 3), 3)
	assert_bool(_holds("gp.x == 5 and gp.y == 6 and gp.direction == 8", event)).is_true()
	assert_bool(_holds("ge().x == 2 and get_character(3).y == 3 and ge(3).direction == 2 and get_character(-1) != null", event)).is_true()
	assert_bool(_holds("ge(9) == null", event)).is_true()
	await _script("gp.moveto(1, 1)\ngp.direction = 6\nge().moveto(4, 4)", event)
	assert_that(_player.cell).is_equal(Vector2i(1, 1))
	assert_that(_player.facing).is_equal(Vector2i.RIGHT)
	assert_that(event.cell).is_equal(Vector2i(4, 4))


func test_characters_are_counted_from_their_map_s_origin_not_the_world_s() -> void:
	_world.maps.current.position = Vector2(32, 16)
	_player.place_at(Vector2i(7, 7))
	var event := _event(Vector2i(2, 3), 3)
	assert_bool(_holds("gp.x == 5 and gp.y == 6 and ge().x == 2 and ge().y == 3", event)).is_true()
	await _script("gp.moveto(1, 1)", event)
	assert_that(_player.cell).is_equal(Vector2i(3, 2))


func test_local_switches_of_this_event_another_one_and_a_map_by_its_number() -> void:
	_world.maps.current_id = &"field"
	var event := _event(Vector2i(2, 3), 3)
	await _script("set_self_switch(true, \"A\")\nset_self_switch(true, \"B\", 7)\nset_self_switch(true, \"C\", 1, 19)\nset_self_switch(true, \"D\", 0, 19)", event)
	assert_bool(_world.story.has(_world.story.local(event, &"A"))).is_true()
	assert_bool(_world.story.has(&"hub/event_1:C")).is_true()
	assert_bool(_world.story.has(&"hub/event_3:D")).is_true()
	assert_bool(_holds("get_self_switch(\"B\", 7) and get_self_switch(\"C\", 1, 19) and not get_self_switch(\"D\")", event)).is_true()
	await _script("set_self_switch(true, \"A\", 1, 42)", event)
	assert_array(_world.logged.filter(func(line: String) -> bool: return line.contains("no map numbered 42"))).has_size(1)


func test_seeing_the_player_as_studio_s_words_say() -> void:
	var watcher := _event(Vector2i(5, 2), 1)
	assert_bool(_holds("player_spotted(4) and trainer_spotted(4) and not player_spotted(3)", watcher)).is_true()
	assert_bool(_holds("player_spotted_directional({up = 1, down = 4})", watcher)).is_true()
	assert_bool(_holds("player_spotted_directional({up = 4, down = 2})", watcher)).is_false()
	assert_bool(_holds("detect_player(4, &\"down\") and detect_player(4, 2) and not detect_player(4, &\"up\")", watcher)).is_true()
	assert_bool(_holds("detect_player_rect(0, 4) and detect_player_circle(16) and not detect_player_circle(15)", watcher)).is_true()
	_player.place_at(Vector2i(6, 4))
	assert_bool(_holds("player_spotted_rect(4, 1)", watcher)).is_true()
	assert_int(_world.events.get(&"_common_wanted")).is_equal(2)


func test_an_event_deleted_forever_stays_deleted_when_its_map_is_built_again() -> void:
	var event := _event(Vector2i(2, 3), 3)
	var other := _event(Vector2i(4, 3), 4)
	await _script("delete_this_event_forever()\nset_gv(1, 1 if delete_event_forever(4) else 0)\nset_gv(2, 1 if delete_event(8) else 0)", event)
	assert_bool(event.erased).is_true()
	assert_bool(other.erased).is_true()
	assert_int(int(_world.story.value(&"variable_1"))).is_equal(1)
	assert_int(int(_world.story.value(&"variable_2"))).is_equal(0)
	event.erased = false
	other.erased = false
	_world.hooks.run(&"map_built", [_world.maps.current, &""])
	assert_bool(event.erased).is_true()
	assert_bool(other.erased).is_true()


func test_text_variables_fill_messages_until_reset() -> void:
	await _script("text.set_variable(\"[TEAM]\", \"Fire\")\ntext.set_variable(\"[PKM1]\", 7)")
	assert_str(_world.texts.format("{team} {pkm1}")).is_equal("Fire 7")
	await _script("text.unset_variable(\"[PKM1]\")")
	assert_str(_world.texts.format("{team} {pkm1}")).is_equal("Fire {pkm1}")
	await _script("text.reset_variables()")
	assert_str(_world.texts.format("{team}")).is_equal("{team}")


func test_the_studio_layer_names_its_context_unless_the_game_names_one() -> void:
	_world.sandbox.set_setting(WgScriptContext.SETTING, "")
	var studio: Object = _Studio.new(World.Paths.new(false), _world.logger, _world.config, _world.hooks)
	studio.call(&"name_script_context")
	assert_str(str(ProjectSettings.get_setting(WgScriptContext.SETTING))).is_equal(_Studio.SCRIPT_CONTEXT)
	studio.call(&"uninstall")
	assert_str(str(ProjectSettings.get_setting(WgScriptContext.SETTING))).is_empty()
	_world.sandbox.set_setting(WgScriptContext.SETTING, "res://game_context.gd")
	var other: Object = _Studio.new(World.Paths.new(false), _world.logger, _world.config, _world.hooks)
	other.call(&"name_script_context")
	assert_str(str(ProjectSettings.get_setting(WgScriptContext.SETTING))).is_equal("res://game_context.gd")
	other.call(&"uninstall")


## Pikachu (25) and Eevee (133), two forms each, and the moves they learn.
func _party_data() -> void:
	for pair: Array in [[&"pikachu", 25, "Pikachu"], [&"eevee", 133, "Eevee"]]:
		var species := WgSpecies.new()
		species.id = pair[0]
		species.number = pair[1]
		species.name = pair[2]
		for number in 2:
			var form := WgSpeciesForm.new()
			form.form = number
			form.base_stats.assign({&"hp": 35, &"attack": 55, &"defense": 40, &"speed": 90, &"special_attack": 50, &"special_defense": 50})
			form.abilities.assign([&"static", &"static", &"lightning_rod"])
			form.female_rate = 50.0
			form.moves.assign([
				{"move": &"tackle", "how": &"level", "level": 1}, {"move": &"tail_whip", "how": &"level", "level": 1},
				{"move": &"quick_attack", "how": &"level", "level": 5},
			])
			species.forms.append(form)
		_world.species.register(species)
	for id: StringName in [&"tackle", &"tail_whip", &"quick_attack", &"thunderbolt", &"growl"]:
		var move := WgMove.new()
		move.id = id
		move.pp = 20
		_world.moves.register(move)
	for pair: Array in [[&"hardy", 0], [&"modest", 15]]:
		var nature := WgNature.new()
		nature.id = pair[0]
		nature.number = pair[1]
		_world.natures.register(nature)
	_world.trainer.reset()
	_world.pokemon.reset()


func _logged(text: String) -> Array:
	return _world.logged.filter(func(line: String) -> bool: return line.contains(text))


func test_actors_as_studio_s_scripts_see_the_party() -> void:
	_party_data()
	_world.party.add(_world.pokemon.make(&"pikachu", 10, {"nickname": "Sparky"}))
	var egg := _world.pokemon.make(&"eevee", 1)
	egg.steps_left = 100
	_world.party.add(egg)
	assert_bool(_holds("actors.size() == 2 and not actors.empty() and actors.at(0).db_symbol == &\"pikachu\" and actors.at(-1).egg() and actors.at(2) == null", null)).is_true()
	assert_bool(_holds("actors.at(0).name == \"Pikachu\" and actors.at(0).given_name == \"Sparky\" and actors.at(0).id == 25 and actors.at(0).level == 10", null)).is_true()
	assert_bool(_holds("actors.any(func(p): return p.egg()) and actors.find(func(p): return p.egg()).db_symbol == &\"eevee\" and actors.index(func(p): return p.dead()) == 1", null)).is_true()
	assert_bool(_holds("actors.count() == 2 and actors.count(func(p): return p.level == 10) == 1 and actors.find(func(p): return p.level == 3) == null and actors.index(func(p): return false) == -1", null)).is_true()
	await _script("actors.at(0).form = 1\nactors.at(0).loyalty = 300\nactors.at(0).given_name = \"Pikachu\"\nactors.at(1).form = 9\nactors.at(0).shiny = true")
	var pikachu := _world.party.at(0)
	assert_array([pikachu.form, pikachu.friendship, pikachu.nickname, pikachu.is_shiny(), egg.form]).is_equal([1, 255, "", true, 0])
	await _script("actors.at(0).given_name = \"Volt\"\nactors.at(0).hp = 0")
	assert_str(pikachu.nickname).is_equal("Volt")
	assert_bool(_holds("actors.at(0).dead() and actors.at(0).hp == 0 and actors.at(0).max_hp > 0 and actors.at(-2).loyalty == 255", null)).is_true()
	pikachu.status = &"burn"
	await _script("actors.at(0).cure()")
	assert_that(pikachu.status).is_equal(&"")


func test_the_party_s_words_as_studio_calls_them() -> void:
	_world.sandbox.write_json("config/party.json", {"size": 2})
	_party_data()
	assert_bool(_holds("pokemon_party.empty() and pokemon_party.size() == 0 and not pokemon_party.full()", null)).is_true()
	_world.party.add(_world.pokemon.make(&"pikachu", 10))
	_world.party.add(_world.pokemon.make(&"eevee", 10))
	_world.party.at(0).set_hp(0)
	assert_bool(_holds("pokemon_party.full() and pokemon_party.pokemon_alive() == 1 and pokemon_party.pokemon_alive(1) == 0", null)).is_true()
	await _script("pokemon_party.heal_party()")
	assert_int(_world.party.alive_count()).is_equal(2)


func test_a_pokemon_from_studio_s_hash() -> void:
	_party_data()
	await _script("add_pokemon(pokemon_from_hash({id = &\"pikachu\", level = 30, shiny = true, form = 1, given_name = \"Volt\", "
		+ "captured_with = &\"great_ball\", ball = &\"ultra_ball\", captured_at = 5, captured_level = 2, trainer_name = \"Bimbo\", "
		+ "trainer_id = 45218, gender = 1, nature = &\"modest\", stats = [1, 2, 3, 4, 5, 6], bonus = [10, 20], conditions = [0, 0, 7], "
		+ "item = &\"light_ball\", ability = &\"lightning_rod\", moves = [&\"thunderbolt\", \"tackle\", 0, &\"growl\"], loyalty = 99, form_extra = null}))")
	var made := _world.party.at(0)
	assert_array([made.species, made.level, made.is_shiny(), made.form, made.nickname, made.ball, made.caught_at, made.caught_level]) \
		.is_equal([&"pikachu", 30, true, 1, "Volt", &"great_ball", 5, 2])
	assert_array([made.trainer_name, made.trainer_id, made.caught_by_player, made.gender, made.nature, made.held_item, made.ability, made.friendship]) \
		.is_equal(["Bimbo", 45218, false, WgPokemon.Gender.MALE, 1, &"light_ball", &"lightning_rod", 99])
	assert_dict(made.ivs).is_equal({&"hp": 1, &"attack": 2, &"defense": 3, &"speed": 4, &"special_attack": 5, &"special_defense": 6})
	assert_dict(made.evs).is_equal({&"hp": 10, &"attack": 20, &"defense": 0, &"speed": 0, &"special_attack": 0, &"special_defense": 0})
	assert_int(made.conditions[&"cute"]).is_equal(7)
	assert_array(made.moves.map(func(slot: WgMoveSlot) -> StringName: return slot.move)).is_equal([&"thunderbolt", &"tail_whip", &"quick_attack", &"growl"])
	await _script("add_pokemon(pokemon_from_hash({id = 25, level = 5, shiny = true, no_shiny = true, ball = &\"ultra_ball\", captured_in = 17}))")
	assert_array([_world.party.at(1).species, _world.party.at(1).is_shiny(), _world.party.at(1).ball]).is_equal([&"pikachu", false, &"ultra_ball"])
	assert_array(_logged("not handled yet: the key 'captured_in' of a Pokémon's hash")).has_size(1)
	assert_bool(_holds("pokemon_from_hash({id = &\"mew\", level = 5}) == null", null)).is_true()
	assert_array(_logged("no species 'mew' to make")).has_size(1)


func test_add_pokemon_as_studio_adds_one() -> void:
	_world.sandbox.write_json("config/party.json", {"size": 5})
	_party_data()
	_world.story.set_flag(&"switch_9")
	await _script("add_pokemon(&\"pikachu\", 5, true)")
	assert_bool(_world.story.has(&"switch_9")).is_false()
	await _script("add_pokemon(133, 6, 0)\nadd_pokemon(&\"pikachu\", 7, 1)\nadd_pokemon(&\"pikachu\", 0)\nadd_pokemon(&\"pikachu\", 101)")
	assert_array(_world.party.all().map(func(made: WgPokemon) -> Array: return [made.species, made.level, made.is_shiny()])) \
		.is_equal([[&"pikachu", 5, true], [&"eevee", 6, false], [&"pikachu", 7, true]])
	assert_array(_logged("level 0 is out of bounds")).has_size(1)
	assert_array(_logged("level 101 is out of bounds")).has_size(1)
	await _script("add_specific_pokemon({id = &\"eevee\", level = 8})\nadd_rename_pokemon(&\"pikachu\", 9)\nset_gs(3, add_pokemon(&\"eevee\", 4) == null)")
	assert_array(_world.party.all().slice(3).map(func(made: WgPokemon) -> int: return made.level)).is_equal([8, 9])
	assert_array(_logged("not handled yet: the naming screen")).has_size(1)
	assert_bool(_world.story.has(&"switch_3")).is_true()
	assert_array(_logged("eevee not added: the party is full")).has_size(1)


func test_a_choice_asked_by_the_next_message_into_its_variable() -> void:
	var words := Translation.new()
	words.locale = TranslationServer.get_locale()
	words.add_message("dialogs.3.147", "South")
	TranslationServer.add_translation(words)
	var event := _event(Vector2i(5, 5), 1)
	var first := WgEventScript.new()
	first.source = "choice(26, -1, [\"North\", \"3, 147 South\", ext_text(3, 148)])"
	var asked := WgEventSay.new()
	asked.text = "Where?"
	var second := WgEventScript.new()
	second.source = "choice(27, 2, \"Yes\", \"\\\\c[18]No\")"
	var again := WgEventSay.new()
	again.text = "Sure?"
	event.pages[0].commands.assign([first, asked, second, again])
	_world.events.start(event)
	for _frame in 3:
		_world.events.advance(1.0 / 60.0)
	_world.dialogue.box.set_process(false)
	_world.dialogue.box.advance(10.0)
	assert_bool(_holds("ext_text(3, 147) == \"South\"", null)).is_true()
	TranslationServer.remove_translation(words)
	var buttons: Array = _world.dialogue.box.get(&"_buttons")
	assert_array(buttons.map(func(button: Button) -> String: return button.text)).is_equal(["North", "South", "{text:3:148}"])
	assert_str(_world.dialogue.box.shown_text()).is_equal("Where?")
	for action: String in ["ui_cancel", "ui_down", "ui_accept"]:
		_press(action)
	for _frame in 3:
		_world.events.advance(1.0 / 60.0)
	assert_int(int(_world.story.value(&"variable_26"))).is_equal(2)
	_world.dialogue.box.advance(10.0)
	var asked_again: Array = _world.dialogue.box.get(&"_buttons")
	assert_array(asked_again.map(func(button: Button) -> String: return button.text)).is_equal(["Yes", "No"])
	_press("ui_cancel")
	for _frame in 3:
		_world.events.advance(1.0 / 60.0)
	assert_int(int(_world.story.value(&"variable_27"))).is_equal(2)
	assert_array(_logged("not handled yet: Studio's colors in a script's text")).has_size(1)


func test_ext_text_reads_studio_s_own_text_when_the_game_has_no_key() -> void:
	assert_bool(_holds("ext_text(3, 148) == \"{text:3:148}\"", null)).is_true()


func _press(action: String) -> void:
	var pressed := InputEventAction.new()
	pressed.action = action
	pressed.pressed = true
	_world.screens.handle_input(pressed)


func test_add_pokemon_s_shiny_chances_as_studio_draws_them() -> void:
	_party_data()
	var maker := ScriptedMaker.new(_world.logger, _world.config, _world.species, _world.natures, _world.moves, _world.bag, _world.trainer, _world.zones)
	maker.reset()
	_world.events.pokemon = maker
	# A code of 0 is shiny: 0 never is; 3 is one chance in three, drawn first.
	maker.rolls.assign([0])
	await _script("add_pokemon(&\"eevee\", 5, 0)")
	maker.rolls.assign([0, 0xFFFF])
	await _script("add_pokemon(&\"eevee\", 5, 3)")
	maker.rolls.assign([1, 0xFFFF])
	await _script("add_pokemon(&\"eevee\", 5, 3)")
	maker.rolls.assign([0xFFFF])
	await _script("add_pokemon(&\"eevee\", 5, true)")
	assert_array(_world.party.all().map(func(made: WgPokemon) -> bool: return made.is_shiny())).is_equal([false, true, false, true])
