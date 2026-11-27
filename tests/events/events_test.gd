extends GdUnitTestSuite

# Events (feature 21): pages, how they start, and the lists they run. Maps,
# events and common events are built by the tests.

const World := preload("res://tests/support/walking_world.gd")

const STEP := 1.0 / 60.0

var _world: World
var _player: WgWalker
var _sheet: Texture2D


func before_test() -> void:
	_world = World.new(self)
	_world.map({}, Vector2i(12, 12))
	_player = _world.walker(Vector2i(5, 5), WgPlayerInput.new())
	_player.facing = Vector2i.UP
	_world.maps.traveller = _player
	_sheet = ImageTexture.create_from_image(Image.create(64, 64, false, Image.FORMAT_RGBA8))


func after_test() -> void:
	for action: String in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept"]:
		Input.action_release(action)
	_world.root.free()
	_world.cleanup()


static func page(commands: Array[WgEventCommand] = [], options := {}) -> WgEventPage:
	var made := WgEventPage.new()
	made.commands = commands
	made.condition = options.get("condition", "")
	made.trigger = options.get("trigger", WgEventPage.Trigger.ACTION)
	made.through = options.get("through", false)
	made.direction = options.get("direction", Vector2i.DOWN)
	return made


static func switch_on(number := 1, on := true) -> WgEventSetSwitches:
	var command := WgEventSetSwitches.new()
	command.first = number
	command.last = number
	command.on = on
	return command


static func variable(number: int, operation: WgEventSetVariables.Operation, amount: int, indent := 0) -> WgEventSetVariables:
	var command := WgEventSetVariables.new()
	command.first = number
	command.last = number
	command.operation = operation
	command.value = amount
	command.indent = indent
	return command


static func at(command: WgEventCommand, indent: int) -> WgEventCommand:
	command.indent = indent
	return command


## An event numbered `number` on `cell` of the map shown, `shown` giving it a
## sheet on each page.
func _event(cell: Vector2i, pages: Array[WgEventPage], shown := true, number := 1) -> WgEvent:
	var event := WgEvent.new()
	event.name = "Event%d" % number
	event.event_id = number
	event.walkers = _world.walkers
	event.position = _world.tiles.center_of(cell)
	for each in pages:
		each.sheet = _sheet if shown else null
	event.pages = pages
	var sprite := WgCharacterSprite.new()
	sprite.name = "Sprite"
	event.add_child(sprite)
	_world.maps.current.entities_node().add_child(event)
	event.set_process(false)
	_world.events.refresh(event)
	return event


func _advance(frames := 1) -> void:
	for _frame in frames:
		_world.events.advance(STEP)


func _flag(number := 1) -> bool:
	return _world.story.has(StringName("switch_%d" % number))


func _value(number: int) -> int:
	return int(_world.story.value(StringName("variable_%d" % number)))


func test_an_event_shows_its_last_page_whose_condition_holds_chosen_again_as_the_story_changes() -> void:
	var first := page()
	var second := page([], {"condition": "switch_2"})
	var third := page([], {"condition": "switch_3"})
	var event := _event(Vector2i(5, 3), [first, second, third])
	assert_object(event.page).is_same(first)
	_world.story.set_flag(&"switch_3")
	assert_object(event.page).is_same(first)
	_advance()
	assert_object(event.page).is_same(third)
	_world.story.set_flag(&"switch_2")
	_advance()
	assert_object(event.page).is_same(third)


func test_no_page_hides_it_it_neither_blocks_nor_starts_but_stays() -> void:
	var event := _event(Vector2i(5, 4), [page([switch_on()], {"condition": "switch_9"})])
	assert_object(event.page).is_null()
	assert_bool(event.get_node("Sprite").visible).is_false()
	assert_object(_world.walkers.at(Vector2i(5, 4))).is_null()
	_world.walkers.interact(_player)
	_advance(3)
	assert_bool(_flag()).is_false()
	assert_bool(is_instance_valid(event)).is_true()


func test_it_blocks_when_it_shows_and_is_not_through() -> void:
	_event(Vector2i(5, 4), [page()], true, 1)
	_event(Vector2i(6, 4), [page([], {"through": true})], true, 2)
	_event(Vector2i(7, 4), [page()], false, 3)
	assert_object(_world.walkers.at(Vector2i(5, 4))).is_not_null()
	assert_object(_world.walkers.at(Vector2i(6, 4))).is_null()
	assert_object(_world.walkers.at(Vector2i(7, 4))).is_null()


func test_the_action_key_starts_the_event_faced_which_turns_to_the_player_then_back() -> void:
	var event := _event(Vector2i(5, 4), [page([switch_on()], {"direction": Vector2i.LEFT})])
	assert_that(event.facing).is_equal(Vector2i.LEFT)
	_world.walkers.interact(_player)
	assert_bool(_world.walkers.is_busy(_player)).is_true()
	_advance()
	assert_bool(_flag()).is_true()
	assert_that(event.facing).is_equal(Vector2i.LEFT)
	assert_bool(_world.walkers.is_busy(_player)).is_false()


func test_while_a_list_runs_the_event_faces_the_player_and_the_player_is_held() -> void:
	var wait := WgEventWait.new()
	wait.seconds = 0.5
	var event := _event(Vector2i(5, 4), [page([wait, switch_on()], {"direction": Vector2i.LEFT})])
	_world.walkers.interact(_player)
	_advance()
	assert_that(event.facing).is_equal(Vector2i.DOWN)
	assert_bool(_world.walkers.is_busy(_player)).is_true()
	_advance(40)
	assert_bool(_flag()).is_true()
	assert_that(event.facing).is_equal(Vector2i.LEFT)
	assert_bool(_world.walkers.is_busy(_player)).is_false()


func test_a_touch_event_starts_stepped_on_or_bumped_into() -> void:
	var under := _event(Vector2i(5, 4), [page([switch_on(1)], {"trigger": WgEventPage.Trigger.TOUCH})], false, 1)
	assert_bool(under.is_stepped_on()).is_true()
	_player.step(Vector2i.UP)
	_player.advance(1.0)
	assert_that(_player.cell).is_equal(Vector2i(5, 4))
	_advance()
	assert_bool(_flag(1)).is_true()
	var wall := _event(Vector2i(5, 3), [page([switch_on(2)], {"trigger": WgEventPage.Trigger.TOUCH})], true, 2)
	assert_bool(wall.is_stepped_on()).is_false()
	assert_bool(_player.step(Vector2i.UP)).is_false()
	_advance()
	assert_bool(_flag(2)).is_true()
	assert_that(_player.cell).is_equal(Vector2i(5, 4))


func test_an_action_event_under_the_player_starts_only_from_its_cell() -> void:
	_event(Vector2i(5, 5), [page([switch_on()])], false)
	_world.walkers.interact(_player)
	_advance()
	assert_bool(_flag()).is_true()


func test_an_autorun_runs_again_until_its_page_changes_holding_the_player() -> void:
	var set_local := WgEventSetLocalSwitch.new()
	var wait := WgEventWait.new()
	wait.seconds = 0.1
	var event := _event(Vector2i(2, 2), [
		page([variable(1, WgEventSetVariables.Operation.ADD, 1), wait, set_local] as Array[WgEventCommand], {"trigger": WgEventPage.Trigger.AUTORUN}),
		page([], {"condition": "local:A"}),
	])
	_advance()
	assert_bool(_world.walkers.is_busy(_player)).is_true()
	_advance(20)
	assert_int(_value(1)).is_equal(1)
	assert_object(event.page).is_same(event.pages[1])
	assert_bool(_world.walkers.is_busy(_player)).is_false()


func test_a_parallel_list_runs_beside_and_again_and_stops_with_its_page() -> void:
	var wait := WgEventWait.new()
	wait.seconds = 0.1
	var event := _event(Vector2i(2, 2), [
		page([variable(1, WgEventSetVariables.Operation.ADD, 1), wait] as Array[WgEventCommand], {"trigger": WgEventPage.Trigger.PARALLEL}),
		page([], {"condition": "switch_5"}),
	])
	_advance(20)
	assert_int(_value(1)).is_between(2, 4)
	assert_bool(_world.walkers.is_busy(_player)).is_false()
	_world.story.set_flag(&"switch_5")
	_advance()
	var stopped := _value(1)
	_advance(20)
	assert_int(_value(1)).is_equal(stopped)
	assert_object(event.page).is_same(event.pages[1])


func test_a_list_goes_on_after_its_event_changes_page() -> void:
	var wait := WgEventWait.new()
	wait.seconds = 0.2
	_event(Vector2i(5, 4), [page([switch_on(2), wait, switch_on(1)]), page([], {"condition": "switch_2"})])
	_world.walkers.interact(_player)
	_advance(30)
	assert_bool(_flag(1)).is_true()


func test_conditions_branch_and_else() -> void:
	var on := WgEventIf.new()
	on.number = 7
	var off := WgEventIf.new()
	off.number = 7
	off.on = false
	var compare := WgEventIf.new()
	compare.kind = WgEventIf.Kind.VARIABLE
	compare.number = 1
	compare.comparison = WgEventIf.Comparison.AT_LEAST
	compare.value = 2
	compare.against_variable = true
	var commands: Array[WgEventCommand] = [
		variable(1, WgEventSetVariables.Operation.SET, 5), variable(2, WgEventSetVariables.Operation.SET, 5),
		on, at(switch_on(10), 1), at(WgEventBlockEnd.new(), 1), WgEventElse.new(), at(switch_on(11), 1), at(WgEventBlockEnd.new(), 1), WgEventBlockEnd.new(),
		off, at(switch_on(12), 1), at(WgEventBlockEnd.new(), 1), WgEventBlockEnd.new(),
		compare, at(switch_on(13), 1), at(WgEventBlockEnd.new(), 1), WgEventBlockEnd.new(),
	]
	_event(Vector2i(5, 4), [page(commands)])
	_world.walkers.interact(_player)
	_advance()
	assert_array([_flag(10), _flag(11), _flag(12), _flag(13)]).is_equal([false, true, true, true])


func test_a_loop_repeats_until_a_break_and_a_jump_goes_to_its_label() -> void:
	var enough := WgEventIf.new()
	enough.kind = WgEventIf.Kind.VARIABLE
	enough.number = 1
	enough.comparison = WgEventIf.Comparison.AT_LEAST
	enough.value = 3
	enough.indent = 1
	var label := WgEventLabel.new()
	label.label = "end"
	var jump := WgEventJump.new()
	jump.label = "end"
	var commands: Array[WgEventCommand] = [
		WgEventLoop.new(), variable(1, WgEventSetVariables.Operation.ADD, 1, 1), enough, at(WgEventBreak.new(), 2), at(WgEventBlockEnd.new(), 2), at(WgEventBlockEnd.new(), 1), at(WgEventBlockEnd.new(), 1), WgEventRepeat.new(),
		jump, switch_on(1), label, switch_on(2),
	]
	_event(Vector2i(5, 4), [page(commands)])
	_world.walkers.interact(_player)
	_advance()
	assert_int(_value(1)).is_equal(3)
	assert_array([_flag(1), _flag(2)]).is_equal([false, true])


func test_a_loop_that_never_waits_gives_the_frame_back() -> void:
	var commands: Array[WgEventCommand] = [WgEventLoop.new(), variable(1, WgEventSetVariables.Operation.ADD, 1, 1), at(WgEventBlockEnd.new(), 1), WgEventRepeat.new()]
	_event(Vector2i(5, 4), [page(commands)])
	_world.walkers.interact(_player)
	_advance()
	assert_int(_value(1)).is_between(1, WgEventCommand._Run.MAX_COMMANDS)


func test_variables_take_each_operation_floored_and_kept_within_bounds() -> void:
	var Op := WgEventSetVariables.Operation
	var other := variable(3, Op.SET, 0)
	other.operand = WgEventSetVariables.Operand.VARIABLE
	other.value = 1
	var commands: Array[WgEventCommand] = [
		variable(1, Op.SET, -7), variable(2, Op.SET, -7), variable(1, Op.DIVIDE, 2), variable(2, Op.MODULO, 3), other,
		variable(4, Op.SET, 99999998), variable(4, Op.ADD, 5), variable(5, Op.SET, 4), variable(5, Op.DIVIDE, 0), variable(5, Op.MULTIPLY, 3), variable(5, Op.SUBTRACT, 1),
	]
	_event(Vector2i(5, 4), [page(commands)])
	_world.walkers.interact(_player)
	_advance()
	assert_array([_value(1), _value(2), _value(3), _value(4), _value(5)]).is_equal([-4, 2, -4, 99999999, 11])


func test_a_local_switch_belongs_to_its_event_and_erasing_hides_it() -> void:
	var commands: Array[WgEventCommand] = [WgEventSetLocalSwitch.new(), WgEventErase.new(), switch_on()]
	var event := _event(Vector2i(5, 4), [page(commands)])
	_world.walkers.interact(_player)
	_advance()
	assert_bool(_world.story.has(_world.story.local(event, &"A"))).is_true()
	assert_bool(event.erased).is_true()
	assert_object(event.page).is_null()
	_advance()
	assert_bool(_flag()).is_true()


func test_a_common_event_is_called_and_runs_by_itself_while_its_switch_is_on() -> void:
	_world.sandbox.set_setting("wildgrass/paths/common_events", _world.sandbox.root + "common_events/")
	DirAccess.make_dir_recursive_absolute(_world.sandbox.root + "common_events")
	var called := WgCommonEvent.new()
	called.commands = [switch_on(2)]
	ResourceSaver.save(called, _world.sandbox.root + "common_events/4.tres")
	var by_itself := WgCommonEvent.new()
	by_itself.trigger = WgCommonEvent.Trigger.AUTORUN
	by_itself.switch = &"switch_8"
	by_itself.commands = [variable(1, WgEventSetVariables.Operation.ADD, 1), switch_on(8, false)]
	ResourceSaver.save(by_itself, _world.sandbox.root + "common_events/9.tres")
	var call := WgEventCallCommon.new()
	call.common_event = 4
	var missing := WgEventCallCommon.new()
	missing.common_event = 77
	_event(Vector2i(5, 4), [page([call, switch_on(3), missing] as Array[WgEventCommand])])
	_world.walkers.interact(_player)
	_advance(2)
	assert_array([_flag(2), _flag(3)]).is_equal([true, true])
	assert_array(_world.logged.filter(func(line: String) -> bool: return line.contains("common event 77"))).has_size(1)
	_world.story.set_flag(&"switch_8")
	_advance(3)
	assert_int(_value(1)).is_equal(1)


func test_a_command_with_no_class_yet_is_told_once_and_the_list_goes_on() -> void:
	var raw := WgEventRaw.new()
	raw.code = 999
	var commands: Array[WgEventCommand] = [raw, raw, switch_on()]
	_event(Vector2i(5, 4), [page(commands)])
	_world.walkers.interact(_player)
	_advance()
	assert_bool(_flag()).is_true()
	assert_array(_world.logged.filter(func(line: String) -> bool: return line.contains("command 999"))).has_size(1)


func test_a_game_started_or_loaded_keeps_no_list_nor_route_of_the_one_before() -> void:
	var loop := WgEventLoop.new()
	var moving := WgEventMoveRoute.new()
	moving.character = 0
	moving.route = WgMoveRoute.new()
	moving.route.repeat = true
	var step := WgMoveStep.new()
	step.kind = WgMoveStep.Kind.TURN_LEFT
	moving.route.steps.append(step)
	var wait := WgEventWait.new()
	wait.seconds = 0.1
	var event := _event(Vector2i(5, 4), [page([moving, loop, at(wait, 1), at(WgEventRepeat.new(), 0)])])
	_world.walkers.interact(_player)
	_advance(3)
	assert_bool(_world.events.main.is_running()).is_true()
	assert_bool(_world.events.any_forced_route()).is_true()
	_world.events.stop_all()
	assert_bool(_world.events.main.is_running()).is_false()
	assert_bool(_world.events.any_forced_route()).is_false()
	assert_bool(_world.walkers.is_scripted(event)).is_false()
	assert_bool(event.is_locked()).is_false()
	assert_bool(_world.walkers.is_busy(_player)).is_false()
	assert_dict(_world.events.lists_state()).is_empty()


func test_a_list_goes_on_after_a_warp_frees_its_map() -> void:
	var wait := WgEventWait.new()
	wait.seconds = 0.2
	_event(Vector2i(5, 4), [page([wait, switch_on()])])
	_world.walkers.interact(_player)
	_advance()
	var old := _world.maps.current
	_player.reparent(_world.map({}, Vector2i(6, 6)).entities_node())
	old.free()
	_advance(30)
	assert_bool(_flag()).is_true()
	assert_bool(_world.walkers.is_busy(_player)).is_false()


func test_a_break_leaves_only_the_loop_it_is_in() -> void:
	var inner_done := WgEventIf.new()
	inner_done.kind = WgEventIf.Kind.VARIABLE
	inner_done.number = 2
	inner_done.comparison = WgEventIf.Comparison.AT_LEAST
	inner_done.value = 2
	inner_done.indent = 2
	var outer_done := WgEventIf.new()
	outer_done.kind = WgEventIf.Kind.VARIABLE
	outer_done.number = 1
	outer_done.comparison = WgEventIf.Comparison.AT_LEAST
	outer_done.value = 3
	outer_done.indent = 1
	var Op := WgEventSetVariables.Operation
	var commands: Array[WgEventCommand] = [
		WgEventLoop.new(),
		variable(1, Op.ADD, 1, 1), variable(2, Op.SET, 0, 1),
		at(WgEventLoop.new(), 1),
		variable(2, Op.ADD, 1, 2), variable(3, Op.ADD, 1, 2), inner_done, at(WgEventBreak.new(), 3), at(WgEventBlockEnd.new(), 3), at(WgEventBlockEnd.new(), 2), at(WgEventBlockEnd.new(), 2),
		at(WgEventRepeat.new(), 1),
		outer_done, at(WgEventBreak.new(), 2), at(WgEventBlockEnd.new(), 2), at(WgEventBlockEnd.new(), 1), at(WgEventBlockEnd.new(), 1),
		WgEventRepeat.new(),
		switch_on(),
	]
	_event(Vector2i(5, 4), [page(commands)])
	_world.walkers.interact(_player)
	_advance()
	assert_array([_value(1), _value(3), _flag()]).is_equal([3, 6, true])


func test_a_new_parallel_page_drops_the_list_of_the_page_before() -> void:
	var wait := WgEventWait.new()
	wait.seconds = 0.2
	var Op := WgEventSetVariables.Operation
	var event := _event(Vector2i(2, 2), [
		page([wait, variable(1, Op.ADD, 1)] as Array[WgEventCommand], {"trigger": WgEventPage.Trigger.PARALLEL}),
		page([variable(2, Op.ADD, 1)] as Array[WgEventCommand], {"trigger": WgEventPage.Trigger.PARALLEL, "condition": "switch_5"}),
	])
	_advance(3)
	_world.story.set_flag(&"switch_5")
	_advance(30)
	assert_object(event.page).is_same(event.pages[1])
	assert_int(_value(1)).is_equal(0)
	assert_int(_value(2)).is_greater(0)


func test_a_break_skips_a_loop_that_follows_it_in_the_same_body() -> void:
	var Op := WgEventSetVariables.Operation
	var commands: Array[WgEventCommand] = [
		WgEventLoop.new(), variable(1, Op.ADD, 1, 1), at(WgEventBreak.new(), 1),
		at(WgEventLoop.new(), 1), variable(2, Op.ADD, 1, 2), at(WgEventBlockEnd.new(), 2), at(WgEventRepeat.new(), 1),
		at(WgEventBlockEnd.new(), 1), WgEventRepeat.new(),
		switch_on(),
	]
	_event(Vector2i(5, 4), [page(commands)])
	_world.walkers.interact(_player)
	_advance()
	assert_array([_value(1), _value(2), _flag()]).is_equal([1, 0, true])


func test_the_events_service_and_its_lists_keep_no_service_alive() -> void:
	var other := World.new(self)
	var events_ref: WeakRef = weakref(other.events)
	var walkers_ref: WeakRef = weakref(other.walkers)
	other.root.free()
	other.cleanup()
	other = null
	assert_object(events_ref.get_ref()).is_null()
	assert_object(walkers_ref.get_ref()).is_null()
