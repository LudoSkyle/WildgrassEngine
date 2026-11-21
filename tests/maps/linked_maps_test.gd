extends GdUnitTestSuite

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")
const ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")
const ScreenRegistry := preload("res://addons/wildgrass/core/screens/screen_registry.gd")
const Maps := preload("res://addons/wildgrass/maps/maps.gd")
const Sandbox := preload("res://tests/support/sandbox.gd")
const MapBuilder := preload("res://tests/support/map_builder.gd")

const NORTH := WgMapLink.Side.NORTH
const EAST := WgMapLink.Side.EAST
const SOUTH := WgMapLink.Side.SOUTH
const WEST := WgMapLink.Side.WEST

var _sandbox: Sandbox
var _build: MapBuilder
var _hooks: Hooks
var _maps: Maps
var _host: Node2D
var _traveller: Node2D
var _logged: Array[String]
var _events: Array[String]


func before_test() -> void:
	_sandbox = Sandbox.new()
	_sandbox.use_data_folder()
	_build = MapBuilder.new(_sandbox)
	var logger := Log.new()
	logger.echo = false
	_logged = []
	logger.logged.connect(func(level: Log.Level, _channel: StringName, message: String) -> void:
		_logged.append("%s %s" % [Log.Level.keys()[level], message]))
	var paths := Paths.new(false)
	var config := ConfigRegistry.new(paths, logger)
	config.register(&"map", WgMapConfig, "map")
	_hooks = Hooks.new()
	var layer: Node = auto_free(Node.new())
	add_child(layer)
	var screens := ScreenRegistry.new(logger, layer)
	screens.register(&"transition_none", "res://addons/wildgrass/maps/transitions/none.tscn")
	screens.register(&"transition_fade", "res://addons/wildgrass/maps/transitions/fade.tscn")
	_host = auto_free(Node2D.new())
	add_child(_host)
	_maps = Maps.new(paths, logger, config, _hooks, screens, _host)
	_traveller = auto_free(Node2D.new())
	_maps.traveller = _traveller
	_events = []
	_maps.traveller_arrived.connect(func(_direction: Vector2i, _point: Node2D) -> void: _events.append("arrived"))
	_maps.zone_changed.connect(func(old_zone: StringName, new_zone: StringName) -> void:
		_events.append("zone %s>%s" % [old_zone, new_zone]))
	_maps.map_changed.connect(func(map: WgMap) -> void: _events.append("changed %s" % map.zone))


func after_test() -> void:
	await _wait_for_neighbours()
	_sandbox.cleanup()


## hub (4×4) with a neighbour of another size on each side, each linking back.
func _hub() -> void:
	var hub := _build.map(&"hub", Vector2i(4, 4))
	MapBuilder.spawn(hub, "Spawn", Vector2.ZERO)
	MapBuilder.link(hub, NORTH, &"north", 1)
	MapBuilder.link(hub, SOUTH, &"south", -1)
	MapBuilder.link(hub, EAST, &"east", -2)
	MapBuilder.link(hub, WEST, &"west", 2)
	_build.save("hub", hub)
	for spec: Array in [["north", Vector2i(3, 2), SOUTH, -1], ["south", Vector2i(5, 3), NORTH, 1], ["east", Vector2i(2, 6), WEST, 2], ["west", Vector2i(3, 1), EAST, -2]]:
		var map := _build.map(StringName(spec[0]), spec[1])
		MapBuilder.link(map, spec[2], &"hub", spec[3])
		_build.save(spec[0], map)


## route (10×8): island south, field east. island (14×6): route north, beach
## south. field (5×5): route west. beach (14×4): island north.
func _route() -> void:
	var route := _build.map(&"route", Vector2i(10, 8))
	MapBuilder.spawn(route, "Spawn", Vector2(16, 16))
	MapBuilder.link(route, SOUTH, &"island", -2)
	MapBuilder.link(route, EAST, &"field", 3)
	_build.save("route", route)
	var island := _build.map(&"island", Vector2i(14, 6))
	MapBuilder.spawn(island, "Spawn", Vector2(32, 32))
	MapBuilder.link(island, NORTH, &"route", 2)
	MapBuilder.link(island, SOUTH, &"beach", 0)
	_build.save("island", island)
	var field := _build.map(&"route", Vector2i(5, 5))
	MapBuilder.link(field, WEST, &"route", -3)
	_build.save("field", field)
	var beach := _build.map(&"island", Vector2i(14, 4))
	MapBuilder.link(beach, NORTH, &"island", 0)
	_build.save("beach", beach)


func _neighbour(map_id: StringName) -> WgMap:
	for map: WgMap in _maps.neighbours:
		if map.scene_file_path.get_file() == "%s.tscn" % map_id:
			return map
	return null


func _cross_to(global_position: Vector2) -> bool:
	_traveller.global_position = global_position
	return _maps.cross()


## What was logged, minus the missing spawn points of maps that need none.
func _problems() -> Array[String]:
	var result: Array[String] = []
	for line: String in _logged:
		if not line.contains("no door or spawn point"):
			result.append(line)
	return result


func _wait_for_neighbours() -> void:
	if _maps != null and _maps.is_loading_neighbours:
		await _maps.neighbours_loaded


func test_neighbours_are_placed_against_each_side_with_their_offset() -> void:
	_hub()
	await _maps.go_to(&"hub", &"Spawn")
	assert_that(_maps.current.position).is_equal(Vector2.ZERO)
	assert_that(_neighbour(&"north").position).is_equal(Vector2(16, -32))
	assert_that(_neighbour(&"south").position).is_equal(Vector2(-16, 64))
	assert_that(_neighbour(&"east").position).is_equal(Vector2(64, -32))
	assert_that(_neighbour(&"west").position).is_equal(Vector2(-48, 32))
	assert_array(_maps.neighbours).has_size(4)
	for map: WgMap in _maps.neighbours:
		assert_object(map.get_parent()).is_same(_host)
	assert_array(_logged).is_empty()


func test_neighbours_run_like_the_current_map() -> void:
	_hub()
	await _maps.go_to(&"hub", &"Spawn")
	for map: WgMap in _maps.neighbours:
		assert_bool(map.can_process()).is_true()


func test_map_at_finds_the_map_under_a_position_edges_included() -> void:
	_hub()
	await _maps.go_to(&"hub", &"Spawn")
	assert_object(_maps.map_at(Vector2(0, 0))).is_same(_maps.current)
	assert_object(_maps.map_at(Vector2(63.9, 63.9))).is_same(_maps.current)
	assert_object(_maps.map_at(Vector2(64, 0))).is_same(_neighbour(&"east"))
	assert_object(_maps.map_at(Vector2(16, -0.1))).is_same(_neighbour(&"north"))
	assert_object(_maps.map_at(Vector2(15.9, -0.1))).is_null()
	assert_object(_maps.map_at(Vector2(-100, -100))).is_null()
	assert_that(_maps.rect(_neighbour(&"south"))).is_equal(Rect2(-16, 64, 80, 48))


func test_a_map_without_size_covers_everything_and_nothing_without_a_map() -> void:
	assert_object(_maps.map_at(Vector2.ZERO)).is_null()
	var room := _build.map()
	_build.save("room", room)
	await _maps.go_to(&"room", &"")
	assert_object(_maps.map_at(Vector2(-5000, 9000))).is_same(_maps.current)


func test_crossing_makes_the_neighbour_current_with_no_warp() -> void:
	_route()
	await _maps.go_to(&"route", &"Spawn")
	var route := _maps.current
	var island := _neighbour(&"island")
	_events.clear()
	assert_bool(_cross_to(Vector2(16, 128))).is_true()
	assert_object(_maps.current).is_same(island)
	assert_that(_maps.current_id).is_equal(&"island")
	assert_object(_traveller.get_parent()).is_same(island.entities_node())
	assert_that(_traveller.global_position).is_equal(Vector2(16, 128))
	assert_that(route.position).is_equal(Vector2.ZERO)
	assert_that(island.position).is_equal(Vector2(-32, 128))
	assert_array(_events).is_equal(["zone route>island", "changed island"])


func test_is_crossing_tells_a_crossing_from_a_warp() -> void:
	_route()
	var seen: Array[bool] = []
	_maps.map_changed.connect(func(_map: WgMap) -> void: seen.append(_maps.is_crossing))
	await _maps.go_to(&"route", &"Spawn")
	_cross_to(Vector2(16, 128))
	await _maps.reload(&"none")
	assert_array(seen).is_equal([false, true, false])
	assert_bool(_maps.is_crossing).is_false()


func test_the_traveller_leaves_and_reenters_the_tree_when_crossing() -> void:
	_route()
	await _maps.go_to(&"route", &"Spawn")
	var entered: Array[bool] = []
	_traveller.tree_entered.connect(func() -> void: entered.append(true))
	_cross_to(Vector2(16, 128))
	assert_array(entered).has_size(1)


func test_a_camera_on_the_traveller_shows_the_right_view_right_after_crossing() -> void:
	_route()
	var camera := Camera2D.new()
	_traveller.add_child(camera)
	await _maps.go_to(&"route", &"Spawn")
	await get_tree().process_frame
	_cross_to(Vector2(16, 128))
	assert_that(camera.get_screen_center_position()).is_equal(Vector2(16, 128))


func test_crossing_keeps_shared_neighbours_frees_the_others_and_loads_the_missing_in_the_background() -> void:
	_route()
	await _maps.go_to(&"route", &"Spawn")
	var route := _maps.current
	var field := _neighbour(&"field")
	var loaded: Array[String] = []
	var left: Array[String] = []
	_hooks.add(&"map_loaded", &"test", func(map: WgMap) -> void: loaded.append(map.scene_file_path.get_file()))
	_hooks.add(&"map_leaving", &"test", func(map: WgMap) -> void: left.append(map.scene_file_path.get_file()))
	_cross_to(Vector2(16, 128))
	assert_bool(_maps.is_loading_neighbours).is_true()
	assert_array(_maps.neighbours).contains_exactly([route])
	assert_bool(is_instance_valid(field)).is_false()
	assert_array(left).is_equal(["field.tscn"])
	await _maps.neighbours_loaded
	assert_bool(_maps.is_loading_neighbours).is_false()
	assert_array(loaded).is_equal(["beach.tscn"])
	assert_that(_neighbour(&"beach").position).is_equal(Vector2(-32, 224))


func test_crossing_back_and_forth_reuses_the_maps_on_screen() -> void:
	_route()
	await _maps.go_to(&"route", &"Spawn")
	var route := _maps.current
	_cross_to(Vector2(16, 128))
	await _wait_for_neighbours()
	assert_bool(_cross_to(Vector2(16, 112))).is_true()
	assert_object(_maps.current).is_same(route)
	assert_that(_maps.current_id).is_equal(&"route")
	assert_array(_events.slice(-2)).is_equal(["zone island>route", "changed route"])


func test_cross_does_nothing_inside_the_map_off_every_map_without_traveller_or_during_a_warp() -> void:
	_route()
	await _maps.go_to(&"route", &"Spawn")
	var route := _maps.current
	assert_bool(_cross_to(Vector2(144, 112))).is_false()
	assert_bool(_cross_to(Vector2(-100, -100))).is_false()
	_traveller.global_position = Vector2(16, 128)
	_maps.warp(&"route", &"Spawn", &"fade")
	assert_bool(_maps.cross()).is_false()
	await _maps.map_changed
	_maps.traveller = null
	assert_bool(_maps.cross()).is_false()
	assert_object(_maps.current).is_same(route)


func test_a_warp_shows_the_target_at_the_origin_with_fresh_neighbours_and_runs_their_hooks() -> void:
	_route()
	await _maps.go_to(&"route", &"Spawn")
	var island := _neighbour(&"island")
	var events: Array[String] = []
	_hooks.add(&"map_loaded", &"test", func(map: WgMap) -> void: events.append("loaded " + map.scene_file_path.get_file()))
	_hooks.add(&"map_leaving", &"test", func(map: WgMap) -> void: events.append("leaving " + map.scene_file_path.get_file()))
	await _maps.go_to(&"island", &"Spawn")
	assert_object(_maps.current).is_not_same(island)
	assert_that(_maps.current.position).is_equal(Vector2.ZERO)
	assert_that(_traveller.global_position).is_equal(Vector2(32, 32))
	assert_array(events).is_equal(["leaving route.tscn", "leaving island.tscn", "leaving field.tscn", "loaded island.tscn", "loaded route.tscn", "loaded beach.tscn"])
	assert_that(_neighbour(&"route").position).is_equal(Vector2(32, -128))


func test_clear_drops_every_map_and_their_loading_and_the_next_warp_starts_afresh() -> void:
	_route()
	await _maps.go_to(&"route", &"Spawn")
	_cross_to(Vector2(16, 128))
	var left: Array[String] = []
	_hooks.add(&"map_leaving", &"test", func(map: WgMap) -> void: left.append(map.scene_file_path.get_file()))
	_maps.cleared.connect(func() -> void: left.append("cleared"))
	_maps.clear()
	assert_array(left).is_equal(["island.tscn", "route.tscn", "cleared"])
	assert_object(_maps.current).is_null()
	assert_str(_maps.current_id).is_empty()
	assert_array(_maps.neighbours).is_empty()
	assert_bool(_maps.is_loading_neighbours).is_false()
	assert_object(_traveller.get_parent()).is_null()
	assert_int(_host.get_child_count()).is_equal(0)
	_events.clear()
	await _maps.go_to(&"island", &"Spawn")
	assert_array(_events).is_equal(["arrived", "zone >island", "changed island"])


func test_reload_away_from_the_origin_keeps_every_map_in_place() -> void:
	_route()
	await _maps.go_to(&"route", &"Spawn")
	_cross_to(Vector2(16, 130))
	await _wait_for_neighbours()
	var old := _maps.current
	await _maps.reload(&"none")
	assert_object(_maps.current).is_not_same(old)
	assert_that(_maps.current.position).is_equal(Vector2(-32, 128))
	assert_that(_traveller.global_position).is_equal(Vector2(16, 130))
	assert_that(_neighbour(&"route").position).is_equal(Vector2.ZERO)
	assert_that(_neighbour(&"beach").position).is_equal(Vector2(-32, 224))


func test_a_warp_during_background_loading_drops_it() -> void:
	_route()
	await _maps.go_to(&"route", &"Spawn")
	var announced: Array[bool] = []
	_maps.neighbours_loaded.connect(func() -> void: announced.append(true))
	_cross_to(Vector2(16, 128))
	await _maps.go_to(&"field", &"")
	var beach := _sandbox.root + "maps/beach.tscn"
	while ResourceLoader.load_threaded_get_status(beach) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(_maps.is_loading_neighbours).is_false()
	assert_array(announced).is_empty()
	assert_object(_neighbour(&"beach")).is_null()
	assert_array(_maps.neighbours).has_size(1)


func test_a_host_freed_during_background_loading_ends_it_quietly() -> void:
	_route()
	await _maps.go_to(&"route", &"Spawn")
	var announced: Array[bool] = []
	_maps.neighbours_loaded.connect(func() -> void: announced.append(true))
	_cross_to(Vector2(16, 128))
	_host.free()
	while _maps.is_loading_neighbours:
		await get_tree().process_frame
	assert_array(announced).is_empty()


## A threaded load nobody collects leaks until the game quits.
func test_maps_dropped_during_background_loading_leave_no_load_behind() -> void:
	_route()
	await _maps.go_to(&"route", &"Spawn")
	_cross_to(Vector2(16, 128))
	var beach := _sandbox.root + "maps/beach.tscn"
	assert_int(ResourceLoader.load_threaded_get_status(beach)).is_not_equal(ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)
	_maps = null
	assert_int(ResourceLoader.load_threaded_get_status(beach)).is_equal(ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)


func test_links_without_a_size_show_the_map_alone() -> void:
	var town := _build.map(&"town")
	MapBuilder.link(town, NORTH, &"route")
	_build.save("town", town)
	_route()
	await _maps.go_to(&"town", &"")
	assert_array(_maps.neighbours).is_empty()
	assert_array(_problems()).is_equal(["ERROR town: links need a size; shown alone"])


func test_empty_self_and_repeated_links_are_ignored() -> void:
	var town := _build.map(&"town", Vector2i(4, 4))
	town.links.append(null)
	MapBuilder.link(town, NORTH, &"town")
	MapBuilder.link(town, EAST, &"north")
	MapBuilder.link(town, WEST, &"north")
	_build.save("town", town)
	var north := _build.map(&"town", Vector2i(2, 4))
	MapBuilder.link(north, WEST, &"town")
	_build.save("north", north)
	await _maps.go_to(&"town", &"")
	assert_array(_maps.neighbours).has_size(1)
	assert_that(_maps.neighbours[0].position).is_equal(Vector2(64, 0))
	assert_array(_problems()).is_equal([
		"ERROR town: empty link ignored",
		"ERROR town: linked to itself; link ignored",
		"ERROR town: 'north' linked twice; first link kept",
	])


func test_an_unknown_or_sizeless_neighbour_leaves_its_side_closed() -> void:
	var town := _build.map(&"town", Vector2i(4, 4))
	MapBuilder.link(town, NORTH, &"nowhere")
	MapBuilder.link(town, SOUTH, &"flat")
	_build.save("town", town)
	var flat := _build.map(&"town")
	MapBuilder.link(flat, NORTH, &"town")
	_build.save("flat", flat)
	await _maps.go_to(&"town", &"")
	assert_array(_maps.neighbours).is_empty()
	assert_int(_problems().size()).is_equal(2)
	assert_str(_problems()[0]).starts_with("ERROR unknown map 'nowhere'")
	assert_str(_problems()[1]).is_equal("ERROR flat: no size; not shown next to town")


func test_an_unknown_map_found_while_crossing_is_logged_and_loading_still_ends() -> void:
	_route()
	var island := _build.map(&"island", Vector2i(14, 6))
	MapBuilder.link(island, NORTH, &"route", 2)
	MapBuilder.link(island, SOUTH, &"nowhere")
	_build.save("island", island)
	await _maps.go_to(&"route", &"Spawn")
	_cross_to(Vector2(16, 128))
	await _wait_for_neighbours()
	assert_array(_maps.neighbours).has_size(1)
	assert_str(_logged[-1]).starts_with("ERROR unknown map 'nowhere'")


func test_a_link_that_does_not_come_back_or_disagrees_is_shown_with_a_warning() -> void:
	var town := _build.map(&"town", Vector2i(4, 4))
	MapBuilder.link(town, NORTH, &"lonely")
	MapBuilder.link(town, SOUTH, &"skewed", 1)
	_build.save("town", town)
	_build.save("lonely", _build.map(&"town", Vector2i(4, 4)))
	var skewed := _build.map(&"town", Vector2i(4, 4))
	MapBuilder.link(skewed, NORTH, &"town", 1)
	_build.save("skewed", skewed)
	await _maps.go_to(&"town", &"")
	assert_array(_maps.neighbours).has_size(2)
	assert_array(_problems()).is_equal([
		"WARN town links to lonely, which does not link back",
		"WARN town and skewed disagree on their offset",
	])


func test_overlapping_neighbours_are_shown_with_a_warning_and_the_first_wins() -> void:
	var town := _build.map(&"town", Vector2i(4, 4))
	MapBuilder.link(town, NORTH, &"wide", 0)
	MapBuilder.link(town, EAST, &"tall", -4)
	_build.save("town", town)
	var wide := _build.map(&"town", Vector2i(8, 2))
	MapBuilder.link(wide, SOUTH, &"town", 0)
	_build.save("wide", wide)
	var tall := _build.map(&"town", Vector2i(2, 8))
	MapBuilder.link(tall, WEST, &"town", 4)
	_build.save("tall", tall)
	await _maps.go_to(&"town", &"")
	assert_array(_problems()).is_equal(["WARN tall overlaps wide next to town"])
	assert_object(_maps.map_at(Vector2(70, -10))).is_same(_neighbour(&"wide"))
