extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const RecordingScreen := preload("res://tests/support/recording_screen.gd")
const T := preload("res://tests/support/tile_builder.gd")
const WaitingInteractable := preload("res://tests/support/waiting_interactable.gd")

var _world: World


func before_test() -> void:
	_world = World.new(self)


func after_test() -> void:
	Input.action_release("ui_right")
	_world.root.free()
	_world.cleanup()


func _wander(area := Rect2i(), tile_data := &"", step_chance := 1.0) -> WgWander:
	var wander := WgWander.new()
	wander.pause = Vector2(0.1, 0.1)
	wander.area = area
	wander.tile_data = tile_data
	wander.step_chance = step_chance
	wander.random_seed = 7
	return wander


## Advances `walker` by `seconds` in frames of 0.05 s; returns every cell it
## stood on.
func _run(walker: WgWalker, seconds: float) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [walker.cell]
	for frame in roundi(seconds / 0.05):
		walker.advance(0.05)
		if walker.cell not in cells:
			cells.append(walker.cell)
	return cells


func test_a_pace_sets_the_walking_pace_but_not_running() -> void:
	_world.map({}, Vector2i(20, 20))
	var walker := _world.walker(Vector2i(5, 5))
	walker.pace = 2.0
	walker.step(Vector2i.RIGHT)
	walker.advance(0.4)
	assert_bool(walker.is_moving).is_true()
	walker.advance(0.1)
	assert_that(walker.cell).is_equal(Vector2i(6, 5))
	walker.step(Vector2i.RIGHT, true)
	walker.advance(0.125)
	assert_that(walker.cell).is_equal(Vector2i(7, 5))


func test_a_wanderer_keeps_to_its_area() -> void:
	_world.map({}, Vector2i(20, 20))
	var walker := _world.walker(Vector2i(5, 5), _wander(Rect2i(4, 4, 3, 3)))
	var cells := _run(walker, 60.0)
	assert_int(cells.size()).is_greater(4)
	for cell: Vector2i in cells:
		assert_bool(Rect2i(4, 4, 3, 3).has_point(cell)).override_failure_message("left its area: %s" % cell).is_true()


func test_a_wanderer_keeps_to_its_tiles() -> void:
	var grass := {}
	for x in range(10, 13):
		for y in range(5, 8):
			grass[Vector2i(x, y)] = T.GRASS
	_world.map(grass, Vector2i(20, 20))
	var walker := _world.walker(Vector2i(11, 6), _wander(Rect2i(), &"grass"))
	var cells := _run(walker, 60.0)
	assert_int(cells.size()).is_greater(4)
	for cell: Vector2i in cells:
		assert_bool(grass.has(cell)).override_failure_message("left the grass: %s" % cell).is_true()


func test_a_wanderer_keeps_to_its_map_and_area_wherever_the_map_is_shown() -> void:
	var map := _world.map({}, Vector2i(4, 4))
	map.position = Vector2(32, 16)
	var walker := _world.walker(Vector2i(3, 2), _wander())
	for cell: Vector2i in _run(walker, 60.0):
		assert_bool(Rect2i(2, 1, 4, 4).has_point(cell)).override_failure_message("left its map: %s" % cell).is_true()
	walker.controller = _wander(Rect2i(1, 1, 2, 2))
	walker.add_child(walker.controller)
	for cell: Vector2i in _run(walker, 60.0).slice(1):
		assert_bool(Rect2i(3, 2, 2, 2).has_point(cell)).override_failure_message("left its area: %s" % cell).is_true()


func test_a_wanderer_never_walks_into_a_neighbour_shown_beside_its_map() -> void:
	_world.map({}, Vector2i(4, 4))
	var neighbour := WgMap.new()
	neighbour.size = Vector2i(4, 4)
	neighbour.position = Vector2(64, 0)
	T.layer(neighbour, _world.tile_set, {}, -1)
	_world.maps.host.add_child(neighbour)
	_world.maps.neighbours.append(neighbour)
	var walker := _world.walker(Vector2i(3, 1), _wander())
	for cell: Vector2i in _run(walker, 60.0):
		assert_int(cell.x).override_failure_message("walked into the neighbour: %s" % cell).is_less(4)


func test_a_wanderer_never_steps_onto_a_ledge_or_ice() -> void:
	_world.map({Vector2i(5, 6): T.LEDGE, Vector2i(6, 5): T.ICE, Vector2i(4, 5): T.WALL, Vector2i(5, 4): T.WALL}, Vector2i(20, 20))
	var walker := _world.walker(Vector2i(5, 5), _wander())
	assert_array(_run(walker, 30.0)).is_equal([Vector2i(5, 5)])


func test_a_wanderer_waits_its_pause_and_may_only_turn() -> void:
	_world.map({}, Vector2i(20, 20))
	var wander := _wander(Rect2i(), &"", 0.0)
	wander.pause = Vector2(1.0, 1.0)
	var walker := _world.walker(Vector2i(5, 5), wander)
	var turns: Array[Vector2i] = []
	walker.turned.connect(func(direction: Vector2i) -> void: turns.append(direction))
	_run(walker, 0.9)
	assert_array(turns).is_empty()
	assert_array(_run(walker, 20.0)).is_equal([Vector2i(5, 5)])
	assert_array(turns).is_not_empty()


func test_a_patrol_walks_its_route_in_straight_lines_and_loops() -> void:
	_world.map({}, Vector2i(20, 20))
	var patrol := WgPatrol.new()
	patrol.route = [Vector2i(5, 5), Vector2i(8, 5), Vector2i(8, 7)]
	var walker := _world.walker(Vector2i(5, 5), patrol)
	var steps: Array[Vector2i] = []
	walker.step_finished.connect(func(cell: Vector2i) -> void: steps.append(cell))
	_run(walker, 3.5)
	assert_array(steps).is_equal([
		Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5), Vector2i(8, 6), Vector2i(8, 7),
		Vector2i(7, 7), Vector2i(6, 7), Vector2i(5, 7), Vector2i(5, 6), Vector2i(5, 5),
		Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5), Vector2i(8, 6),
	])


func test_a_route_is_in_cells_of_the_map_wherever_it_is_shown() -> void:
	var map := _world.map({}, Vector2i(10, 10))
	map.position = Vector2(32, 16)
	var patrol := WgPatrol.new()
	patrol.route = [Vector2i(1, 1), Vector2i(3, 1)]
	var walker := _world.walker(Vector2i(1, 1), patrol)
	assert_array(_run(walker, 1.0)).is_equal([Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2)])


func test_a_patrol_waits_while_someone_is_in_the_way() -> void:
	_world.map({}, Vector2i(20, 20))
	var patrol := WgPatrol.new()
	patrol.route = [Vector2i(5, 5), Vector2i(8, 5)]
	var walker := _world.walker(Vector2i(5, 5), patrol)
	var blocker := _world.walker(Vector2i(7, 5))
	var bumps := [0]
	walker.bumped.connect(func(_direction: Vector2i) -> void: bumps[0] += 1)
	_run(walker, 2.0)
	assert_that(walker.cell).is_equal(Vector2i(6, 5))
	assert_that(walker.facing).is_equal(Vector2i.RIGHT)
	assert_int(bumps[0]).is_equal(0)
	blocker.free()
	_run(walker, 0.5)
	assert_that(walker.cell).is_equal(Vector2i(8, 5))


func test_a_route_point_off_the_map_is_skipped_and_logged_once() -> void:
	_world.map({}, Vector2i(10, 10))
	var patrol := WgPatrol.new()
	patrol.route = [Vector2i(5, 5), Vector2i(15, 5), Vector2i(7, 5)]
	var walker := _world.walker(Vector2i(5, 5), patrol)
	_run(walker, 3.0)
	assert_bool(walker.cell.x <= 7).is_true()
	assert_array(_world.logged).is_equal(["WARN %s: route point (15, 5) is off its map" % walker.name])


func test_nobody_moves_by_themselves_during_a_screen_a_warp_or_an_interaction() -> void:
	_world.map({}, Vector2i(20, 20))
	var walker := _world.walker(Vector2i(5, 5), _wander())
	_world.screens.register(&"menu", _world.sandbox.scene("menu.tscn", RecordingScreen))
	var menu := _world.screens.open(&"menu")
	assert_array(_run(walker, 2.0)).is_equal([Vector2i(5, 5)])
	menu.close()
	_world.maps.is_changing = true
	assert_array(_run(walker, 2.0)).is_equal([Vector2i(5, 5)])
	_world.maps.is_changing = false
	var player := _world.walker(Vector2i(15, 15))
	player.facing = Vector2i.UP
	_world.maps.traveller = player
	var sign_post := WaitingInteractable.new()
	sign_post.position = _world.tiles.center_of(Vector2i(15, 14))
	_world.maps.current.entities_node().add_child(sign_post)
	_world.walkers.interact(player)
	assert_array(_run(walker, 2.0)).is_equal([Vector2i(5, 5)])
	sign_post.release.emit()
	assert_int(_run(walker, 2.0).size()).is_greater(1)


func test_characters_may_move_during_dialogue_if_the_config_says_so() -> void:
	_world.sandbox.write_json("config/movement.json", {"still_during_dialogue": false})
	_world.map({}, Vector2i(20, 20))
	var walker := _world.walker(Vector2i(5, 5), _wander())
	_world.screens.register(&"menu", _world.sandbox.scene("menu.tscn", RecordingScreen))
	_world.screens.open(&"menu")
	assert_int(_run(walker, 2.0).size()).is_greater(1)


func test_the_traveller_is_always_asked_its_moves() -> void:
	_world.map({}, Vector2i(20, 20))
	var asked := [0]
	var counting := CountingController.new()
	counting.asked = asked
	var player := _world.walker(Vector2i(5, 5), counting)
	_world.maps.traveller = player
	_world.screens.register(&"menu", _world.sandbox.scene("menu.tscn", RecordingScreen))
	_world.screens.open(&"menu")
	player.advance(0.05)
	assert_int(asked[0]).is_equal(1)


class CountingController extends WgWalkerController:
	var asked: Array

	func _drive(_walker: WgWalker, _delta: float) -> void:
		asked[0] += 1
