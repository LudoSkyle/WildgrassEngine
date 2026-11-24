extends GdUnitTestSuite

# Messages, choices and numbers in events (feature 21): lists built by the
# tests, shown in the engine's message box.

const World := preload("res://tests/support/walking_world.gd")
const Events := preload("res://tests/events/events_test.gd")

const STEP := 1.0 / 60.0

var _world: World
var _player: WgWalker


func before_test() -> void:
	_world = World.new(self)
	_world.map({}, Vector2i(12, 12))
	_player = _world.walker(Vector2i(5, 5), WgPlayerInput.new())
	_player.facing = Vector2i.UP
	_world.maps.traveller = _player


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


static func say(text: String) -> WgEventSay:
	var command := WgEventSay.new()
	command.text = text
	return command


static func choices(texts: Array[String], cancel: int) -> WgEventChoices:
	var command := WgEventChoices.new()
	command.choices = texts
	command.cancel = cancel
	return command


static func when(choice: int) -> WgEventWhen:
	var command := WgEventWhen.new()
	command.choice = choice
	return command


func _event(commands: Array[WgEventCommand], cell := Vector2i(5, 4), number := 1, trigger := WgEventPage.Trigger.ACTION) -> WgEvent:
	var event := WgEvent.new()
	event.name = "Event%d" % number
	event.event_id = number
	event.walkers = _world.walkers
	event.position = _world.tiles.center_of(cell)
	var shown := Events.page(commands, {"trigger": trigger})
	# A sheet: it blocks, so the action key reaches it from beside.
	shown.sheet = ImageTexture.create_from_image(Image.create(64, 64, false, Image.FORMAT_RGBA8))
	event.pages = [shown]
	_world.maps.current.entities_node().add_child(event)
	event.set_process(false)
	_world.events.refresh(event)
	return event


func _advance(frames := 1) -> void:
	for _frame in frames:
		_world.events.advance(STEP)


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_world.screens.handle_input(event)


func _written() -> void:
	_world.dialogue.box.set_process(false)
	_world.dialogue.box.advance(10.0)


func _flag(number := 1) -> bool:
	return _world.story.has(StringName("switch_%d" % number))


## A choice, its whens setting switch 10 + the answer, the cancel's 20.
func _choice_list(cancel: int, count := 2) -> Array[WgEventCommand]:
	var texts: Array[String] = []
	for index in count:
		texts.append("C%d" % index)
	var list: Array[WgEventCommand] = [say("Pick?"), choices(texts, cancel)]
	for index in count:
		list.append(when(index))
		list.append(Events.at(Events.switch_on(10 + index), 1))
		list.append(Events.at(WgEventBlockEnd.new(), 1))
	list.append(WgEventWhenCancel.new())
	list.append(Events.at(Events.switch_on(20), 1))
	list.append(Events.at(WgEventBlockEnd.new(), 1))
	list.append(WgEventBlockEnd.new())
	return list


func test_a_message_holds_the_list_until_it_is_read() -> void:
	_event([say("Hello."), Events.switch_on()])
	_world.walkers.interact(_player)
	_advance(3)
	assert_bool(_world.dialogue.is_open()).is_true()
	assert_bool(_flag()).is_false()
	_written()
	assert_str(_world.dialogue.box.shown_text()).is_equal("Hello.")
	_press("ui_accept")
	_advance()
	assert_bool(_flag()).is_true()


func test_a_message_then_a_choice_asks_and_its_when_runs() -> void:
	_event(_choice_list(0))
	_world.walkers.interact(_player)
	_advance()
	_written()
	assert_str(_world.dialogue.box.shown_text()).is_equal("Pick?")
	_press("ui_down")
	_press("ui_accept")
	_advance()
	assert_array([_flag(10), _flag(11), _flag(20)]).is_equal([false, true, false])


func test_cancel_answers_as_rpg_maker_says() -> void:
	# 0: nothing; 2: the second choice; 5: the cancel's own branch.
	_event(_choice_list(0))
	_world.walkers.interact(_player)
	_advance()
	_written()
	_press("ui_cancel")
	_advance()
	assert_bool(_world.dialogue.is_busy()).is_true()
	_press("ui_accept")
	_advance()
	assert_bool(_flag(10)).is_true()
	_world.story.clear_flag(&"switch_10")
	_event(_choice_list(2), Vector2i(4, 5), 2)
	_player.turn(Vector2i.LEFT)
	_world.walkers.interact(_player)
	_advance()
	_written()
	_press("ui_cancel")
	_advance()
	assert_array([_flag(10), _flag(11), _flag(20)]).is_equal([false, true, false])
	_world.story.clear_flag(&"switch_11")
	_event(_choice_list(5), Vector2i(6, 5), 3)
	_player.turn(Vector2i.RIGHT)
	_world.walkers.interact(_player)
	_advance()
	_written()
	_press("ui_cancel")
	_advance()
	assert_array([_flag(10), _flag(11), _flag(20)]).is_equal([false, false, true])


func test_a_choice_alone_asks_with_no_message() -> void:
	var list := _choice_list(0)
	list.remove_at(0)
	_event(list)
	_world.walkers.interact(_player)
	_advance()
	_written()
	_press("ui_accept")
	_advance()
	assert_bool(_flag(10)).is_true()


func test_a_number_goes_into_its_variable_and_cancel_does_nothing() -> void:
	var number := WgEventInputNumber.new()
	number.variable = 4
	number.digits = 2
	_event([say("How many?"), number, Events.switch_on()])
	_world.walkers.interact(_player)
	_advance()
	_written()
	_press("ui_cancel")
	_press("ui_up")
	_press("ui_up")
	_press("ui_up")
	_press("ui_accept")
	_advance()
	assert_int(int(_world.story.value(&"variable_4"))).is_equal(3)
	assert_bool(_flag()).is_true()


func test_one_message_at_a_time_another_list_waits_its_turn() -> void:
	_event([say("Mine."), Events.switch_on(1)])
	_event([say("Theirs."), Events.switch_on(2)], Vector2i(1, 1), 2, WgEventPage.Trigger.PARALLEL)
	_world.walkers.interact(_player)
	_advance()
	_written()
	var first := _world.dialogue.box.shown_text()
	_press("ui_accept")
	_advance()
	_written()
	var second := _world.dialogue.box.shown_text()
	_press("ui_accept")
	_advance(2)
	assert_array([first, second]).is_equal(["Theirs.", "Mine."])
	assert_array([_flag(1), _flag(2)]).is_equal([true, true])


func test_text_options_move_the_messages_and_look_to_turns_the_player() -> void:
	var options := WgEventTextOptions.new()
	options.place = WgEventTextOptions.Place.TOP
	_event([], Vector2i(2, 5), 2)
	_event([options, say("[look_to=2]Look.")])
	_world.walkers.interact(_player)
	_advance()
	_written()
	assert_str(str(_world.dialogue.box.get(&"_options").get("place"))).is_equal("top")
	assert_that(_player.facing).is_equal(Vector2i.LEFT)


func test_a_list_set_up_again_drops_what_the_one_before_waited_for() -> void:
	var run := WgEventCommand._Run.new(_world.events)
	run.setup([say("First.")] as Array[WgEventCommand], null)
	run.advance(STEP)
	assert_bool(run.waiting).is_true()
	run.setup([say("Second."), Events.switch_on()] as Array[WgEventCommand], null)
	_world.dialogue.close()
	await get_tree().process_frame
	run.advance(STEP)
	_written()
	assert_str(_world.dialogue.box.shown_text()).is_equal("Second.")
	assert_bool(_flag()).is_false()


func test_a_message_waiting_its_turn_is_not_kept_when_its_list_is_dropped() -> void:
	_event([say("Mine."), Events.switch_on(1)])
	var parallel := Events.page([say("Theirs."), Events.switch_on(2)] as Array[WgEventCommand], {"trigger": WgEventPage.Trigger.PARALLEL, "condition": "switch_7"})
	var other := _event([], Vector2i(1, 1), 2)
	other.pages = [parallel]
	_world.events.refresh(other)
	_world.walkers.interact(_player)
	_advance()
	_world.story.set_flag(&"switch_7")
	_advance(3)
	_world.story.clear_flag(&"switch_7")
	_advance()
	_written()
	_press("ui_accept")
	_advance(3)
	assert_bool(_flag(1)).is_true()
	assert_bool(_world.dialogue.is_busy()).is_false()
	assert_bool(_flag(2)).is_false()
