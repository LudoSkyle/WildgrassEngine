extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const MapBuilder := preload("res://tests/support/map_builder.gd")
const RecordingBanner := preload("res://tests/support/recording_banner.gd")

var _world: World


func before_test() -> void:
	_world = World.new(self)
	for spec: Array in [[&"town", "Town", &"wood"], [&"upstairs", "Town", &"wood"], [&"cave", "", &""], [&"wood", "Wood", &"forest"], [&"twin", "Wood", &"forest"]]:
		var zone := WgZone.new()
		zone.id = spec[0]
		zone.name = spec[1]
		zone.banner = spec[2]
		_world.zones.register(zone)
	var build := MapBuilder.new(_world.sandbox)
	for spec: Array in [["town", &"town"], ["home", &"town"], ["home_up", &"upstairs"], ["cave", &"cave"], ["wood", &"wood"], ["twin_wood", &"twin"], ["nowhere", &""], ["bare", &"bare"]]:
		var map := build.map(spec[1], Vector2i(4, 4))
		MapBuilder.spawn(map, "Spawn", Vector2(8, 8))
		build.save(spec[0], map)
	var west := build.map(&"town", Vector2i(4, 4))
	MapBuilder.spawn(west, "Spawn", Vector2(8, 8))
	MapBuilder.link(west, WgMapLink.Side.EAST, &"east")
	build.save("west", west)
	var east := build.map(&"wood", Vector2i(4, 4))
	MapBuilder.link(east, WgMapLink.Side.WEST, &"west")
	build.save("east", east)
	_world.maps.traveller = Node2D.new()


func after_test() -> void:
	if _world.maps.traveller.get_parent() == null:
		_world.maps.traveller.free()
	_world.root.free()
	_world.cleanup()


func _shown() -> Array[String]:
	var names: Array[String] = []
	_world.zones.banner_shown.connect(func(zone_name: String, _style: StringName) -> void: names.append(zone_name))
	return names


func test_zones_registered_then_the_folder_s_then_a_source_s() -> void:
	DirAccess.make_dir_recursive_absolute(_world.sandbox.root + "zones")
	var lake := WgZone.new()
	lake.id = &"lake"
	lake.name = "Lake"
	ResourceSaver.save(lake, _world.sandbox.root + "zones/lake.tres")
	_world.zones.add_source(func(id: StringName) -> WgZone: return WgZone.new() if id == &"sea" else null, func() -> Array: return [&"sea"])
	assert_str(_world.zones.find(&"town").name).is_equal("Town")
	assert_str(_world.zones.find(&"lake").name).is_equal("Lake")
	assert_object(_world.zones.find(&"sea")).is_not_null()
	assert_bool(_world.zones.has(&"moon")).is_false()
	assert_array(_world.zones.ids()).contains([&"town", &"lake", &"sea"])
	assert_object(_world.zones.find(&"moon")).is_null()
	assert_object(_world.zones.find(&"moon")).is_null()
	assert_array(_world.logged).is_equal(["ERROR unknown zone 'moon'"])


func test_arriving_in_a_zone_shows_its_banner_once_the_map_is_uncovered() -> void:
	var at_change: Array[bool] = []
	_world.maps.zone_changed.connect(func(_old: StringName, _new: StringName) -> void: at_change.append(_world.zones.banner != null and _world.zones.banner.is_showing()))
	await _world.maps.go_to(&"town", &"Spawn")
	assert_array(at_change).is_equal([false])
	var banner := _world.zones.banner
	assert_bool(banner.is_showing()).is_true()
	assert_str((banner.get_node("Panel/Name") as Label).text).is_equal("Town")
	assert_object(_world.zones.current()).is_same(_world.zones.find(&"town"))
	assert_array(_world.screens.stack()).is_empty()
	assert_int(banner.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_object(banner.get_parent()).is_same(_world.screen_layer)
	assert_int(banner.get_index()).is_equal(0)


func test_under_the_titles_fade_it_waits_for_the_fade_to_close() -> void:
	var names := _shown()
	var veil := _world.screens.open(&"transition_none")
	await _world.maps.go_to(&"town", &"Spawn")
	assert_array(names).is_empty()
	veil.close()
	assert_array(names).is_equal(["Town"])


func test_the_banner_slides_down_stays_and_slides_up() -> void:
	await _world.maps.go_to(&"town", &"Spawn")
	var banner := _world.zones.banner
	var panel := banner.get_node("Panel") as Control
	var height := panel.size.y
	assert_float(height).is_greater(0.0)
	assert_that(panel.position).is_equal(Vector2(8, -height - 8))
	banner.advance(0.15)
	assert_float(panel.position.y).is_equal_approx((-height - 8 + 8) / 2.0, 0.01)
	banner.advance(0.15)
	assert_that(panel.position).is_equal(Vector2(8, 8))
	banner.advance(2.1)
	assert_int(banner.phase).is_equal(WgLocationBanner.Phase.STAYING)
	banner.advance(0.1)
	assert_int(banner.phase).is_equal(WgLocationBanner.Phase.SLIDING_OUT)
	banner.advance(0.3)
	assert_bool(banner.is_showing()).is_false()
	assert_bool(panel.visible).is_false()


func test_only_a_new_name_shows_and_a_zone_without_one_shows_nothing() -> void:
	var names := _shown()
	await _world.maps.go_to(&"town", &"Spawn")
	await _world.maps.go_to(&"home", &"Spawn")
	await _world.maps.go_to(&"home_up", &"Spawn")
	await _world.maps.go_to(&"cave", &"Spawn")
	await _world.maps.go_to(&"nowhere", &"Spawn")
	# A zone with no data shows nothing, and is no error.
	await _world.maps.go_to(&"bare", &"Spawn")
	assert_object(_world.zones.current()).is_null()
	await _world.maps.go_to(&"town", &"Spawn")
	assert_array(names).is_equal(["Town"])
	assert_array(_world.logged).is_empty()
	await _world.maps.go_to(&"wood", &"Spawn")
	_world.zones.banner.advance(1.0)
	await _world.maps.go_to(&"twin_wood", &"Spawn")
	await _world.maps.go_to(&"town", &"Spawn")
	assert_array(names).is_equal(["Town", "Wood", "Town"])
	# A new name while one shows: it slides in again.
	assert_int(_world.zones.banner.phase).is_equal(WgLocationBanner.Phase.SLIDING_IN)


func test_crossing_into_a_linked_map_of_another_zone_shows_it_at_once() -> void:
	var names := _shown()
	await _world.maps.go_to(&"west", &"Spawn")
	_world.maps.traveller.global_position = Vector2(72, 8)
	assert_bool(_world.maps.cross()).is_true()
	assert_array(names).is_equal(["Town", "Wood"])
	while _world.maps.is_loading_neighbours:
		await _world.maps.neighbours_loaded


func test_back_at_the_title_the_first_map_shows_it_again() -> void:
	var names := _shown()
	await _world.maps.go_to(&"town", &"Spawn")
	_world.maps.clear()
	await _world.maps.go_to(&"town", &"Spawn")
	assert_array(names).is_equal(["Town", "Town"])


func test_a_games_banner_draws_its_styles_and_a_wrong_scene_is_logged() -> void:
	_world.screens.set_scene(&"location_banner", _world.sandbox.scene("banner.tscn", RecordingBanner))
	await _world.maps.go_to(&"wood", &"Spawn")
	var banner := _world.zones.banner as RecordingBanner
	assert_array(banner.styles).is_equal([&"forest"])
	assert_str(banner.zone_name).is_equal("Wood")
	assert_int(banner.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	_world.zones.banner = null
	banner.free()
	_world.screens.set_scene(&"location_banner", _world.sandbox.scene("plain.tscn"))
	await _world.maps.go_to(&"town", &"Spawn")
	assert_object(_world.zones.banner).is_null()
	assert_array(_world.logged.filter(func(line: String) -> bool: return line.contains("location_banner"))).has_size(1)
