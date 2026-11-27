extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const MapBuilder := preload("res://tests/support/map_builder.gd")

var _world: World
var _player: WgWalker


func before_test() -> void:
	_world = World.new(self)
	var build := MapBuilder.new(_world.sandbox)
	var town := build.map(&"harbour", Vector2i(12, 12))
	MapBuilder.spawn(town, "Spawn", Vector2(24, 24))
	var guard := WgWalker.new()
	guard.name = "Guard"
	guard.position = Vector2(88, 88)
	town.entities_node().add_child(guard)
	build.save("town", town)
	var cave := build.map(&"", Vector2i(8, 8))
	MapBuilder.spawn(cave, "Entrance", Vector2(56, 40), Vector2i.UP)
	build.save("cave", cave)
	_player = WgWalker.new()
	_player.name = "Player"
	_player.walkers = _world.walkers
	_world.maps.traveller = _player


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _guard() -> WgWalker:
	return _world.maps.current.get_node("Entities/Guard") as WgWalker


func test_the_player_and_the_walkers_of_the_map_come_back_where_they_stood() -> void:
	await _world.maps.go_to(&"town", &"Spawn")
	_player.place_at(Vector2i(3, 4), 1, Vector2i.LEFT)
	_guard().place_at(Vector2i(6, 2), 0, Vector2i.UP)
	_world.save.write(1)
	assert_that(_world.save.summary(1)).is_equal({"seconds": 0.0, "map": "town", "zone": "harbour"})
	await _world.maps.go_to(&"cave", &"Entrance")
	assert_bool(await _world.save.load_game(1)).is_true()
	assert_str(_world.maps.current_id).is_equal("town")
	assert_that(_player.cell).is_equal(Vector2i(3, 4))
	assert_int(_player.level).is_equal(1)
	assert_that(_player.facing).is_equal(Vector2i.LEFT)
	assert_that(_guard().cell).is_equal(Vector2i(6, 2))
	assert_that(_guard().facing).is_equal(Vector2i.UP)
	assert_object(_world.walkers.at(Vector2i(6, 2))).is_same(_guard())
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_world.save.path_of(1)))["parts"]["map"]
	assert_that(saved).is_equal({"map": "town", "cell": [3.0, 4.0], "level": 1.0, "facing": [-1.0, 0.0], "walkers": {"Entities/Guard": {"cell": [6.0, 2.0], "level": 0.0, "facing": [0.0, -1.0]}},
		"look": {"offset": [0.0, 0.0], "shadow": [0.0, 0.0], "shadow_shown": true}})


func test_cells_are_the_map_s_own_and_a_walker_gone_from_it_is_skipped() -> void:
	await _world.maps.go_to(&"town", &"Spawn")
	_world.maps.current.position = Vector2(80, 0)
	_player.place_at(Vector2i(8, 4))
	var elsewhere := WgWalker.new()
	elsewhere.walkers = _world.walkers
	_world.root.add_child(elsewhere)
	var state := _world.walkers.map_state()
	assert_that(state["cell"]).is_equal([3, 4])
	assert_array(state["walkers"].keys()).is_equal(["Entities/Guard"])
	state["walkers"]["Entities/Gone"] = {"cell": [1, 1]}
	await _world.walkers.restore_map(state)
	assert_that(_player.cell).is_equal(Vector2i(3, 4))
	assert_array(_world.logged).is_empty()


func test_a_lost_map_refuses_the_load_unless_the_game_names_another() -> void:
	await _world.maps.go_to(&"town", &"Spawn")
	_player.place_at(Vector2i(3, 4))
	_world.save.write(1)
	await _world.maps.go_to(&"cave", &"Entrance")
	_world.story.set_flag(&"now")
	DirAccess.remove_absolute(_world.sandbox.root + "maps/town.tscn")
	assert_bool(await _world.save.load_game(1)).is_false()
	assert_bool(_world.story.has(&"now")).is_true()
	var asked: Array[String] = []
	var instead := [&"nowhere"]
	_world.hooks.add(&"save_lost_map", &"test", func(found: StringName, lost: String, _state: Dictionary) -> StringName:
		asked.append(lost)
		return instead[0] if found.is_empty() else found)
	assert_bool(await _world.save.load_game(1)).is_false()
	instead[0] = &"cave"
	assert_bool(await _world.save.load_game(1)).is_true()
	assert_array(asked).is_equal(["town", "town"])
	assert_str(_world.maps.current_id).is_equal("cave")
	assert_that(_player.cell).is_equal(Vector2i(3, 2))
	assert_that(_player.facing).is_equal(Vector2i.UP)
	assert_array(_world.logged).is_equal(["ERROR the saved map 'town' no longer exists", "ERROR the saved map 'town' no longer exists"])


func test_a_game_saved_with_no_map_restores_none() -> void:
	_world.maps.traveller = null
	assert_that(_world.walkers.map_state()).is_equal({})
	_world.save.write(1)
	assert_bool(await _world.save.load_game(1)).is_true()
	assert_object(_world.maps.current).is_null()
	assert_that(_world.save.summary(1)).is_equal({"seconds": 0.0, "map": "", "zone": ""})
	_player.free()


func test_a_traveller_that_is_no_walker_lands_on_its_cell_facing_its_way() -> void:
	_player.free()
	var traveller := Node2D.new()
	_world.maps.traveller = traveller
	var arrived: Array[Vector2i] = []
	_world.maps.traveller_arrived.connect(func(direction: Vector2i, _point: Node2D) -> void: arrived.append(direction))
	await _world.walkers.restore_map({"map": "town", "cell": [3, 4], "facing": [-1, 0]})
	assert_that(traveller.global_position).is_equal(_world.tiles.center_of(Vector2i(3, 4)))
	assert_array(arrived).is_equal([Vector2i.LEFT])
	assert_that(_world.walkers.map_state()["cell"]).is_equal([3, 4])


func test_a_map_reached_by_its_scene_path_is_saved_and_loaded_by_it() -> void:
	var build := MapBuilder.new(_world.sandbox)
	var field := build.map(&"", Vector2i(8, 8))
	MapBuilder.spawn(field, "Spawn", Vector2(24, 24))
	build.save("hidden/field", field)
	var path := _world.sandbox.root + "maps/hidden/field.tscn"
	await _world.maps.go_to(StringName(path), &"Spawn")
	_player.place_at(Vector2i(4, 5))
	_world.save.write(1)
	await _world.maps.go_to(&"cave", &"Entrance")
	assert_bool(await _world.save.load_game(1)).is_true()
	assert_str(_world.maps.current_id).is_equal(path)
	assert_that(_player.cell).is_equal(Vector2i(4, 5))


func test_the_player_s_looks_are_kept_and_a_new_game_shows_it_as_it_stands() -> void:
	await _world.maps.go_to(&"town", &"Spawn")
	_player.look_offset = Vector2(0, -64)
	_player.shadow_offset = Vector2(2, -32)
	_player.shadow_shown = false
	_world.save.write(1)
	_player.look_offset = Vector2.ZERO
	_player.shadow_offset = Vector2.ZERO
	_player.shadow_shown = true
	assert_bool(await _world.save.load_game(1)).is_true()
	assert_array([_player.look_offset, _player.shadow_offset, _player.shadow_shown]).is_equal([Vector2(0, -64), Vector2(2, -32), false])
	_world.walkers.reset_map()
	assert_array([_player.look_offset, _player.shadow_offset, _player.shadow_shown]).is_equal([Vector2.ZERO, Vector2.ZERO, true])
