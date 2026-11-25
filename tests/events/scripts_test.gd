extends GdUnitTestSuite

# Event scripts (feature 22): GDScript a list, a condition or a route step
# runs in the project's script words. Events and lists built by the tests.

const World := preload("res://tests/support/walking_world.gd")
const Events := preload("res://tests/events/events_test.gd")
const Moves := preload("res://tests/events/moves_test.gd")
const _Run := preload("res://addons/wildgrass/events/event_run.gd")

var _world: World
var _player: WgWalker
var _sheet: Texture2D


func before_test() -> void:
	_world = World.new(self)
	_world.map({}, Vector2i(12, 12))
	_player = _world.walker(Vector2i(5, 6), WgPlayerInput.new())
	_world.maps.traveller = _player
	_sheet = ImageTexture.create_from_image(Image.create(64, 64, false, Image.FORMAT_RGBA8))


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _event(cell: Vector2i, pages: Array[WgEventPage], number := 1) -> WgEvent:
	var event := WgEvent.new()
	event.name = "Event%d" % number
	event.event_id = number
	event.walkers = _world.walkers
	event.position = _world.tiles.center_of(cell)
	for each in pages:
		each.sheet = _sheet
	event.pages = pages
	var sprite := WgCharacterSprite.new()
	sprite.name = "Sprite"
	event.add_child(sprite)
	_world.maps.current.entities_node().add_child(event)
	event.set_process(false)
	_world.events.refresh(event)
	return event


## An event running `commands` by itself, once.
func _autorun(commands: Array[WgEventCommand]) -> WgEvent:
	var ended := WgEventSetLocalSwitch.new()
	ended.letter = "D"
	commands.append(ended)
	return _event(Vector2i(2, 2), [Events.page(commands, {"trigger": WgEventPage.Trigger.AUTORUN}), Events.page([], {"condition": "local:D"})])


static func _script(source: String) -> WgEventScript:
	var made := WgEventScript.new()
	made.source = source
	return made


## Advances the game `frames` frames, a real frame each, the clock too.
func _run(frames := 10) -> void:
	for _frame in frames:
		_world.clock.advance(1.0 / 60.0)
		_world.events.advance(1.0 / 60.0)
		for walker in _world.walkers.all():
			walker.advance(1.0 / 60.0)
		await get_tree().process_frame


func _holds(source: String, event: WgEvent) -> bool:
	var condition := WgEventIf.new()
	condition.kind = WgEventIf.Kind.SCRIPT
	condition.source = source
	var run := _Run.new(_world.events)
	run.setup([] as Array[WgEventCommand], event)
	return condition.holds(run)


func _logged(text: String) -> Array:
	return _world.logged.filter(func(line: String) -> bool: return line.contains(text))


func test_a_script_runs_its_lines_with_the_engine_s_words() -> void:
	_world.story.set_value(&"variable_2", 4)
	var event := _autorun([_script("set_flag(&\"switch_1\")\nset_value(&\"variable_2\", value(&\"variable_2\") + 5)\nif this.event_id == 1 and character(-1) == player:\n\tset_local(\"B\")")] as Array[WgEventCommand])
	await _run(3)
	assert_bool(_world.story.has(&"switch_1")).is_true()
	assert_int(int(_world.story.value(&"variable_2"))).is_equal(9)
	assert_bool(_world.story.has(_world.story.local(event, &"B"))).is_true()


func test_the_list_waits_for_its_script_and_its_scripts_share_their_memory() -> void:
	_autorun([
		_script("memory.counted = 3\nawait wait(0.3)\nset_flag(&\"switch_3\")"),
		_script("set_value(&\"variable_1\", memory.counted + 1)"),
	] as Array[WgEventCommand])
	await _run(6)
	assert_bool(_world.story.has(&"switch_3")).is_false()
	assert_bool(_world.story.has_value(&"variable_1")).is_false()
	await _run(30)
	assert_bool(_world.story.has(&"switch_3")).is_true()
	assert_int(int(_world.story.value(&"variable_1"))).is_equal(4)


func test_a_script_that_does_not_compile_is_logged_once_with_its_place_and_skipped() -> void:
	_autorun([_script("func broken(:"), Events.switch_on()] as Array[WgEventCommand])
	await assert_error(func() -> void: await _run(3)).is_runtime_error("Parse Error: Expected parameter name.")
	assert_bool(_world.story.has(&"switch_1")).is_true()
	assert_array(_logged("Event1 page 1, command 1: its script does not compile")).has_size(1)
	await assert_error(func() -> void: _holds("((", null)).is_runtime_error("Parse Error: Expected grouping expression.")
	assert_bool(_holds("((", null)).is_false()
	assert_array(_logged("its script does not compile")).has_size(2)


func test_a_script_condition_answers_with_the_engine_s_words() -> void:
	var watcher := _event(Vector2i(5, 2), [Events.page()])
	_world.story.set_flag(&"switch_1")
	_world.story.set_value(&"variable_2", 4)
	assert_bool(_holds("flag(&\"switch_1\") and value(&\"variable_2\") > 3", watcher)).is_true()
	assert_bool(_holds("flag(&\"switch_1\") and not (value(&\"variable_2\") > 3)", watcher)).is_false()
	assert_bool(_holds("sees_player(4)", watcher)).is_true()
	assert_bool(_holds("player_in_line(2, Vector2i.DOWN)", watcher)).is_false()
	assert_bool(_holds("42", watcher)).is_false()
	assert_array(_logged("not true or false")).has_size(1)


func test_the_project_s_context_gives_its_own_words_a_wrong_one_is_logged() -> void:
	var path := _world.sandbox.write("game_context.gd", "extends WgScriptContext\n\nfunc greet() -> void:\n\tset_flag(&\"switch_9\")\n")
	_world.sandbox.set_setting(WgScriptContext.SETTING, path)
	_autorun([_script("greet()")] as Array[WgEventCommand])
	await _run(3)
	assert_bool(_world.story.has(&"switch_9")).is_true()
	var wrong := _world.sandbox.write("not_a_context.gd", "extends RefCounted\n")
	_world.sandbox.set_setting(WgScriptContext.SETTING, wrong)
	assert_bool(_holds("flag(&\"switch_9\")", null)).is_true()
	assert_array(_logged("is not a script extending WgScriptContext")).has_size(1)


func test_a_route_step_runs_its_script_one_not_translated_is_reported() -> void:
	var page := Events.page()
	page.move_type = WgEventPage.MoveType.ROUTE
	page.move_frequency = 6
	page.move_route = Moves.route([WgMoveStep.Kind.CALL, WgMoveStep.Kind.CALL], true)
	page.move_route.steps[0].call = "set_flag(&\"switch_6\")\nset_value(&\"variable_6\", this.event_id)"
	page.move_route.steps[1].original = "Mod.wave(1)"
	_event(Vector2i(2, 2), [page] as Array[WgEventPage], 7)
	await _run(3)
	assert_bool(_world.story.has(&"switch_6")).is_true()
	assert_int(int(_world.story.value(&"variable_6"))).is_equal(7)
	assert_array(_logged("a route's call")).has_size(1)
