extends GdUnitTestSuite

# Routes and moving by oneself (feature 21): events, routes and lists built
# by the tests; walkers advanced by hand, frame by frame.

const World := preload("res://tests/support/walking_world.gd")
const Events := preload("res://tests/events/events_test.gd")
const T := preload("res://tests/support/tile_builder.gd")
const Mover := preload("res://addons/wildgrass/events/mover.gd")

const K := WgMoveStep.Kind

var _world: World
var _player: WgWalker
var _sheet: Texture2D


func before_test() -> void:
	# Moving at random and toward the player draw lots as RPG Maker's do: the
	# same draws each run, so that a test never fails by chance.
	seed(21)
	_world = World.new(self)
	_world.map({Vector2i(9, 3): T.WALL}, Vector2i(12, 12))
	_player = _world.walker(Vector2i(5, 8), WgPlayerInput.new())
	_player.facing = Vector2i.UP
	_world.maps.traveller = _player
	_sheet = ImageTexture.create_from_image(Image.create(64, 64, false, Image.FORMAT_RGBA8))


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


static func route(kinds: Array, repeat := false, skippable := false) -> WgMoveRoute:
	var made := WgMoveRoute.new()
	for entry: Variant in kinds:
		var step := WgMoveStep.new()
		if entry is Array:
			step.kind = entry[0]
			if entry[1] is Vector2i:
				step.offset = entry[1]
			else:
				step.value = entry[1]
		else:
			step.kind = entry
		made.steps.append(step)
	made.repeat = repeat
	made.skippable = skippable
	return made


## `built`: its page chosen before it enters the tree and has its walkers
## service, as on a map just built.
func _event(cell: Vector2i, page: WgEventPage, number := 1, built := false) -> WgEvent:
	var event := WgEvent.new()
	event.name = "Event%d" % number
	event.event_id = number
	event.position = _world.tiles.center_of(cell)
	page.sheet = _sheet
	event.pages = [page]
	var sprite := WgCharacterSprite.new()
	sprite.name = "Sprite"
	event.add_child(sprite)
	if built:
		_world.events.refresh(event)
	event.walkers = _world.walkers
	_world.maps.current.entities_node().add_child(event)
	event.set_process(false)
	if not built:
		_world.events.refresh(event)
	return event


## Advances the events and every walker for `seconds`, `step` at a time.
func _run(seconds: float, step := 1.0 / 60.0) -> void:
	var left := seconds
	while left > 0.00001:
		var delta := minf(step, left)
		_world.events.advance(delta)
		for walker in _world.walkers.all():
			walker.advance(delta)
		left -= delta


func test_a_route_imposed_moves_its_character_then_lets_go() -> void:
	var event := _event(Vector2i(2, 2), Events.page())
	_world.events.force_route(event, route([K.MOVE_RIGHT, K.MOVE_RIGHT, K.TURN_UP]))
	assert_bool(_world.events.any_forced_route()).is_true()
	_run(2.0)
	assert_that(event.cell).is_equal(Vector2i(4, 2))
	assert_that(event.facing).is_equal(Vector2i.UP)
	assert_bool(_world.events.any_forced_route()).is_false()
	assert_bool(_world.walkers.is_scripted(event)).is_false()


func test_a_list_waits_for_the_routes_it_imposed() -> void:
	var move := WgEventMoveRoute.new()
	move.character = 0
	move.route = route([K.MOVE_DOWN, K.MOVE_DOWN, K.MOVE_DOWN])
	var event := _event(Vector2i(2, 2), Events.page([move, WgEventWaitForMoves.new(), Events.switch_on(), WgEventSetLocalSwitch.new()] as Array[WgEventCommand], {"trigger": WgEventPage.Trigger.AUTORUN}))
	event.pages.append(Events.page([], {"condition": "local:A"}))
	_run(0.3)
	assert_bool(_world.story.has(&"switch_1")).is_false()
	_run(2.0)
	assert_that(event.cell).is_equal(Vector2i(2, 5))
	assert_bool(_world.story.has(&"switch_1")).is_true()


func test_an_imposed_route_s_first_commands_run_at_once_one_that_only_changes_looks_ends_there() -> void:
	var event := _event(Vector2i(2, 2), Events.page())
	_world.events.force_route(event, route([[K.OPACITY, 128]]))
	assert_float((event.get_node("Sprite") as CanvasItem).modulate.a).is_equal_approx(128 / 255.0, 0.001)
	assert_bool(_world.events.any_forced_route()).is_false()
	assert_bool(_world.walkers.is_scripted(event)).is_false()
	_world.events.force_route(event, route([K.TURN_LEFT, K.MOVE_DOWN]))
	assert_that(event.facing).is_equal(Vector2i.LEFT)


func test_a_parallel_list_imposing_looks_every_frame_does_not_hold_a_wait_for_moves() -> void:
	var looks := WgEventMoveRoute.new()
	looks.character = 1
	looks.route = route([[K.OPACITY, 255]])
	var door := _event(Vector2i(6, 6), Events.page(), 1)
	_event(Vector2i(7, 7), Events.page([looks] as Array[WgEventCommand], {"trigger": WgEventPage.Trigger.PARALLEL}), 2)
	var move := WgEventMoveRoute.new()
	move.character = 0
	move.route = route([K.MOVE_DOWN])
	var event := _event(Vector2i(2, 2), Events.page([move, WgEventWaitForMoves.new(), Events.switch_on(), WgEventSetLocalSwitch.new()] as Array[WgEventCommand], {"trigger": WgEventPage.Trigger.AUTORUN}), 3)
	event.pages.append(Events.page([], {"condition": "local:A"}))
	_run(1.0)
	assert_that(event.cell).is_equal(Vector2i(2, 3))
	assert_bool(_world.story.has(&"switch_1")).is_true()
	assert_bool(is_instance_valid(door)).is_true()


func test_a_blocked_step_is_tried_again_unless_the_route_is_skippable() -> void:
	var stuck := _event(Vector2i(8, 3), Events.page(), 1)
	_world.events.force_route(stuck, route([K.MOVE_RIGHT, K.MOVE_DOWN]))
	var skipping := _event(Vector2i(8, 5), Events.page(), 2)
	_world.walker(Vector2i(9, 5))
	_world.events.force_route(skipping, route([K.MOVE_RIGHT, K.MOVE_DOWN], false, true))
	_run(2.0)
	assert_that(stuck.cell).is_equal(Vector2i(8, 3))
	assert_that(stuck.facing).is_equal(Vector2i.RIGHT)
	assert_that(skipping.cell).is_equal(Vector2i(8, 6))


func test_a_route_keeps_rpg_maker_s_time_at_any_frame_rate() -> void:
	for step: float in [1.0 / 60.0, 1.0 / 120.0]:
		var event := _event(Vector2i(2, 2), Events.page(), 1)
		_world.events.force_route(event, route([[K.WAIT, 15], K.MOVE_RIGHT]))
		_run(0.45, step)
		assert_bool(event.is_moving).override_failure_message("waiting at %s" % step).is_false()
		assert_that(event.cell).is_equal(Vector2i(2, 2))
		_run(0.1, step)
		assert_bool(event.is_moving or event.cell == Vector2i(3, 2)).override_failure_message("moving at %s" % step).is_true()
		event.free()
		_run(0.05, step)


func test_a_page_route_repeats_or_runs_once() -> void:
	var page := Events.page()
	page.move_type = WgEventPage.MoveType.ROUTE
	page.move_frequency = 6
	page.move_route = route([K.MOVE_RIGHT, K.MOVE_LEFT], true)
	var pacing := _event(Vector2i(2, 2), page, 1)
	var once := Events.page()
	once.move_type = WgEventPage.MoveType.ROUTE
	once.move_frequency = 6
	once.move_route = route([K.MOVE_DOWN])
	var single := _event(Vector2i(6, 2), once, 2)
	var seen: Array[Vector2i] = []
	var moves := 0
	var last := pacing.cell
	for frame in 200:
		_run(1.0 / 60.0)
		if not pacing.cell in seen:
			seen.append(pacing.cell)
		if pacing.cell != last:
			moves += 1
			last = pacing.cell
	assert_array(seen).contains_exactly_in_any_order([Vector2i(2, 2), Vector2i(3, 2)])
	assert_int(moves).is_greater(3)
	assert_that(single.cell).is_equal(Vector2i(6, 3))


func test_a_page_route_that_only_turns_stands_its_frequency_between_turns() -> void:
	var page := Events.page()
	page.move_type = WgEventPage.MoveType.ROUTE
	page.move_frequency = 3
	page.move_route = route([K.TURN_RIGHT_90], true)
	var turning := _event(Vector2i(5, 5), page)
	var turns := 0
	var last := turning.facing
	# Frequency 3: 102 ticks standing between two turns, two turns in 3.5 s.
	for frame in 210:
		_run(1.0 / 60.0)
		if turning.facing != last:
			turns += 1
			last = turning.facing
	assert_int(turns).is_equal(2)


func test_moving_by_itself_waits_its_frequency_and_stops_while_its_list_runs() -> void:
	var wait := WgEventWait.new()
	wait.seconds = 5.0
	var page := Events.page([wait] as Array[WgEventCommand])
	page.move_type = WgEventPage.MoveType.RANDOM
	page.move_frequency = 6
	var event := _event(Vector2i(5, 5), page)
	var moved := 0
	var last := event.cell
	for frame in 300:
		_run(1.0 / 60.0)
		if event.cell != last:
			moved += 1
			last = event.cell
	assert_int(moved).is_greater(2)
	assert_int(Mover.stop_ticks_of(3)).is_equal(102)
	var slow := Events.page()
	slow.move_type = WgEventPage.MoveType.RANDOM
	slow.move_frequency = 1
	var sleeper := _event(Vector2i(2, 9), slow, 2)
	var still := sleeper.cell
	_run(3.0)
	assert_that(sleeper.cell).is_equal(still)
	assert_int(Mover.stop_ticks_of(6)).is_equal(0)
	_run(0.5)
	event.starting = true
	_run(0.5)
	var held := event.cell
	_run(2.0)
	assert_bool(event.is_locked()).is_true()
	assert_that(event.cell).is_equal(held)


func test_an_event_of_a_map_just_built_moves_by_itself() -> void:
	var page := Events.page()
	page.move_type = WgEventPage.MoveType.RANDOM
	page.move_frequency = 6
	var event := _event(Vector2i(5, 5), page, 1, true)
	var start := event.cell
	_run(2.0)
	assert_that(event.cell).is_not_equal(start)


func test_the_movers_of_walkers_freed_with_their_map_are_dropped() -> void:
	var page := Events.page()
	page.move_type = WgEventPage.MoveType.RANDOM
	var gone := _event(Vector2i(5, 5), page)
	var kept := _event(Vector2i(2, 2), page.duplicate(), 2)
	_run(0.1)
	gone.free()
	_run(0.1)
	var movers: Dictionary = _world.events.get(&"_movers")
	assert_array(movers.keys()).is_equal([kept])


func test_a_route_changes_pace_look_through_and_more() -> void:
	var event := _event(Vector2i(8, 3), Events.page())
	var graphic := route([[K.SPEED, 4], [K.SWITCH_ON, 7], K.THROUGH_ON, K.MOVE_RIGHT, K.FIXED_DIRECTION_ON, K.ON_TOP_ON, [K.OPACITY, 51], K.GRAPHIC])
	graphic.steps[7].sheet = null
	_world.events.force_route(event, graphic)
	_run(1.0)
	assert_float(event.pace).is_equal_approx(7.5, 0.001)
	assert_float(Mover.pace_of(3)).is_equal_approx(3.75, 0.001)
	assert_bool(_world.story.has(&"switch_7")).is_true()
	assert_that(event.cell).is_equal(Vector2i(9, 3))
	assert_bool(event.fixed_direction).is_true()
	assert_int(event.z_index).is_equal(WgWalker.ON_TOP_Z)
	assert_float((event.get_node("Sprite") as CanvasItem).modulate.a).is_equal_approx(0.2, 0.01)
	assert_bool((event.get_node("Sprite") as CanvasItem).visible).is_false()


func test_a_route_jump_takes_rpg_maker_s_ticks() -> void:
	var event := _event(Vector2i(2, 2), Events.page())
	# Speed 3, two cells: (10 + 2 - 3) × 2 = 18 ticks in the air.
	_world.events.force_route(event, route([[K.JUMP, Vector2i(2, 0)]]))
	_run(17.0 / 60.0)
	assert_bool(event.is_jumping).is_true()
	_run(3.0 / 60.0)
	assert_bool(event.is_jumping).is_false()
	assert_that(event.cell).is_equal(Vector2i(4, 2))


func test_a_route_imposed_on_the_player_moves_it_while_a_list_holds_it() -> void:
	var move := WgEventMoveRoute.new()
	move.character = -1
	move.route = route([K.MOVE_UP, K.MOVE_UP])
	var event := _event(Vector2i(1, 1), Events.page([move, WgEventWaitForMoves.new(), Events.switch_on(), WgEventSetLocalSwitch.new()] as Array[WgEventCommand], {"trigger": WgEventPage.Trigger.AUTORUN}))
	event.pages.append(Events.page([], {"condition": "local:A"}))
	_run(0.05)
	assert_bool(_world.walkers.is_busy(_player)).is_true()
	_run(2.0)
	assert_that(_player.cell).is_equal(Vector2i(5, 6))
	assert_bool(_world.story.has(&"switch_1")).is_true()


func test_a_new_page_ends_the_route_imposed_on_its_event() -> void:
	var event := _event(Vector2i(2, 2), Events.page())
	var moving := Events.page([], {"condition": "switch_4"})
	moving.move_type = WgEventPage.MoveType.RANDOM
	moving.move_frequency = 1
	event.pages.append(moving)
	_world.events.force_route(event, route([[K.WAIT, 30], K.MOVE_RIGHT]))
	_run(0.2)
	_world.story.set_flag(&"switch_4")
	_run(2.0)
	assert_that(event.cell).is_equal(Vector2i(2, 2))
	assert_bool(_world.events.any_forced_route()).is_false()


func test_an_event_touch_event_walking_into_the_player_starts() -> void:
	var page := Events.page([Events.switch_on()] as Array[WgEventCommand], {"trigger": WgEventPage.Trigger.EVENT_TOUCH})
	page.move_type = WgEventPage.MoveType.APPROACH
	page.move_frequency = 6
	_event(Vector2i(5, 5), page)
	_run(3.0)
	assert_bool(_world.story.has(&"switch_1")).is_true()
