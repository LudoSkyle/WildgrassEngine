extends GdUnitTestSuite

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")
const ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")
const ScreenRegistry := preload("res://addons/wildgrass/core/screens/screen_registry.gd")
const Maps := preload("res://addons/wildgrass/maps/maps.gd")
const Sandbox := preload("res://tests/support/sandbox.gd")
const MapBuilder := preload("res://tests/support/map_builder.gd")
const RecordingTransition := preload("res://tests/support/recording_transition.gd")

var _sandbox: Sandbox
var _build: MapBuilder
var _hooks: Hooks
var _screens: ScreenRegistry
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
	_screens = ScreenRegistry.new(logger, layer)
	_screens.register(&"transition_none", "res://addons/wildgrass/maps/transitions/none.tscn")
	_screens.register(&"transition_fade", "res://addons/wildgrass/maps/transitions/fade.tscn")
	_screens.register(&"transition_test", _sandbox.scene("test_transition.tscn", RecordingTransition))
	RecordingTransition.calls.clear()
	_host = auto_free(Node2D.new())
	add_child(_host)
	_maps = Maps.new(paths, logger, config, _hooks, _screens, _host)
	_traveller = auto_free(Node2D.new())
	_maps.traveller = _traveller
	_events = []
	_maps.traveller_arrived.connect(func(direction: Vector2i, point: Node2D) -> void:
		_events.append("arrived %s %s" % [direction, point.name if point else "-"]))
	_maps.zone_changed.connect(func(old_zone: StringName, new_zone: StringName) -> void:
		_events.append("zone %s>%s" % [old_zone, new_zone]))
	_maps.map_changed.connect(func(_map: WgMap) -> void: _events.append("changed"))


func after_test() -> void:
	_sandbox.cleanup()


## Two maps: town (zone town) and house (zone town), linked by a door each way.
func _town_and_house() -> void:
	var town := _build.map(&"town")
	MapBuilder.spawn(town, "Spawn", Vector2(32, 32), Vector2i.UP)
	MapBuilder.door(town, "HouseDoor", Vector2(64, 48), &"house", &"Mat", WgDoor.Kind.CONTACT, Vector2i.DOWN)
	_build.save("town", town)
	var house := _build.map(&"town")
	MapBuilder.door(house, "Mat", Vector2(16, 80), &"town", &"HouseDoor", WgDoor.Kind.EXIT, Vector2i.DOWN)
	_build.save("house", house)


func test_go_to_shows_the_map_and_puts_the_traveller_at_the_spawn_point() -> void:
	_town_and_house()
	assert_bool(await _maps.go_to(&"town", &"Spawn")).is_true()
	assert_object(_maps.current.get_parent()).is_same(_host)
	assert_that(_maps.current_id).is_equal(&"town")
	assert_object(_traveller.get_parent()).is_same(_maps.current.entities_node())
	assert_that(_traveller.global_position).is_equal(Vector2(32, 32))
	assert_array(_events).is_equal(["arrived (0, -1) Spawn", "zone >town", "changed"])


func test_arriving_at_a_contact_door_puts_you_one_tile_away_facing_its_direction() -> void:
	_town_and_house()
	await _maps.go_to(&"house", &"Mat")
	await _maps.use(_maps.current.find_point(&"Mat") as WgDoor)
	assert_that(_traveller.global_position).is_equal(Vector2(64, 64))
	assert_array(_events.slice(-2)).is_equal(["arrived (0, 1) HouseDoor", "changed"])


func test_arriving_at_an_exit_puts_you_on_it_facing_back() -> void:
	_town_and_house()
	await _maps.go_to(&"town", &"Spawn")
	await _maps.use(_maps.current.find_point(&"HouseDoor") as WgDoor)
	assert_that(_maps.current_id).is_equal(&"house")
	assert_that(_traveller.global_position).is_equal(Vector2(16, 80))
	assert_str(_events[-2]).is_equal("arrived (0, -1) Mat")


func test_the_tile_size_comes_from_map_config() -> void:
	_sandbox.write_json("config/map.json", {"tile_size": 32})
	_town_and_house()
	await _maps.go_to(&"town", &"HouseDoor")
	assert_that(_traveller.global_position).is_equal(Vector2(64, 80))


func test_a_contact_door_without_direction_sends_you_down_and_is_logged() -> void:
	var town := _build.map()
	MapBuilder.door(town, "Broken", Vector2(0, 0), &"x", &"y", WgDoor.Kind.CONTACT, Vector2i.ZERO)
	_build.save("town", town)
	await _maps.go_to(&"town", &"Broken")
	assert_that(_traveller.global_position).is_equal(Vector2(0, 16))
	assert_array(_logged).is_equal(["WARN town: contact door 'Broken' has no direction; using down"])


func test_warp_adds_its_offset_in_tiles_and_may_force_the_direction() -> void:
	_town_and_house()
	await _maps.warp(&"town", &"Spawn", &"none", Vector2i(2, -1), Vector2i.LEFT)
	assert_that(_traveller.global_position).is_equal(Vector2(64, 16))
	assert_str(_events[0]).is_equal("arrived (-1, 0) Spawn")


func test_an_unknown_point_falls_back_to_the_first_spawn_point_then_the_origin() -> void:
	_town_and_house()
	await _maps.go_to(&"town", &"Nope")
	assert_that(_traveller.global_position).is_equal(Vector2(32, 32))
	assert_array(_logged).is_equal(["WARN town: no door or spawn point 'Nope'"])
	await _maps.go_to(&"house", &"Nope")
	assert_that(_traveller.global_position).is_equal(Vector2.ZERO)


func test_an_unknown_map_or_a_scene_that_is_not_a_map_changes_nothing() -> void:
	_town_and_house()
	_sandbox.scene("maps/plain.tscn")
	await _maps.go_to(&"town", &"Spawn")
	var town := _maps.current
	assert_bool(await _maps.go_to(&"nowhere", &"Spawn")).is_false()
	assert_bool(await _maps.go_to(&"plain", &"Spawn")).is_false()
	assert_object(_maps.current).is_same(town)
	assert_bool(_maps.is_changing).is_false()
	assert_array(_logged).has_size(2)


func test_a_warp_within_the_map_only_moves_the_traveller() -> void:
	var town := _build.map(&"town")
	MapBuilder.spawn(town, "A", Vector2(0, 0))
	MapBuilder.spawn(town, "B", Vector2(48, 0))
	MapBuilder.door(town, "ToB", Vector2(16, 0), &"", &"B")
	_build.save("town", town)
	await _maps.go_to(&"town", &"A")
	var map := _maps.current
	var loaded: Array[WgMap] = []
	_hooks.add(&"map_loaded", &"test", func(loaded_map: WgMap) -> void: loaded.append(loaded_map))
	_events.clear()
	await _maps.use(map.find_point(&"ToB") as WgDoor)
	assert_object(_maps.current).is_same(map)
	assert_that(_traveller.global_position).is_equal(Vector2(48, 0))
	assert_array(loaded).is_empty()
	assert_array(_events).is_equal(["arrived (0, 1) B", "changed"])


func test_hooks_and_signals_run_in_order_and_the_old_map_is_freed() -> void:
	_town_and_house()
	await _maps.go_to(&"town", &"Spawn")
	var town := _maps.current
	_hooks.add(&"map_leaving", &"test", func(map: WgMap) -> void: _events.append("leaving %s inside=%s" % [map.zone, map.is_inside_tree()]))
	_hooks.add(&"map_loaded", &"test", func(map: WgMap) -> void: _events.append("loaded inside=%s" % map.is_inside_tree()))
	_events.clear()
	await _maps.go_to(&"house", &"Mat")
	assert_array(_events).is_equal(["leaving town inside=true", "loaded inside=true", "arrived (0, -1) Mat", "changed"])
	assert_bool(is_instance_valid(town)).is_false()


func test_the_zone_is_announced_only_when_it_changes() -> void:
	_town_and_house()
	var cave := _build.map(&"cave")
	MapBuilder.spawn(cave, "Spawn", Vector2.ZERO)
	_build.save("cave", cave)
	await _maps.go_to(&"town", &"Spawn")
	await _maps.go_to(&"house", &"Mat")
	await _maps.go_to(&"cave", &"Spawn")
	assert_array(_events.filter(func(event: String) -> bool: return event.begins_with("zone"))).is_equal(["zone >town", "zone town>cave"])


func test_a_warp_during_a_warp_is_ignored() -> void:
	_town_and_house()
	_maps.warp(&"town", &"Spawn", &"fade")
	assert_bool(_maps.is_changing).is_true()
	assert_bool(await _maps.go_to(&"house", &"Mat")).is_false()
	await _maps.map_changed
	assert_that(_maps.current_id).is_equal(&"town")


func test_reload_gives_a_fresh_map_and_keeps_the_traveller_in_place() -> void:
	_town_and_house()
	await _maps.go_to(&"town", &"Spawn")
	var old := _maps.current
	_traveller.global_position = Vector2(80, 80)
	var loaded: Array[WgMap] = []
	_hooks.add(&"map_loaded", &"test", func(map: WgMap) -> void: loaded.append(map))
	_events.clear()
	assert_bool(await _maps.reload(&"none")).is_true()
	assert_object(_maps.current).is_not_same(old)
	assert_array(loaded).is_equal([_maps.current])
	assert_object(_traveller.get_parent()).is_same(_maps.current.entities_node())
	assert_that(_traveller.global_position).is_equal(Vector2(80, 80))
	assert_array(_events).is_equal(["changed"])


func test_reload_without_a_map_is_refused() -> void:
	assert_bool(await _maps.reload()).is_false()


func test_the_named_transition_covers_then_uncovers_with_the_configured_length() -> void:
	_sandbox.write_json("config/map.json", {"fade_seconds": 0.5})
	_town_and_house()
	await _maps.warp(&"town", &"Spawn", &"test")
	assert_array(RecordingTransition.calls).is_equal(["cover 0.5", "uncover"])
	assert_array(_screens.stack()).is_empty()


func test_an_unknown_transition_is_logged_and_the_warp_still_happens() -> void:
	_town_and_house()
	assert_bool(await _maps.warp(&"town", &"Spawn", &"spiral")).is_true()
	assert_that(_maps.current_id).is_equal(&"town")
	assert_array(_logged).is_equal(["ERROR unknown screen 'transition_spiral'"])


func test_without_a_traveller_maps_still_load() -> void:
	_maps.traveller = null
	_town_and_house()
	assert_bool(await _maps.go_to(&"town", &"Spawn")).is_true()
	assert_str(_events[0]).is_equal("arrived (0, -1) Spawn")
