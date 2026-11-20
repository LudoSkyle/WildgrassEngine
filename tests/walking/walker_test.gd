extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const Steady := preload("res://tests/support/steady_controller.gd")
const T := preload("res://tests/support/tile_builder.gd")

const UP := Vector2i.UP
const DOWN := Vector2i.DOWN
const LEFT := Vector2i.LEFT
const RIGHT := Vector2i.RIGHT

var _world: World


func before_test() -> void:
	_world = World.new(self)


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _events(walker: WgWalker) -> Array[String]:
	var events: Array[String] = []
	walker.turned.connect(func(direction: Vector2i) -> void: events.append("turned %s" % direction))
	walker.step_started.connect(func(from: Vector2i, to: Vector2i) -> void: events.append("started %s %s" % [from, to]))
	walker.step_finished.connect(func(cell: Vector2i) -> void: events.append("finished %s" % cell))
	walker.bumped.connect(func(direction: Vector2i) -> void: events.append("bumped %s" % direction))
	return events


func test_a_walker_settles_on_the_centre_of_its_cell_and_holds_it() -> void:
	_world.map()
	var walker := _world.walker(Vector2i(2, 3))
	assert_that(walker.position).is_equal(Vector2(40, 56))
	assert_that(walker.cell).is_equal(Vector2i(2, 3))
	assert_object(_world.walkers.at(Vector2i(2, 3))).is_same(walker)


func test_a_step_goes_at_its_pace_to_the_next_centre_and_cannot_be_doubled() -> void:
	_world.map()
	var walker := _world.walker(Vector2i(2, 2))
	var events := _events(walker)
	assert_bool(walker.step(RIGHT)).is_true()
	assert_bool(walker.step(DOWN)).is_false()
	walker.advance(0.125)
	assert_that(walker.position).is_equal(Vector2(48, 40))
	assert_bool(walker.is_moving).is_true()
	walker.advance(0.125)
	assert_that(walker.position).is_equal(Vector2(56, 40))
	assert_bool(walker.is_moving).is_false()
	assert_array(events).is_equal(["turned (1, 0)", "started (2, 2) (3, 2)", "finished (3, 2)"])


func test_a_held_direction_covers_pace_times_time_however_the_frames_fall() -> void:
	_world.map({}, Vector2i(40, 3))
	var steady := Steady.new()
	var walker := _world.walker(Vector2i(0, 1), steady)
	for delta: float in [0.1, 0.37, 0.013, 0.5, 0.25, 0.03]:
		walker.advance(delta)
	assert_float(walker.position.x).is_equal_approx(8.0 + 16.0 * 4.0 * 1.263, 0.001)
	assert_bool(walker.is_moving).is_true()


func test_running_and_the_pace_hook_set_the_pace_of_each_step() -> void:
	_world.map()
	var walker := _world.walker(Vector2i(1, 1))
	walker.step(RIGHT, true)
	walker.advance(0.125)
	assert_bool(walker.is_moving).is_false()
	var asked: Array[String] = []
	_world.hooks.add(&"step_pace", &"bike", func(pace: float, who: WgWalker, direction: Vector2i, run: bool) -> float:
		asked.append("%s %s %s %s" % [pace, who == walker, direction, run])
		return 16.0)
	walker.step(RIGHT)
	walker.advance(0.0625)
	assert_bool(walker.is_moving).is_false()
	assert_array(asked).is_equal(["4.0 true (1, 0) false"])


func test_a_refused_step_faces_the_obstacle_and_bumps_once_per_push() -> void:
	_world.map({Vector2i(3, 2): T.WALL})
	var walker := _world.walker(Vector2i(2, 2))
	var events := _events(walker)
	for frame in 3:
		assert_bool(walker.step(RIGHT)).is_false()
		walker.advance(0.016)
	walker.advance(0.016)
	walker.step(RIGHT)
	assert_array(events).is_equal(["turned (1, 0)", "bumped (1, 0)", "bumped (1, 0)"])
	assert_that(walker.cell).is_equal(Vector2i(2, 2))


func test_backing_away_keeps_the_facing() -> void:
	_world.map()
	var walker := _world.walker(Vector2i(2, 2))
	walker.turn(DOWN)
	walker.step(UP, false, false)
	assert_that(walker.facing).is_equal(DOWN)
	assert_bool(walker.is_moving).is_true()


func test_walkers_never_head_for_the_same_cell_unless_going_through() -> void:
	_world.map()
	var first := _world.walker(Vector2i(1, 1))
	var second := _world.walker(Vector2i(3, 1))
	assert_bool(first.step(RIGHT)).is_true()
	assert_bool(second.step(LEFT)).is_false()
	assert_object(_world.walkers.at(Vector2i(2, 1))).is_same(first)
	assert_object(_world.walkers.at(Vector2i(1, 1))).is_same(first)
	first.advance(1.0)
	assert_object(_world.walkers.at(Vector2i(1, 1))).is_null()
	var ghost := _world.walker(Vector2i(2, 2))
	ghost.through = true
	assert_object(_world.walkers.at(Vector2i(2, 2))).is_null()
	assert_bool(ghost.step(UP)).is_true()


func test_a_ramp_lifts_the_walker_and_its_z_index_and_levels_do_not_meet() -> void:
	var map := _world.map()
	T.layer(map, _world.tile_set, {Vector2i(2, 1): T.RAMP, Vector2i(2, 2): T.DECK, Vector2i(2, 3): T.DECK})
	var walker := _world.walker(Vector2i(2, 0))
	walker.step(DOWN)
	walker.advance(1.0)
	walker.step(DOWN)
	walker.advance(1.0)
	assert_int(walker.level).is_equal(1)
	assert_int(walker.z_index).is_equal(2)
	var below := _world.walker(Vector2i(1, 2))
	assert_bool(below.step(RIGHT)).is_true()
	assert_object(_world.walkers.at(Vector2i(2, 2), 1)).is_same(walker)


func test_a_ledge_is_jumped_its_way_in_one_step_of_two_cells() -> void:
	_world.map({Vector2i(2, 2): T.LEDGE})
	var walker := _world.walker(Vector2i(2, 1), null, World.frames(["walk_down"]))
	var sprite := walker.get_node("Sprite") as AnimatedSprite2D
	var shadow := walker.get_node("Shadow") as Sprite2D
	assert_bool(walker.step(DOWN)).is_true()
	walker.advance(0.2)
	assert_bool(walker.is_jumping).is_true()
	assert_that(walker.position).is_equal(Vector2(40, 40))
	assert_that(sprite.position).is_equal(Vector2(0, -8))
	assert_bool(shadow.visible).is_true()
	walker.advance(0.2)
	assert_that(walker.cell).is_equal(Vector2i(2, 3))
	assert_that(sprite.position).is_equal(Vector2.ZERO)
	assert_bool(shadow.visible).is_false()
	assert_bool(walker.step(UP)).is_false()


func test_a_ledge_with_nowhere_to_land_or_a_walker_that_does_not_jump_bumps() -> void:
	_world.map({Vector2i(2, 2): T.LEDGE, Vector2i(2, 3): T.WALL, Vector2i(5, 2): T.LEDGE})
	assert_bool(_world.walker(Vector2i(2, 1)).step(DOWN)).is_false()
	var grounded := _world.walker(Vector2i(5, 1))
	grounded.jumps = false
	assert_bool(grounded.step(DOWN)).is_false()


func test_ice_slides_the_walker_straight_until_stopped_or_off_the_ice() -> void:
	_world.map({Vector2i(2, 1): T.ICE, Vector2i(3, 1): T.ICE, Vector2i(4, 1): T.ICE, Vector2i(5, 1): T.WALL, Vector2i(2, 3): T.ICE})
	var steady := Steady.new()
	steady.direction = Vector2i.ZERO
	var walker := _world.walker(Vector2i(1, 1), steady)
	walker.step(RIGHT)
	walker.advance(2.0)
	assert_that(walker.cell).is_equal(Vector2i(4, 1))
	assert_bool(walker.is_sliding).is_false()
	assert_int(steady.asked).is_equal(0)
	var other := _world.walker(Vector2i(1, 3))
	other.step(RIGHT)
	other.advance(2.0)
	assert_that(other.cell).is_equal(Vector2i(3, 3))


func test_a_walker_that_does_not_slide_walks_on_ice() -> void:
	_world.map({Vector2i(2, 1): T.ICE, Vector2i(3, 1): T.ICE})
	var walker := _world.walker(Vector2i(1, 1))
	walker.slides = false
	walker.step(RIGHT)
	walker.advance(2.0)
	assert_that(walker.cell).is_equal(Vector2i(2, 1))


func test_bad_directions_are_logged_and_refused() -> void:
	_world.map()
	var walker := _world.walker(Vector2i(1, 1))
	assert_bool(walker.step(Vector2i(1, 1))).is_false()
	walker.turn(Vector2i.ZERO)
	assert_that(walker.facing).is_equal(DOWN)
	assert_array(_world.logged).is_equal(["ERROR (1, 1) is not up, down, left or right", "ERROR (0, 0) is not up, down, left or right"])


func test_a_freed_walker_gives_its_cells_back() -> void:
	_world.map()
	var walker := _world.walker(Vector2i(1, 1))
	walker.step(RIGHT)
	walker.free()
	assert_object(_world.walkers.at(Vector2i(1, 1))).is_null()
	assert_object(_world.walkers.at(Vector2i(2, 1))).is_null()


func _sprite(walker: WgWalker) -> AnimatedSprite2D:
	return walker.get_node("Sprite") as AnimatedSprite2D


func test_each_state_plays_its_animation_facing_the_right_way() -> void:
	_world.map()
	var walker := _world.walker(Vector2i(2, 1), null, World.frames(["idle_down", "walk_right", "run_right", "turn_left", "idle_left"]))
	var sprite := _sprite(walker)
	assert_str(sprite.animation).is_equal("idle_down")
	walker.step(RIGHT)
	walker.advance(0.1)
	assert_str(sprite.animation).is_equal("walk_right")
	walker.advance(0.2)
	walker.step(RIGHT, true)
	walker.advance(0.01)
	assert_str(sprite.animation).is_equal("run_right")
	assert_float(sprite.speed_scale).is_equal(1.0)
	walker.advance(1.0)
	walker.step(RIGHT)
	walker.advance(0.0)
	assert_str(sprite.animation).is_equal("walk_right")
	walker.advance(1.0)
	walker.turn(LEFT)
	walker.advance(0.0)
	assert_str(sprite.animation).is_equal("turn_left")


func test_missing_animations_fall_back_on_the_walk() -> void:
	_world.map()
	var walker := _world.walker(Vector2i(2, 1), null, World.frames(["walk_right", "walk_down"]))
	var sprite := _sprite(walker)
	assert_str(sprite.animation).is_equal("walk_down")
	assert_bool(sprite.is_playing()).is_false()
	assert_int(sprite.frame).is_equal(0)
	walker.step(RIGHT, true)
	walker.advance(0.01)
	assert_str(sprite.animation).is_equal("walk_right")
	assert_float(sprite.speed_scale).is_equal(2.0)
	walker.advance(1.0)
	walker.turn(DOWN)
	walker.advance(0.0)
	assert_str(sprite.animation).is_equal("walk_down")
	assert_bool(sprite.is_playing()).is_false()


func test_the_animation_hook_names_another_state() -> void:
	_world.map()
	var walker := _world.walker(Vector2i(2, 1), null, World.frames(["bike_down", "walk_down"]))
	_world.hooks.add(&"walker_animation", &"bike", func(state: String, who: WgWalker) -> String:
		return "bike" if who == walker else state)
	walker.advance(0.0)
	assert_str(_sprite(walker).animation).is_equal("bike_down")


func test_feet_go_on_from_step_to_step_and_freeze_on_ice() -> void:
	_world.map({Vector2i(5, 1): T.ICE, Vector2i(6, 1): T.ICE})
	var walker := _world.walker(Vector2i(1, 1), Steady.new(), World.frames(["walk_right"]))
	var sprite := _sprite(walker)
	walker.advance(0.1)
	sprite.frame = 1
	walker.advance(0.3)
	assert_that(walker.cell).is_equal(Vector2i(2, 1))
	assert_int(sprite.frame).is_equal(1)
	assert_bool(sprite.is_playing()).is_true()
	walker.advance(0.7)
	assert_bool(walker.is_sliding).is_true()
	assert_bool(sprite.is_playing()).is_false()


func test_movement_config_resets_impossible_values_and_keeps_unset_actions() -> void:
	var config := WgMovementConfig.new()
	var problems := config.load_data({"walkPace": 0, "jumpHeight": -2, "holdSeconds": -1, "actions": {"run": "dash", "jump": "x"}}, "movement_config.json")
	assert_array(problems).has_size(4)
	assert_float(config.walk_pace).is_equal(4.0)
	assert_float(config.jump_height).is_equal(8.0)
	assert_float(config.hold_seconds).is_equal(0.12)
	assert_str(config.actions["run"]).is_equal("dash")
	assert_str(config.actions["up"]).is_equal("ui_up")
	assert_bool(config.actions.has("jump")).is_false()
