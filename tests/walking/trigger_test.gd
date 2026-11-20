extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const MapBuilder := preload("res://tests/support/map_builder.gd")
const WaitingTrigger := preload("res://tests/support/waiting_trigger.gd")
const T := preload("res://tests/support/tile_builder.gd")

const ACTIONS := ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept"]

var _world: World
var _player: WgWalker


func before_test() -> void:
	_world = World.new(self)


func after_test() -> void:
	for action: String in ACTIONS:
		Input.action_release(action)
	_world.root.free()
	_world.cleanup()


## A 12×12 map with `cells`, the player on `cell` facing up.
func _field(cells := {}, cell := Vector2i(5, 5)) -> void:
	_world.map(cells, Vector2i(12, 12))
	_player = _world.walker(cell, WgPlayerInput.new())
	_player.facing = Vector2i.UP
	_world.maps.traveller = _player


func _place(trigger: WgTrigger, cell: Vector2i) -> WgTrigger:
	trigger.position = _world.tiles.center_of(cell)
	_world.maps.current.entities_node().add_child(trigger)
	return trigger


## Advances `walkers` by 0.05 s a frame, real frames passing, `count` times or
## until `done` returns true.
func _frames(walkers: Array, count: int, done := Callable()) -> void:
	for frame in count:
		if done.is_valid() and done.call():
			return
		for walker: WgWalker in walkers:
			if is_instance_valid(walker):
				walker.advance(0.05)
		if _world.dialogue.box != null:
			_world.dialogue.box.set_process(false)
			_world.dialogue.box.advance(0.05)
		await get_tree().process_frame


func _confirm() -> void:
	var event := InputEventAction.new()
	event.action = "ui_accept"
	event.pressed = true
	_world.screens.handle_input(event)


func test_a_trigger_runs_where_a_step_ends_and_holds_the_player_at_once() -> void:
	_field()
	var trigger := _place(WaitingTrigger.new(), Vector2i(5, 3)) as WaitingTrigger
	Input.action_press("ui_up")
	_player.advance(0.12)
	_player.advance(0.25)
	_player.advance(0.3)
	assert_that(_player.cell).is_equal(Vector2i(5, 3))
	assert_bool(_player.is_moving).is_false()
	_player.advance(1.0)
	assert_that(_player.cell).is_equal(Vector2i(5, 3))
	assert_int(trigger.runs).is_equal(1)
	trigger.release.emit()
	_player.advance(0.3)
	assert_that(_player.cell).is_equal(Vector2i(5, 2))


func test_turning_a_scripted_walk_or_a_disabled_trigger_do_nothing() -> void:
	_field()
	var here := _place(WaitingTrigger.new(), Vector2i(5, 5)) as WaitingTrigger
	_player.turn(Vector2i.LEFT)
	_player.advance(0.05)
	var ahead := _place(WaitingTrigger.new(), Vector2i(5, 4)) as WaitingTrigger
	_world.walkers.walk(_player, [Vector2i.UP])
	_player.advance(0.3)
	assert_that(_player.cell).is_equal(Vector2i(5, 4))
	var off := _place(WaitingTrigger.new(), Vector2i(5, 3)) as WaitingTrigger
	off.enabled = false
	_player.step(Vector2i.UP)
	_player.advance(0.3)
	assert_that(_player.cell).is_equal(Vector2i(5, 3))
	assert_array([here.runs, ahead.runs, off.runs]).is_equal([0, 0, 0])


func test_arriving_by_a_warp_does_nothing() -> void:
	var build := MapBuilder.new(_world.sandbox)
	var town := build.map(&"town")
	MapBuilder.spawn(town, "Spawn", Vector2(88, 88))
	var trigger := WaitingTrigger.new()
	trigger.name = "Trap"
	trigger.position = Vector2(88, 88)
	town.add_child(trigger)
	build.save("town", town)
	_world.map({}, Vector2i(4, 4))
	_player = _world.walker(Vector2i(0, 0))
	_world.maps.traveller = _player
	await _world.maps.go_to(&"town", &"Spawn")
	assert_int((_world.maps.current.get_node("Trap") as WaitingTrigger).runs).is_equal(0)
	assert_bool(_world.walkers.is_busy(_player)).is_false()


func test_a_slide_ends_on_a_trigger() -> void:
	_field({Vector2i(5, 4): T.ICE, Vector2i(5, 3): T.ICE, Vector2i(5, 2): T.ICE, Vector2i(5, 1): T.ICE})
	var trigger := _place(WaitingTrigger.new(), Vector2i(5, 2)) as WaitingTrigger
	_player.step(Vector2i.UP)
	_player.advance(2.0)
	assert_that(_player.cell).is_equal(Vector2i(5, 2))
	assert_bool(_player.is_sliding).is_false()
	assert_int(trigger.runs).is_equal(1)


func test_a_jump_triggers_where_it_lands() -> void:
	_field({Vector2i(5, 6): T.LEDGE})
	var trigger := _place(WaitingTrigger.new(), Vector2i(5, 7)) as WaitingTrigger
	_player.step(Vector2i.DOWN)
	_player.advance(1.0)
	assert_that(_player.cell).is_equal(Vector2i(5, 7))
	assert_int(trigger.runs).is_equal(1)


## A guard on `post` facing right, its passage on `passage`.
func _guarded(post: Vector2i, passage: Vector2i) -> WgWalker:
	var guard := _world.walker(post)
	guard.name = "Guard"
	guard.facing = Vector2i.RIGHT
	var talk := WgTalk.new()
	talk.text = "No entry!"
	talk.speaker = "Guard"
	guard.add_child(talk)
	var block := WgRoadblock.new()
	_place(block, passage)
	block.guard = block.get_path_to(guard)
	return guard


func test_a_guard_steps_in_as_the_player_backs_away_speaks_and_goes_back() -> void:
	_field()
	var guard := _guarded(Vector2i(4, 3), Vector2i(5, 3))
	Input.action_press("ui_up")
	_player.advance(0.12)
	_player.advance(0.25)
	_player.advance(0.25)
	assert_bool(_player.is_moving).is_true()
	assert_that(_player.heading).is_equal(Vector2i.DOWN)
	assert_that(_player.facing).is_equal(Vector2i.UP)
	assert_that(guard.heading).is_equal(Vector2i.RIGHT)
	await _frames([_player, guard], 60, func() -> bool: return _world.dialogue.is_open())
	_world.dialogue.box.advance(10.0)
	assert_str(_world.dialogue.box.shown_text()).is_equal("No entry!")
	assert_that(_player.cell).is_equal(Vector2i(5, 4))
	assert_that(guard.cell).is_equal(Vector2i(5, 3))
	assert_that(guard.facing).is_equal(Vector2i.DOWN)
	_confirm()
	await _frames([_player, guard], 60, func() -> bool: return not _world.walkers.is_busy(_player))
	assert_that(guard.cell).is_equal(Vector2i(4, 3))
	assert_that(guard.facing).is_equal(Vector2i.RIGHT)
	_player.advance(1.0)
	assert_that(_player.cell).is_equal(Vector2i(5, 4))
	Input.action_release("ui_up")
	_player.advance(0.05)
	Input.action_press("ui_up")
	_player.advance(0.12)
	_player.advance(0.25)
	assert_that(_player.cell).is_equal(Vector2i(5, 3))
	assert_bool(_world.walkers.is_busy(_player)).is_true()


func test_a_player_that_cannot_back_away_hears_the_guard_from_its_post() -> void:
	_field({Vector2i(5, 4): T.LEDGE}, Vector2i(5, 3))
	_player.facing = Vector2i.DOWN
	var guard := _guarded(Vector2i(4, 5), Vector2i(5, 5))
	var bumps := [0]
	guard.bumped.connect(func(_direction: Vector2i) -> void: bumps[0] += 1)
	_player.step(Vector2i.DOWN)
	_player.advance(1.0)
	await _frames([_player, guard], 10, func() -> bool: return _world.dialogue.is_open())
	assert_bool(_world.dialogue.is_open()).is_true()
	assert_that(guard.cell).is_equal(Vector2i(4, 5))
	assert_that(_player.cell).is_equal(Vector2i(5, 5))
	assert_int(bumps[0]).is_equal(0)
	_world.dialogue.box.advance(10.0)
	_confirm()
	await _frames([_player, guard], 10, func() -> bool: return not _world.walkers.is_busy(_player))
	assert_bool(_world.walkers.is_busy(_player)).is_false()


func test_without_a_guard_or_with_one_freed_the_text_is_said_and_the_player_freed() -> void:
	_field()
	var alone := WgRoadblock.new()
	alone.text = "Closed."
	_place(alone, Vector2i(5, 4))
	_player.step(Vector2i.UP)
	_player.advance(0.3)
	_world.dialogue.box.set_process(false)
	_world.dialogue.box.advance(10.0)
	assert_str(_world.dialogue.box.shown_text()).is_equal("Closed.")
	_confirm()
	assert_bool(_world.walkers.is_busy(_player)).is_false()
	alone.free()
	await get_tree().process_frame
	await get_tree().process_frame
	var guard := _guarded(Vector2i(4, 3), Vector2i(5, 3))
	_player.step(Vector2i.UP)
	_player.advance(0.3)
	await _frames([_player, guard], 60, func() -> bool: return _world.dialogue.is_open())
	guard.free()
	_world.dialogue.box.advance(10.0)
	_confirm()
	await _frames([_player], 10, func() -> bool: return not _world.walkers.is_busy(_player))
	assert_bool(_world.walkers.is_busy(_player)).is_false()
