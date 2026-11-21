extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const MapBuilder := preload("res://tests/support/map_builder.gd")
const RecordingScreen := preload("res://tests/support/recording_screen.gd")
const SteadyController := preload("res://tests/support/steady_controller.gd")
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


## Starts a scripted walk; the returned array holds its result once done.
func _walk(walker: WgWalker, directions: Array, options := {}) -> Array:
	var result := [null]
	_await_walk(walker, directions, options, result)
	return result


func _await_walk(walker: WgWalker, directions: Array, options: Dictionary, result: Array) -> void:
	result[0] = await _world.walkers.walk(walker, directions, options)


func _walk_to(walker: WgWalker, cell: Vector2i) -> Array:
	var result := [null]
	_await_walk_to(walker, cell, result)
	return result


func _await_walk_to(walker: WgWalker, cell: Vector2i, result: Array) -> void:
	result[0] = await _world.walkers.walk_to(walker, cell)


## Advances `walker` frame by frame, real frames passing, until `result` is set.
func _until_done(walker: WgWalker, result: Array) -> void:
	for frame in 400:
		if result[0] != null or not is_instance_valid(walker):
			return
		walker.advance(0.05)
		await get_tree().process_frame


func test_a_walk_takes_each_step_in_turn_and_returns_true() -> void:
	_world.map({}, Vector2i(20, 20))
	var walker := _world.walker(Vector2i(5, 5))
	var result := _walk(walker, [RIGHT, RIGHT, UP])
	walker.advance(0.5)
	assert_that(walker.cell).is_equal(Vector2i(7, 5))
	assert_that(result[0]).is_null()
	walker.advance(0.25)
	assert_that(walker.cell).is_equal(Vector2i(7, 4))
	assert_that(walker.facing).is_equal(UP)
	assert_bool(result[0]).is_true()


func test_a_walk_may_back_away_or_run() -> void:
	_world.map({}, Vector2i(20, 20))
	var walker := _world.walker(Vector2i(5, 5))
	walker.facing = UP
	var back := _walk(walker, [DOWN], {"face": false})
	walker.advance(0.25)
	assert_bool(back[0]).is_true()
	assert_that(walker.facing).is_equal(UP)
	var ran := _walk(walker, [RIGHT], {"run": true})
	walker.advance(0.125)
	assert_bool(ran[0]).is_true()


func test_the_controller_waits_during_a_walk_and_dialogue_does_not_stop_it() -> void:
	_world.map({}, Vector2i(20, 20))
	var controller := SteadyController.new()
	var walker := _world.walker(Vector2i(5, 5), controller)
	_world.screens.register(&"menu", _world.sandbox.scene("menu.tscn", RecordingScreen))
	_world.screens.open(&"menu")
	var result := _walk(walker, [UP])
	walker.advance(0.25)
	assert_that(walker.cell).is_equal(Vector2i(5, 4))
	assert_bool(result[0]).is_true()
	assert_int(controller.asked).is_equal(0)


func test_a_taken_cell_is_waited_for_then_given_up() -> void:
	_world.map({}, Vector2i(20, 20))
	var walker := _world.walker(Vector2i(5, 5))
	var bumps := [0]
	walker.bumped.connect(func(_direction: Vector2i) -> void: bumps[0] += 1)
	var blocker := _world.walker(Vector2i(6, 5))
	var waited := _walk(walker, [RIGHT])
	walker.advance(1.0)
	assert_that(walker.cell).is_equal(Vector2i(5, 5))
	assert_that(waited[0]).is_null()
	blocker.free()
	walker.advance(0.25)
	assert_bool(waited[0]).is_true()
	_world.walker(Vector2i(7, 5))
	var given_up := _walk(walker, [RIGHT])
	walker.advance(1.9)
	assert_that(given_up[0]).is_null()
	walker.advance(0.2)
	assert_bool(given_up[0]).is_false()
	assert_int(bumps[0]).is_equal(0)


func test_skip_blocked_skips_a_taken_cell() -> void:
	_world.map({}, Vector2i(20, 20))
	var walker := _world.walker(Vector2i(5, 5))
	_world.walker(Vector2i(6, 5))
	var result := _walk(walker, [RIGHT, UP], {"skip_blocked": true})
	walker.advance(0.25)
	assert_that(walker.cell).is_equal(Vector2i(5, 4))
	assert_bool(result[0]).is_true()


func test_a_walk_is_cut_short_by_another_walk_by_freeing_or_by_a_warp() -> void:
	_world.map({}, Vector2i(20, 20))
	var walker := _world.walker(Vector2i(5, 5))
	var first := _walk(walker, [RIGHT, RIGHT])
	var second := _walk(walker, [UP])
	assert_bool(first[0]).is_false()
	walker.free()
	assert_bool(second[0]).is_false()
	# The traveller lives on through the warp: only the warp ends its walk.
	var traveller := _world.walker(Vector2i(2, 2))
	_world.maps.traveller = traveller
	var warped := _walk(traveller, [RIGHT, RIGHT])
	var build := MapBuilder.new(_world.sandbox)
	var town := build.map(&"town")
	MapBuilder.spawn(town, "Spawn", Vector2(8, 8))
	build.save("town", town)
	await _world.maps.go_to(&"town", &"Spawn")
	assert_bool(warped[0]).is_false()


func test_walk_to_finds_its_way_around_walls_and_over_ledges() -> void:
	var cells := {}
	for y in range(2, 9):
		cells[Vector2i(7, y)] = T.WALL
	_world.map(cells, Vector2i(20, 20))
	var walker := _world.walker(Vector2i(5, 5))
	var result := _walk_to(walker, Vector2i(9, 5))
	await _until_done(walker, result)
	assert_bool(result[0]).is_true()
	assert_that(walker.cell).is_equal(Vector2i(9, 5))
	var fenced := {Vector2i(4, 6): T.LEDGE, Vector2i(3, 6): T.WALL, Vector2i(5, 6): T.WALL}
	_world.map(fenced, Vector2i(10, 10))
	var jumper := _world.walker(Vector2i(4, 5))
	var jumped := _walk_to(jumper, Vector2i(4, 8))
	await _until_done(jumper, jumped)
	assert_bool(jumped[0]).is_true()
	assert_that(jumper.cell).is_equal(Vector2i(4, 8))


func test_characters_do_not_block_a_path_search() -> void:
	var cells := {}
	for y in range(0, 10):
		if y != 5:
			cells[Vector2i(7, y)] = T.WALL
	_world.map(cells, Vector2i(10, 10))
	var walker := _world.walker(Vector2i(5, 5))
	var passer := _world.walker(Vector2i(7, 5))
	var result := _walk_to(walker, Vector2i(9, 5))
	for frame in 5:
		await get_tree().process_frame
	passer.free()
	await _until_done(walker, result)
	assert_bool(result[0]).is_true()


func test_walk_to_gives_up_without_a_path_within_path_cells() -> void:
	_world.sandbox.write_json("config/movement.json", {"path_cells": 30})
	var cells := {Vector2i(14, 13): T.WALL, Vector2i(14, 15): T.WALL, Vector2i(13, 14): T.WALL, Vector2i(15, 14): T.WALL}
	_world.map(cells, Vector2i(20, 20))
	var walker := _world.walker(Vector2i(2, 2))
	var enclosed := _walk_to(walker, Vector2i(14, 14))
	await _until_done(walker, enclosed)
	assert_bool(enclosed[0]).is_false()
	var far := _walk_to(walker, Vector2i(12, 12))
	await _until_done(walker, far)
	assert_bool(far[0]).is_false()
	assert_that(walker.cell).is_equal(Vector2i(2, 2))


func test_turn_toward_faces_along_the_longer_axis() -> void:
	_world.map({}, Vector2i(20, 20))
	var walker := _world.walker(Vector2i(5, 5))
	var other := _world.walker(Vector2i(8, 4))
	walker.turn_toward(other)
	assert_that(walker.facing).is_equal(RIGHT)
	other.position = _world.tiles.center_of(Vector2i(4, 9))
	walker.turn_toward(other)
	assert_that(walker.facing).is_equal(DOWN)


func test_a_walker_may_step_into_a_cell_another_is_leaving() -> void:
	_world.map({}, Vector2i(20, 20))
	var follower := _world.walker(Vector2i(5, 5))
	var leader := _world.walker(Vector2i(6, 5))
	assert_bool(follower.step(RIGHT)).is_false()
	leader.step(UP)
	assert_bool(follower.step(RIGHT)).is_true()
	follower.advance(1.0)
	leader.advance(1.0)
	leader.step(RIGHT)
	assert_bool(follower.step(UP)).is_true()


func test_wrong_options_and_config_are_logged() -> void:
	_world.sandbox.write_json("config/movement.json", {"patience": -1, "path_cells": 0})
	_world.map({}, Vector2i(20, 20))
	var walker := _world.walker(Vector2i(5, 5))
	_walk(walker, [RIGHT], {"jump": true})
	assert_float(_world.walkers.movement().patience).is_equal(2.0)
	assert_int(_world.walkers.movement().path_cells).is_equal(400)
	assert_array(_world.logged).is_equal([
		"WARN unknown walk option 'jump'",
		"WARN movement.json: patience cannot be negative, got -1.0; using 2",
		"WARN movement.json: path_cells must be positive, got 0; using 400",
	])
