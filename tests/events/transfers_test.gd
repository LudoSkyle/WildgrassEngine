extends GdUnitTestSuite

# Transfers, events placed, local switches of other events (feature 21): two
# maps saved by the tests, `field` and `town`; the player starts on field.

const World := preload("res://tests/support/walking_world.gd")
const MapBuilder := preload("res://tests/support/map_builder.gd")
const Events := preload("res://tests/events/events_test.gd")
const RecordingTransition := preload("res://tests/support/recording_transition.gd")

var _world: World
var _player: WgWalker
var _sheet: Texture2D


func before_test() -> void:
	_world = World.new(self, {"numbers": {"7": "town"}})
	_sheet = ImageTexture.create_from_image(Image.create(64, 64, false, Image.FORMAT_RGBA8))
	_world.map({}, Vector2i(12, 12))
	_player = _world.walker(Vector2i(0, 0), WgPlayerInput.new())
	_world.maps.traveller = _player
	RecordingTransition.calls.clear()


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


## Saves field and town (`town_events` in town), then goes to field, the
## player on (1, 1) facing up.
func _start(town_events: Array[WgEvent] = []) -> void:
	var build := MapBuilder.new(_world.sandbox)
	for id: String in ["field", "town"]:
		var made := build.map(&"", Vector2i(12, 12))
		MapBuilder.spawn(made, "Spawn", _world.tiles.center_of(Vector2i(1, 1)), Vector2i.UP)
		if id == "town":
			for event in town_events:
				made.entities_node().add_child(event)
		build.save(id, made)
	await _world.maps.go_to(&"field", &"Spawn")


func _event(cell: Vector2i, pages: Array[WgEventPage], number := 1, shown := true) -> WgEvent:
	var event := WgEvent.new()
	event.name = "Event%d" % number
	event.event_id = number
	event.position = _world.tiles.center_of(cell)
	for each in pages:
		each.sheet = _sheet if shown else null
	event.pages = pages
	var sprite := WgCharacterSprite.new()
	sprite.name = "Sprite"
	event.add_child(sprite)
	return event


## An event on the map shown.
func _place(cell: Vector2i, pages: Array[WgEventPage], number := 1, shown := true) -> WgEvent:
	var event := _event(cell, pages, number, shown)
	event.walkers = _world.walkers
	_world.maps.current.entities_node().add_child(event)
	event.set_process(false)
	_world.events.refresh(event)
	return event


## An autorun list, run once: its page gives way to a second one as it ends.
func _autorun(commands: Array[WgEventCommand], number := 1) -> WgEvent:
	var ended := WgEventSetLocalSwitch.new()
	ended.letter = "D"
	commands.append(ended)
	return _place(Vector2i(10, 10), [Events.page(commands, {"trigger": WgEventPage.Trigger.AUTORUN}), Events.page([], {"condition": "local:D"})], number)


static func _transfer(map: StringName, cell: Vector2i, direction := Vector2i.ZERO, transition := &"none") -> WgEventTransfer:
	var made := WgEventTransfer.new()
	made.map = map
	made.cell = cell
	made.direction = direction
	made.transition = transition
	return made


static func _local(letter: String, event := 0, map := &"") -> WgEventSetLocalSwitch:
	var made := WgEventSetLocalSwitch.new()
	made.letter = letter
	made.event = event
	made.map = map
	return made


## Advances the events `frames` frames, a real frame each, for the warps.
func _run(frames := 30) -> void:
	for _frame in frames:
		_world.events.advance(1.0 / 60.0)
		await get_tree().process_frame


func test_a_transfer_on_the_map_shown_moves_the_player_and_keeps_its_events() -> void:
	await _start()
	var other := _place(Vector2i(6, 6), [Events.page(), Events.page([], {"condition": "switch_5"})], 2)
	var wait := WgEventWait.new()
	wait.seconds = 0.2
	_autorun([_transfer(&"", Vector2i(3, 4), Vector2i.LEFT), wait, Events.switch_on()] as Array[WgEventCommand])
	_world.events.advance(1.0 / 60.0)
	# Moved at once (no transition), the list waiting: held again.
	assert_that(_player.cell).is_equal(Vector2i(3, 4))
	assert_bool(_world.walkers.is_busy(_player)).is_true()
	await _run()
	assert_that(_player.cell).is_equal(Vector2i(3, 4))
	assert_that(_player.facing).is_equal(Vector2i.LEFT)
	assert_str(String(_world.maps.current_id)).is_equal("field")
	assert_bool(is_instance_valid(other)).is_true()
	assert_bool(_world.story.has(&"switch_1")).is_true()
	assert_bool(_world.walkers.is_busy(_player)).is_false()


func test_a_transfer_to_another_map_goes_on_there_its_event_forgotten() -> void:
	await _start()
	var place := WgEventSetEventLocation.new()
	place.cell = Vector2i(9, 9)
	_autorun([_transfer(&"town", Vector2i(5, 2)), _local("A"), _local("B", 1), place, Events.switch_on()] as Array[WgEventCommand])
	await _run()
	assert_str(String(_world.maps.current_id)).is_equal("town")
	assert_that(_player.cell).is_equal(Vector2i(5, 2))
	assert_that(_player.facing).is_equal(Vector2i.UP)
	assert_bool(_world.story.has(&"switch_1")).is_true()
	# Its own switch, named by nothing on town: none set.
	assert_bool(_world.story.has(&"town/event_1:A")).is_false()
	assert_bool(_world.story.has(&"field/event_1:A")).is_false()
	# Event 1 named by number: still field's.
	assert_bool(_world.story.has(&"field/event_1:B")).is_true()


func test_a_transfer_by_variables_reads_the_map_from_its_number() -> void:
	await _start()
	var by := WgEventTransfer.new()
	by.by_variables = true
	by.map_variable = 1
	by.x_variable = 2
	by.y_variable = 3
	by.transition = &"none"
	_world.story.set_value(&"variable_1", 9)
	_autorun([by, Events.switch_on(2), Events.variable(1, WgEventSetVariables.Operation.SET, 7), by, Events.switch_on()] as Array[WgEventCommand])
	_world.story.set_value(&"variable_2", 4)
	_world.story.set_value(&"variable_3", 6)
	await _run(60)
	assert_bool(_world.story.has(&"switch_2")).is_true()
	assert_array(_world.logged.filter(func(line: String) -> bool: return line.contains("no map numbered 9"))).has_size(1)
	assert_str(String(_world.maps.current_id)).is_equal("town")
	assert_that(_player.cell).is_equal(Vector2i(4, 6))
	assert_bool(_world.story.has(&"switch_1")).is_true()


func test_a_transfer_to_no_map_is_logged_and_the_list_goes_on() -> void:
	await _start()
	_autorun([_transfer(&"nowhere", Vector2i(3, 3)), Events.switch_on()] as Array[WgEventCommand])
	await _run()
	assert_str(String(_world.maps.current_id)).is_equal("field")
	assert_that(_player.cell).is_equal(Vector2i(1, 1))
	assert_bool(_world.story.has(&"switch_1")).is_true()
	assert_array(_world.logged.filter(func(line: String) -> bool: return line.contains("nowhere"))).is_not_empty()


func test_a_transfer_waits_for_a_warp_under_way() -> void:
	await _start()
	_world.maps.is_changing = true
	_autorun([_transfer(&"", Vector2i(3, 4)), Events.switch_on()] as Array[WgEventCommand])
	await _run(10)
	assert_that(_player.cell).is_equal(Vector2i(1, 1))
	assert_bool(_world.story.has(&"switch_1")).is_false()
	_world.maps.is_changing = false
	await _run()
	assert_that(_player.cell).is_equal(Vector2i(3, 4))
	assert_bool(_world.story.has(&"switch_1")).is_true()


func test_a_transfer_dissolves_in_rpg_maker_s_twenty_ticks() -> void:
	await _start()
	_world.screens.register(&"transition_dissolve", _world.sandbox.scene("recording_transition.tscn", RecordingTransition))
	_autorun([_transfer(&"", Vector2i(3, 4), Vector2i.ZERO, &"dissolve")] as Array[WgEventCommand])
	await _run()
	assert_array(RecordingTransition.calls).is_equal(["cover %s" % (20.0 / 60.0), "uncover"])


func test_the_dissolve_keeps_no_picture_without_a_renderer_and_never_waits_for_one() -> void:
	var screen := _world.screens.open(&"transition_dissolve", {"seconds": 0.05}) as WgTransition
	await screen.cover()
	await screen.uncover()
	assert_float(screen.call(&"opacity")).is_equal(0.0)
	screen.close()


func test_arriving_starts_no_touch_event_but_an_event_touch_one() -> void:
	var touch := _event(Vector2i(5, 2), [Events.page([Events.switch_on(2)] as Array[WgEventCommand], {"trigger": WgEventPage.Trigger.TOUCH})], 1, false)
	var event_touch := _event(Vector2i(5, 2), [Events.page([Events.switch_on(3)] as Array[WgEventCommand], {"trigger": WgEventPage.Trigger.EVENT_TOUCH})], 2, false)
	await _start([touch, event_touch] as Array[WgEvent])
	_autorun([_transfer(&"town", Vector2i(5, 2))] as Array[WgEventCommand])
	await _run(60)
	assert_str(String(_world.maps.current_id)).is_equal("town")
	assert_bool(_world.story.has(&"switch_2")).is_false()
	assert_bool(_world.story.has(&"switch_3")).is_true()


func test_set_event_location_places_by_cell_and_variables_swaps_and_turns() -> void:
	await _start()
	var second := _place(Vector2i(6, 6), [Events.page()], 2)
	var third := _place(Vector2i(8, 6), [Events.page()], 3)
	var by_cell := WgEventSetEventLocation.new()
	by_cell.character = 2
	by_cell.cell = Vector2i(2, 7)
	by_cell.direction = Vector2i.RIGHT
	var by_variables := WgEventSetEventLocation.new()
	by_variables.character = 3
	by_variables.mode = WgEventSetEventLocation.Mode.VARIABLES
	by_variables.x_variable = 4
	by_variables.y_variable = 5
	var swap := WgEventSetEventLocation.new()
	swap.character = -1
	swap.mode = WgEventSetEventLocation.Mode.SWAP
	swap.other = 2
	_world.story.set_value(&"variable_4", 9)
	_world.story.set_value(&"variable_5", 3)
	_autorun([by_cell, by_variables, swap] as Array[WgEventCommand])
	await _run(5)
	assert_that(third.cell).is_equal(Vector2i(9, 3))
	assert_that(second.facing).is_equal(Vector2i.RIGHT)
	assert_that(_player.cell).is_equal(Vector2i(2, 7))
	assert_that(second.cell).is_equal(Vector2i(1, 1))
	assert_that(third.facing).is_equal(Vector2i.DOWN)


func test_a_local_switch_of_another_event_or_map_shows_its_page() -> void:
	var waiting := _event(Vector2i(8, 8), [Events.page(), Events.page([], {"condition": "local:A"})], 3)
	await _start([waiting] as Array[WgEvent])
	var near := _place(Vector2i(6, 6), [Events.page(), Events.page([], {"condition": "local:B"})], 2)
	var wait := WgEventWait.new()
	wait.seconds = 0.2
	_autorun([_local("B", 2), _local("A", 3, &"town"), wait, _transfer(&"town", Vector2i(2, 2))] as Array[WgEventCommand])
	await _run(3)
	assert_object(near.page).is_same(near.pages[1])
	assert_bool(_world.story.has(&"field/event_2:B")).is_true()
	await _run(60)
	var arrived := _world.maps.current.entities_node().get_node("Event3") as WgEvent
	assert_object(arrived.page).is_same(arrived.pages[1])
