extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const MapBuilder := preload("res://tests/support/map_builder.gd")
const Steady := preload("res://tests/support/steady_controller.gd")
const T := preload("res://tests/support/tile_builder.gd")

const UP := Vector2i.UP
const DOWN := Vector2i.DOWN
const LEFT := Vector2i.LEFT
const RIGHT := Vector2i.RIGHT

var _world: World
var _player: WgWalker


func before_test() -> void:
	_world = World.new(self)


func after_test() -> void:
	if _world.followers != null:
		for follower: WgFollower in _world.followers.line:
			_world.followers.remove(follower)
			follower.free()
	_world.root.free()
	_world.cleanup()


## A map of `cells` with the traveller on `at`.
func _field(at := Vector2i(5, 5), cells := {}) -> void:
	_world.map(cells, Vector2i(20, 20))
	_player = _world.walker(at)
	_world.maps.traveller = _player


## A follower in line, moved only by the test; `frames`: its sprite and a
## shadow.
func _follower(frames: SpriteFrames = null) -> WgFollower:
	var follower := WgFollower.new()
	if frames != null:
		var sprite := AnimatedSprite2D.new()
		sprite.name = "Sprite"
		sprite.sprite_frames = frames
		follower.add_child(sprite)
		var shadow := Sprite2D.new()
		shadow.name = "Shadow"
		follower.add_child(shadow)
	_world.followers.add(follower)
	follower.set_process(false)
	return follower


## Advances the traveller, then the line, as the frame would.
func _tick(seconds: float) -> void:
	_player.advance(seconds)
	for follower: WgFollower in _world.followers.line:
		follower.advance(seconds)


func _step(direction: Vector2i, run := false) -> void:
	_player.step(direction, run)
	_tick(_player.step_seconds)


func _centre(cell: Vector2i) -> Vector2:
	return _world.tiles.center_of(cell)


func test_it_waits_hidden_on_the_travellers_cell_and_shows_on_the_first_step() -> void:
	_field()
	var follower := _follower()
	assert_object(follower.get_parent()).is_same(_player.get_parent())
	assert_bool(follower.visible).is_false()
	assert_that(follower.cell).is_equal(Vector2i(5, 5))
	assert_bool(follower.through).is_true()
	_player.step(RIGHT)
	_tick(0.1)
	assert_bool(follower.visible).is_true()
	assert_bool(follower.is_moving).is_false()
	assert_that(follower.cell).is_equal(Vector2i(5, 5))


func test_it_replays_the_leaders_last_step_in_the_same_frame_and_as_long() -> void:
	_field()
	var follower := _follower()
	_step(RIGHT)
	_player.step(DOWN)
	assert_bool(follower.is_moving).is_true()
	assert_that(follower.destination).is_equal(Vector2i(6, 5))
	assert_that(follower.facing).is_equal(RIGHT)
	_tick(0.1)
	assert_that(follower.global_position).is_equal(_centre(Vector2i(5, 5)).lerp(_centre(Vector2i(6, 5)), 0.4))
	_tick(0.15)
	assert_bool(_player.is_moving).is_false()
	assert_bool(follower.is_moving).is_false()
	assert_that(follower.cell).is_equal(Vector2i(6, 5))
	# Its leader below it now: it faces it.
	assert_that(follower.facing).is_equal(DOWN)


func test_a_frame_falling_across_two_steps_keeps_it_in_step() -> void:
	_field()
	_player.add_child(Steady.new())
	_player.controller = _player.get_child(-1)
	var follower := _follower()
	_tick(0.25)
	_tick(0.2)
	# The leader's second step ends 0.05 s into this frame, its third starts at once.
	_tick(0.1)
	assert_that(follower.destination).is_equal(Vector2i(7, 5))
	assert_float(follower.step_progress).is_equal_approx(_player.step_progress, 0.0001)
	assert_float(follower.step_progress).is_equal_approx(0.2, 0.0001)


func test_running_is_replayed_running() -> void:
	_field()
	var follower := _follower()
	_step(RIGHT, true)
	_player.step(RIGHT, true)
	assert_bool(follower.is_running).is_true()
	assert_float(follower.step_seconds).is_equal_approx(0.125, 0.0001)


func test_a_ledge_is_waited_behind_then_jumped_in_an_arc_in_the_leaders_step_time() -> void:
	_field(Vector2i(5, 4), {Vector2i(5, 6): T.LEDGE})
	var follower := _follower(World.frames(["walk_down"]))
	_step(DOWN)
	_player.step(DOWN)
	assert_bool(_player.is_jumping).is_true()
	# Replayed while the leader jumps: as long as the jump.
	assert_float(follower.step_seconds).is_equal_approx(_player.step_seconds, 0.0001)
	_tick(_player.step_seconds)
	_tick(1.0)
	assert_that(_player.cell).is_equal(Vector2i(5, 7))
	assert_that(follower.cell).is_equal(Vector2i(5, 5))
	assert_bool(follower.visible).is_true()
	_player.step(DOWN)
	assert_bool(follower.is_jumping).is_true()
	assert_that(follower.destination).is_equal(Vector2i(5, 7))
	assert_float(follower.step_seconds).is_equal_approx(0.25, 0.0001)
	assert_bool((follower.get_node("Shadow") as CanvasItem).visible).is_true()
	_tick(0.125)
	assert_float((follower.get_node("Sprite") as Node2D).position.y).is_less(0.0)
	_tick(0.125)
	assert_that(follower.cell).is_equal(Vector2i(5, 7))
	assert_bool(follower.is_jumping).is_false()


func test_a_slide_is_replayed_legs_still() -> void:
	_field(Vector2i(3, 5), {Vector2i(5, 5): T.ICE, Vector2i(6, 5): T.ICE})
	var follower := _follower(World.frames(["walk_right"]))
	var sprite := follower.get_node("Sprite") as AnimatedSprite2D
	_step(RIGHT)
	_player.step(RIGHT)
	_tick(0.1)
	assert_bool(sprite.is_playing()).is_true()
	_tick(0.15)
	assert_bool(_player.is_sliding).is_true()
	_tick(0.1)
	assert_that(follower.destination).is_equal(Vector2i(5, 5))
	assert_bool(sprite.is_playing()).is_false()
	assert_bool(follower.is_sliding).is_false()


func test_a_change_of_level_is_replayed() -> void:
	_field(Vector2i(2, 0), {Vector2i(2, 1): T.RAMP, Vector2i(2, 2): T.DECK, Vector2i(2, 3): T.DECK})
	var follower := _follower()
	_step(DOWN)
	_step(DOWN)
	_step(DOWN)
	assert_that(follower.cell).is_equal(Vector2i(2, 2))
	assert_int(follower.level).is_equal(1)
	assert_int(follower.z_index).is_equal(2)


func test_nothing_stops_it_and_the_leader_walks_back_through_it() -> void:
	_field()
	var follower := _follower()
	_world.hooks.add(&"can_step", &"no_follower", func(allowed: bool, _cell: Vector2i, _direction: Vector2i, _level: int, who: Node) -> bool:
		return false if who is WgFollower else allowed)
	_step(RIGHT)
	_step(RIGHT)
	assert_that(follower.cell).is_equal(Vector2i(6, 5))
	_step(LEFT)
	assert_that(_player.cell).is_equal(Vector2i(6, 5))
	assert_that(follower.cell).is_equal(Vector2i(7, 5))
	assert_that(follower.facing).is_equal(LEFT)


func test_a_character_in_the_way_does_not_stop_it() -> void:
	_field()
	var follower := _follower()
	_step(RIGHT)
	_step(RIGHT)
	var guard := _world.walker(Vector2i(7, 6))
	# The guard steps into the cell the leader leaves, as the follower does.
	_player.step(RIGHT)
	assert_bool(guard.step(UP)).is_true()
	guard.advance(0.25)
	_tick(0.25)
	assert_that(follower.cell).is_equal(Vector2i(7, 5))
	assert_object(_world.walkers.at(Vector2i(7, 5))).is_same(guard)


func test_a_turn_or_a_bump_does_not_move_it() -> void:
	_field(Vector2i(5, 5), {Vector2i(7, 5): T.WALL})
	var follower := _follower()
	_step(RIGHT)
	_player.turn(UP)
	_tick(0.3)
	assert_bool(follower.is_moving).is_false()
	assert_bool(_player.step(RIGHT)).is_false()
	_tick(0.3)
	assert_bool(follower.is_moving).is_false()
	assert_that(follower.cell).is_equal(Vector2i(5, 5))
	assert_that(follower.facing).is_equal(RIGHT)


func test_a_line_of_three_unfolds_step_by_step_the_first_drawn_over_the_next() -> void:
	_field()
	var first := _follower()
	var second := _follower()
	var third := _follower()
	assert_array(_world.followers.line).is_equal([first, second, third])
	assert_object(second.leader).is_same(first)
	var parent := _player.get_parent()
	assert_array([third.get_index(), second.get_index(), first.get_index(), _player.get_index()]).is_equal([0, 1, 2, 3].map(func(i: int) -> int: return i + parent.get_child_count() - 4))
	assert_int(first.process_priority).is_greater(_player.process_priority)
	assert_int(third.process_priority).is_greater(second.process_priority)
	_step(RIGHT)
	assert_array([first.visible, second.visible, third.visible]).is_equal([true, false, false])
	_step(RIGHT)
	assert_array([first.visible, second.visible, third.visible]).is_equal([true, true, false])
	_step(RIGHT)
	_step(RIGHT)
	assert_array([first.cell, second.cell, third.cell]).is_equal([Vector2i(8, 5), Vector2i(7, 5), Vector2i(6, 5)])
	assert_bool(third.visible).is_true()


func test_out_of_place_it_waits_on_its_leaders_cell() -> void:
	_field()
	var follower := _follower()
	_step(RIGHT)
	_step(RIGHT)
	_player.place_at(Vector2i(12, 3))
	_tick(0.0)
	assert_that(follower.cell).is_equal(Vector2i(12, 3))
	assert_bool(follower.visible).is_false()
	_step(DOWN)
	assert_bool(follower.visible).is_true()
	assert_that(follower.cell).is_equal(Vector2i(12, 3))


func test_while_a_script_walks_it_it_replays_nothing_then_waits_on_its_leaders_cell() -> void:
	_field()
	var follower := _follower()
	_step(RIGHT)
	_step(RIGHT)
	_world.walkers.walk(follower, [UP, UP])
	_tick(0.0)
	_player.step(RIGHT)
	assert_that(follower.destination).is_equal(Vector2i(6, 4))
	_tick(0.25)
	assert_that(follower.cell).is_equal(Vector2i(6, 4))
	_tick(0.25)
	# Its walk over, out of place.
	assert_that(follower.cell).is_equal(Vector2i(8, 5))
	assert_bool(follower.visible).is_false()


func test_the_hook_and_enabled_keep_the_line_off_the_map() -> void:
	_field()
	var follower := _follower()
	_world.followers.enabled = false
	assert_object(follower.get_parent()).is_null()
	_world.followers.enabled = true
	assert_object(follower.get_parent()).is_same(_player.get_parent())
	_world.hooks.add(&"followers_shown", &"none_here", func(_shown: bool, _map: WgMap) -> bool: return false)
	_world.followers.remove(follower)
	_world.followers.add(follower)
	assert_object(follower.get_parent()).is_null()
	assert_bool(_world.followers.is_shown()).is_false()


func test_removed_it_leaves_the_line_and_the_map_unfreed() -> void:
	_field()
	var first := _follower()
	var second := _follower()
	var changes := [0]
	_world.followers.line_changed.connect(func() -> void: changes[0] += 1)
	_world.followers.remove(first)
	assert_array(_world.followers.line).is_equal([second])
	assert_object(second.leader).is_same(_player)
	assert_object(first.get_parent()).is_null()
	assert_object(first.leader).is_null()
	assert_int(changes[0]).is_equal(1)
	_world.followers.add(second)
	assert_int(changes[0]).is_equal(1)
	first.free()


func test_followers_are_left_out_of_the_map_part() -> void:
	_field()
	_world.maps.current_id = &"field"
	_follower()
	_step(RIGHT)
	_step(RIGHT)
	assert_dict(_world.walkers.map_state()["walkers"]).is_empty()


func test_it_is_talked_to_like_any_character() -> void:
	_field()
	var follower := _follower()
	var talk := WgTalk.new()
	follower.add_child(talk)
	_step(RIGHT)
	_player.turn(LEFT)
	assert_object(_world.walkers.interactable_at(get_tree(), _player.cell + _player.facing, 0, LEFT)).is_same(talk)


## Maps saved for warps: a field with a spawn on (5, 5) and a house door on
## (5, 4), a house with its mat on (2, 6).
func _town() -> void:
	var build := MapBuilder.new(_world.sandbox)
	var field := build.map(&"field", Vector2i(20, 20))
	MapBuilder.spawn(field, "Spawn", Vector2(80, 80))
	MapBuilder.door(field, "HouseDoor", Vector2(80, 64), &"house", &"Mat", WgDoor.Kind.CONTACT, DOWN)
	build.save("field", field)
	var house := build.map(&"house", Vector2i(8, 8))
	MapBuilder.door(house, "Mat", Vector2(32, 96), &"field", &"HouseDoor", WgDoor.Kind.EXIT, DOWN)
	build.save("house", house)


func _travel(map_id: StringName, point: StringName) -> void:
	_player = WgWalker.new()
	_player.walkers = _world.walkers
	_world.maps.traveller = _player
	await _world.maps.go_to(map_id, point)
	_player.set_process(false)


func test_a_warp_puts_the_line_on_the_new_map_hidden_on_the_travellers_cell() -> void:
	_town()
	await _travel(&"field", &"Spawn")
	var follower := _follower()
	_step(RIGHT)
	_step(LEFT)
	_step(UP)
	await get_tree().process_frame
	assert_that(_world.maps.current_id).is_equal(&"house")
	assert_object(follower.get_parent()).is_same(_world.maps.current.entities_node())
	assert_that(follower.cell).is_equal(_player.cell)
	assert_bool(follower.visible).is_false()
	assert_bool(follower.is_moving).is_false()


func test_the_line_survives_a_reload_and_the_title() -> void:
	_town()
	await _travel(&"field", &"Spawn")
	var follower := _follower()
	_step(RIGHT)
	_step(RIGHT)
	await _world.maps.reload(&"none")
	assert_bool(is_instance_valid(follower)).is_true()
	assert_object(follower.get_parent()).is_same(_world.maps.current.entities_node())
	assert_that(follower.cell).is_equal(Vector2i(7, 5))
	assert_bool(follower.visible).is_false()
	_world.maps.clear()
	assert_bool(is_instance_valid(follower)).is_true()
	assert_object(follower.get_parent()).is_null()
	await _world.maps.go_to(&"house", &"Mat")
	assert_object(follower.get_parent()).is_same(_world.maps.current.entities_node())


func test_crossing_a_seam_carries_the_line_on_in_step() -> void:
	var build := MapBuilder.new(_world.sandbox)
	var route := build.map(&"route", Vector2i(10, 8))
	MapBuilder.spawn(route, "Spawn", Vector2(32, 96), DOWN)
	MapBuilder.link(route, WgMapLink.Side.SOUTH, &"island")
	build.save("route", route)
	var island := build.map(&"island", Vector2i(10, 6))
	MapBuilder.link(island, WgMapLink.Side.NORTH, &"route")
	build.save("island", island)
	await _travel(&"route", &"Spawn")
	var follower := _follower()
	_step(DOWN)
	_player.step(DOWN)
	_tick(0.25)
	assert_that(_world.maps.current_id).is_equal(&"island")
	_player.step(DOWN)
	_tick(0.1)
	assert_object(follower.get_parent()).is_same(_world.maps.current.entities_node())
	assert_bool(follower.visible).is_true()
	assert_bool(follower.is_moving).is_true()
	assert_that(follower.global_position).is_equal(_centre(Vector2i(2, 7)).lerp(_centre(Vector2i(2, 8)), 0.4))
	_tick(0.15)
	assert_that(follower.cell).is_equal(Vector2i(2, 8))


func test_the_line_off_the_map_is_freed_with_the_service() -> void:
	_field()
	var follower := _follower()
	_world.followers.enabled = false
	# The debug tools and the events' scripts hold the services too.
	_world.debug_tools = null
	_world.events.followers = null
	_world.followers = null
	assert_bool(is_instance_valid(follower)).is_false()


func test_an_exit_door_does_not_move_it_and_a_map_leaving_does_not_take_it() -> void:
	_town()
	await _travel(&"house", &"Mat")
	var follower := _follower()
	_step(UP)
	_step(DOWN)
	assert_that(follower.cell).is_equal(Vector2i(2, 5))
	assert_bool(_player.step(DOWN)).is_true()
	assert_bool(follower.is_moving).is_false()
	await get_tree().process_frame
	assert_that(_world.maps.current_id).is_equal(&"field")
	var field := _world.maps.current
	_world.hooks.run(&"map_leaving", [field])
	assert_bool(is_instance_valid(follower)).is_true()
	assert_object(follower.get_parent()).is_null()


func test_put_elsewhere_as_its_leader_steps_it_shows_on_the_cell_its_leader_leaves() -> void:
	_field()
	var follower := _follower()
	_step(RIGHT)
	_step(RIGHT)
	follower.place_at(Vector2i(2, 2))
	_player.step(DOWN)
	assert_bool(follower.is_moving).is_false()
	assert_that(follower.cell).is_equal(Vector2i(7, 5))
	assert_bool(follower.visible).is_true()


func test_a_slide_is_replayed_legs_still_all_down_the_line() -> void:
	_field(Vector2i(3, 5), {Vector2i(5, 5): T.ICE, Vector2i(6, 5): T.ICE, Vector2i(7, 5): T.ICE})
	_follower(World.frames(["walk_right"]))
	var second := _follower(World.frames(["walk_right"]))
	var sprite := second.get_node("Sprite") as AnimatedSprite2D
	_step(RIGHT)
	# The leader walks onto the ice and slides; the second follower replays
	# that step two behind.
	_player.step(RIGHT)
	_tick(0.25)
	_tick(0.25)
	_tick(0.1)
	assert_bool(_player.is_sliding).is_true()
	assert_that(second.destination).is_equal(Vector2i(5, 5))
	assert_bool(second.is_moving).is_true()
	assert_bool(sprite.is_playing()).is_false()


func test_a_script_taking_over_mid_replay_walks_it_at_its_own_pace() -> void:
	_field()
	var follower := _follower()
	_step(RIGHT)
	_player.step(RIGHT)
	_tick(0.1)
	_world.walkers.walk(follower, [UP])
	_tick(0.15)
	_tick(0.1)
	assert_that(follower.destination).is_equal(Vector2i(6, 4))
	assert_float(follower.step_progress).is_equal_approx(0.4, 0.0001)


func test_a_follower_freed_leaves_the_line_which_closes_up() -> void:
	_field()
	var first := _follower()
	var second := _follower()
	var changes := [0]
	_world.followers.line_changed.connect(func() -> void: changes[0] += 1)
	first.free()
	await get_tree().process_frame
	assert_array(_world.followers.line).is_equal([second])
	assert_object(second.leader).is_same(_player)
	assert_int(changes[0]).is_equal(1)


func test_waiting_on_its_leaders_cell_it_takes_its_level() -> void:
	_field()
	var follower := _follower()
	_player.place_at(Vector2i(5, 5), 1)
	_tick(0.0)
	assert_int(follower.level).is_equal(1)
	assert_int(follower.z_index).is_equal(2)
	assert_bool(follower.visible).is_false()


func test_one_joining_leaves_the_others_walking() -> void:
	_field()
	var first := _follower()
	_step(RIGHT)
	_player.step(RIGHT)
	_tick(0.1)
	var second := _follower()
	assert_bool(first.visible).is_true()
	assert_bool(first.is_moving).is_true()
	assert_bool(second.visible).is_false()
	assert_that(second.cell).is_equal(Vector2i(6, 5))
	assert_int(second.get_index()).is_less(first.get_index())


func test_removed_mid_step_it_ends_its_step_and_shows() -> void:
	_field()
	var follower := _follower()
	_step(RIGHT)
	_player.step(RIGHT)
	_tick(0.1)
	_world.followers.remove(follower)
	assert_bool(follower.is_moving).is_false()
	assert_that(follower.cell).is_equal(Vector2i(6, 5))
	assert_bool(follower.visible).is_true()
	follower.free()


func test_processed_by_the_tree_it_keeps_to_its_leaders_step() -> void:
	_field()
	_player.add_child(Steady.new())
	_player.controller = _player.get_child(-1)
	var follower := _follower()
	_player.set_process(true)
	follower.set_process(true)
	var seen := 0
	for frame in 600:
		await get_tree().process_frame
		if _player.cell.x >= 10:
			break
		if follower.is_moving and _player.is_moving:
			assert_float(follower.step_progress).is_equal_approx(_player.step_progress, 0.0001)
			seen += 1
	assert_int(seen).is_greater(5)
	_player.set_process(false)
	follower.set_process(false)


func test_a_neighbour_dropped_on_a_crossing_does_not_take_the_line() -> void:
	var build := MapBuilder.new(_world.sandbox)
	var route := build.map(&"route", Vector2i(10, 8))
	MapBuilder.spawn(route, "Spawn", Vector2(32, 96), DOWN)
	MapBuilder.link(route, WgMapLink.Side.SOUTH, &"island")
	build.save("route", route)
	build.save("island", build.map(&"island", Vector2i(10, 6)))
	await _travel(&"route", &"Spawn")
	var follower := _follower()
	_step(DOWN)
	_player.step(DOWN)
	_tick(0.25)
	assert_that(_world.maps.current_id).is_equal(&"island")
	assert_array(_world.maps.neighbours).is_empty()
	assert_bool(is_instance_valid(follower)).is_true()
	assert_object(follower.get_parent()).is_same(_world.maps.current.entities_node())
	assert_that(follower.cell).is_equal(Vector2i(2, 7))
