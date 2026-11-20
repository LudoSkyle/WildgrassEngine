extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const MapBuilder := preload("res://tests/support/map_builder.gd")
const RecordingScreen := preload("res://tests/support/recording_screen.gd")
const T := preload("res://tests/support/tile_builder.gd")

const UP := Vector2i.UP
const DOWN := Vector2i.DOWN
const LEFT := Vector2i.LEFT
const RIGHT := Vector2i.RIGHT
const ACTIONS := ["ui_up", "ui_down", "ui_left", "ui_right", "run"]

var _world: World
var _build: MapBuilder
var _added_run := false


func before_test() -> void:
	_world = World.new(self)
	_build = MapBuilder.new(_world.sandbox)
	_added_run = not InputMap.has_action("run")
	if _added_run:
		InputMap.add_action("run")


func after_test() -> void:
	for action: String in ACTIONS:
		if InputMap.has_action(action):
			Input.action_release(action)
	if _added_run:
		InputMap.erase_action("run")
	_world.root.free()
	_world.cleanup()


## A 20×20 field with a spawn point on the corner of cell (5, 5).
func _field() -> void:
	var field := _build.map(&"field")
	field.size = Vector2i(20, 20)
	MapBuilder.spawn(field, "Spawn", Vector2(80, 80))
	_build.save("field", field)


## The traveller, with its input and `frames`, put on `point` of `map_id`.
func _player(map_id: StringName, point: StringName, frames: SpriteFrames = null) -> WgWalker:
	var walker := WgWalker.new()
	walker.walkers = _world.walkers
	walker.add_child(WgPlayerInput.new())
	if frames != null:
		var sprite := AnimatedSprite2D.new()
		sprite.name = "Sprite"
		sprite.sprite_frames = frames
		walker.add_child(sprite)
	_world.maps.traveller = walker
	await _world.maps.go_to(map_id, point)
	walker.set_process(false)
	return walker


func test_a_tap_turns_and_a_hold_walks() -> void:
	_field()
	var walker: WgWalker = await _player(&"field", &"Spawn")
	Input.action_press("ui_left")
	walker.advance(0.05)
	Input.action_release("ui_left")
	walker.advance(0.05)
	assert_that(walker.facing).is_equal(LEFT)
	assert_bool(walker.is_moving).is_false()
	Input.action_press("ui_down")
	walker.advance(0.1)
	assert_that(walker.facing).is_equal(DOWN)
	assert_bool(walker.is_moving).is_false()
	walker.advance(0.05)
	assert_bool(walker.is_moving).is_true()


func test_held_directions_walk_on_and_the_last_pressed_wins_until_released() -> void:
	_field()
	var walker: WgWalker = await _player(&"field", &"Spawn")
	Input.action_press("ui_right")
	walker.advance(0.12)
	walker.advance(0.3)
	Input.action_press("ui_up")
	walker.advance(0.2)
	assert_that(walker.cell).is_equal(Vector2i(7, 5))
	assert_that(walker.facing).is_equal(UP)
	assert_bool(walker.is_moving).is_true()
	Input.action_release("ui_up")
	walker.advance(0.25)
	assert_that(walker.cell).is_equal(Vector2i(7, 4))
	assert_that(walker.facing).is_equal(RIGHT)


func test_the_run_action_runs() -> void:
	_field()
	var walker: WgWalker = await _player(&"field", &"Spawn")
	Input.action_press("ui_right")
	Input.action_press("run")
	walker.advance(0.12)
	walker.advance(0.125)
	assert_that(walker.cell).is_equal(Vector2i(6, 5))
	assert_bool(walker.is_running).is_true()


func test_nothing_is_read_while_a_screen_is_open_or_a_warp_runs() -> void:
	_field()
	var walker: WgWalker = await _player(&"field", &"Spawn")
	_world.screens.register(&"menu", _world.sandbox.scene("menu.tscn", RecordingScreen))
	var menu := _world.screens.open(&"menu")
	Input.action_press("ui_right")
	walker.advance(0.5)
	assert_bool(walker.is_moving).is_false()
	assert_that(walker.facing).is_equal(DOWN)
	menu.close()
	_world.maps.is_changing = true
	walker.advance(0.5)
	assert_bool(walker.is_moving).is_false()
	_world.maps.is_changing = false
	walker.advance(0.12)
	assert_bool(walker.is_moving).is_true()


func test_an_action_missing_from_the_input_map_is_logged_once() -> void:
	_world.sandbox.write_json("Data/configs/movement_config.json", {"actions": {"run": "dash"}})
	_field()
	var walker: WgWalker = await _player(&"field", &"Spawn")
	Input.action_press("ui_right")
	for frame in 5:
		walker.advance(0.1)
	assert_array(_world.logged.filter(func(line: String) -> bool: return line.contains("dash"))).is_equal(["WARN no input action 'dash' (movement_config.json actions.run)"])
	assert_bool(walker.is_running).is_false()


## town: spawn on (5, 5), the house door on (5, 4). house: its mat on (2, 6),
## a wall below it.
func _town_and_house() -> void:
	var town := _build.map(&"town")
	MapBuilder.spawn(town, "Spawn", Vector2(80, 80))
	MapBuilder.door(town, "HouseDoor", Vector2(80, 64), &"house", &"Mat", WgDoor.Kind.CONTACT, DOWN)
	_build.save("town", town)
	var house := _build.map(&"house")
	MapBuilder.door(house, "Mat", Vector2(32, 96), &"town", &"HouseDoor", WgDoor.Kind.EXIT, DOWN)
	T.layer(house, T.tile_set(), {Vector2i(2, 7): T.WALL}, -1)
	_build.save("house", house)


func test_a_contact_door_warps_and_a_held_key_walks_on_into_the_new_map() -> void:
	_town_and_house()
	var walker: WgWalker = await _player(&"town", &"Spawn")
	Input.action_press("ui_up")
	walker.advance(0.12)
	walker.advance(0.25)
	assert_that(_world.maps.current_id).is_equal(&"house")
	assert_that(walker.cell).is_equal(Vector2i(2, 6))
	assert_that(walker.facing).is_equal(UP)
	walker.advance(0.0)
	assert_bool(walker.is_moving).is_true()
	assert_that(walker.facing).is_equal(UP)


func test_the_way_back_is_ignored_while_its_key_stays_held() -> void:
	# Two stairs, both taken by walking left: arriving on the second with Left
	# held must not take it at once.
	var cellar := _build.map(&"cellar")
	MapBuilder.door(cellar, "Stairs", Vector2(32, 32), &"attic", &"Stairs", WgDoor.Kind.EXIT, LEFT)
	_build.save("cellar", cellar)
	var attic := _build.map(&"attic")
	MapBuilder.door(attic, "Stairs", Vector2(80, 80), &"cellar", &"Stairs", WgDoor.Kind.EXIT, LEFT)
	_build.save("attic", attic)
	var walker: WgWalker = await _player(&"cellar", &"Stairs")
	Input.action_press("ui_left")
	walker.advance(0.12)
	assert_that(_world.maps.current_id).is_equal(&"attic")
	walker.advance(0.5)
	assert_that(_world.maps.current_id).is_equal(&"attic")
	assert_bool(walker.is_moving).is_false()
	Input.action_release("ui_left")
	walker.advance(0.0)
	Input.action_press("ui_left")
	walker.advance(0.12)
	assert_that(_world.maps.current_id).is_equal(&"cellar")


func test_an_exit_door_is_used_by_stepping_its_way_even_toward_a_wall() -> void:
	_town_and_house()
	var walker: WgWalker = await _player(&"house", &"Mat")
	assert_bool(walker.step(RIGHT)).is_true()
	assert_that(_world.maps.current_id).is_equal(&"house")
	walker.advance(1.0)
	walker.step(LEFT)
	walker.advance(1.0)
	assert_bool(walker.step(DOWN)).is_true()
	assert_that(_world.maps.current_id).is_equal(&"town")
	assert_that(walker.cell).is_equal(Vector2i(5, 5))
	assert_that(walker.facing).is_equal(DOWN)


func test_a_warp_during_a_step_drops_it_and_gives_its_cell_back() -> void:
	_field()
	_town_and_house()
	var walker: WgWalker = await _player(&"field", &"Spawn")
	walker.step(RIGHT)
	walker.advance(0.1)
	var on_arrival: Array[String] = []
	_world.maps.traveller_arrived.connect(func(_direction: Vector2i, _point: Node2D) -> void:
		on_arrival.append("%s %s" % [walker.position, walker.is_moving]))
	await _world.maps.go_to(&"town", &"Spawn")
	assert_array(on_arrival).is_equal(["(88.0, 88.0) false"])
	assert_bool(walker.is_moving).is_false()
	assert_that(walker.cell).is_equal(Vector2i(5, 5))
	assert_that(walker.position).is_equal(Vector2(88, 88))
	assert_object(_world.walkers.at(Vector2i(6, 5))).is_null()


func test_crossing_a_seam_keeps_facing_cell_and_animation() -> void:
	var route := _build.map(&"route")
	route.size = Vector2i(10, 8)
	MapBuilder.spawn(route, "Spawn", Vector2(32, 112), DOWN)
	MapBuilder.link(route, WgMapLink.Side.SOUTH, &"island", -2)
	_build.save("route", route)
	var island := _build.map(&"island")
	island.size = Vector2i(14, 6)
	MapBuilder.link(island, WgMapLink.Side.NORTH, &"route", 2)
	_build.save("island", island)
	var walker: WgWalker = await _player(&"route", &"Spawn", World.frames(["walk_down"]))
	var sprite := walker.get_node("Sprite") as AnimatedSprite2D
	Input.action_press("ui_down")
	walker.advance(0.12)
	walker.advance(0.1)
	sprite.frame = 1
	walker.advance(0.16)
	assert_that(_world.maps.current_id).is_equal(&"island")
	assert_object(walker.get_parent()).is_same(_world.maps.current.entities_node())
	assert_that(walker.cell).is_equal(Vector2i(2, 8))
	assert_that(walker.facing).is_equal(DOWN)
	assert_object(_world.walkers.at(Vector2i(2, 8))).is_same(walker)
	assert_int(sprite.frame).is_equal(1)


func test_a_reload_during_a_step_settles_the_walker_where_it_was() -> void:
	_field()
	var walker: WgWalker = await _player(&"field", &"Spawn")
	walker.step(RIGHT)
	walker.advance(0.2)
	await _world.maps.reload(&"none")
	assert_bool(walker.is_moving).is_false()
	assert_that(walker.cell).is_equal(Vector2i(6, 5))
	assert_that(walker.position).is_equal(Vector2(104, 88))
