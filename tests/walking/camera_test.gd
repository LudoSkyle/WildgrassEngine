extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const MapBuilder := preload("res://tests/support/map_builder.gd")

var _world: World
var _build: MapBuilder


func before_test() -> void:
	_world = World.new(self)
	_build = MapBuilder.new(_world.sandbox)


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _camera_on(map: WgMap, map_id: String) -> WgCamera:
	MapBuilder.spawn(map, "Spawn", Vector2.ZERO)
	_build.save(map_id, map)
	var walker := WgWalker.new()
	walker.walkers = _world.walkers
	var camera := WgCamera.new()
	camera.zoom = Vector2(0.25, 0.25)
	walker.add_child(camera)
	_world.maps.traveller = walker
	_world.maps.go_to(StringName(map_id), &"Spawn")
	return camera


func test_the_camera_stays_in_a_room_and_centres_it_where_it_is_narrow() -> void:
	# A room half as wide as the view and twice as tall.
	var view := get_viewport().get_visible_rect().size * 4.0
	var room := _build.map()
	room.size = Vector2i(floori(view.x / 32.0), ceili(view.y / 8.0))
	var pixels := Vector2(room.size * 16)
	var camera := _camera_on(room, "room")
	assert_int(camera.limit_top).is_equal(0)
	assert_int(camera.limit_bottom).is_equal(int(pixels.y))
	assert_int(camera.limit_left).is_equal(floori(pixels.x / 2.0 - view.x / 2.0))
	assert_int(camera.limit_right).is_equal(ceili(pixels.x / 2.0 + view.x / 2.0))


func test_the_camera_is_free_on_linked_maps_and_maps_without_a_size() -> void:
	var linked := _build.map()
	linked.size = Vector2i(5, 5)
	MapBuilder.link(linked, WgMapLink.Side.NORTH, &"nowhere")
	var camera := _camera_on(linked, "linked")
	assert_int(camera.limit_left).is_equal(-WgCamera.FAR)
	assert_int(camera.limit_bottom).is_equal(WgCamera.FAR)
	_camera_on(_build.map(), "open")
	assert_int((_world.maps.traveller.get_child(0) as WgCamera).limit_right).is_equal(WgCamera.FAR)


func test_the_limits_change_on_arrival_under_the_transition() -> void:
	const Held := preload("res://tests/support/held_transition.gd")
	_world.screens.register(&"transition_held", _world.sandbox.scene("held.tscn", Held))
	var view := get_viewport().get_visible_rect().size * 4.0
	var hall := _build.map()
	var hall_size := Vector2i(ceili(view.x / 8.0), ceili(view.y / 8.0))
	hall.size = hall_size
	var camera := _camera_on(hall, "hall")
	var room := _build.map()
	var room_size := hall_size * 2
	room.size = room_size
	MapBuilder.spawn(room, "Spawn", Vector2.ZERO)
	_build.save("room", room)
	_world.maps.warp(&"room", &"Spawn", &"held")
	await get_tree().process_frame
	assert_bool(_world.maps.is_changing).is_true()
	assert_int(camera.limit_right).is_equal(room_size.x * 16)
	(_world.screens.top() as Held).release.emit()
	await get_tree().process_frame
	assert_bool(_world.maps.is_changing).is_false()
