extends GdUnitTestSuite

# Studio's words for events' scripts (feature 22): scripts as the importer
# writes them, run in a world whose script context is Studio's.

const World := preload("res://tests/support/walking_world.gd")
const Events := preload("res://tests/events/events_test.gd")
const T := preload("res://tests/support/tile_builder.gd")
const _Run := preload("res://addons/wildgrass/events/event_run.gd")
const _Studio := preload("res://addons/wildgrass/studio/studio.gd")

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
