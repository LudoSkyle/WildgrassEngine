extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const MapBuilder := preload("res://tests/support/map_builder.gd")
const EnteringNode := preload("res://tests/support/entering_node.gd")

var _world: World
var _build: MapBuilder


func before_test() -> void:
	_world = World.new(self)
	_build = MapBuilder.new(_world.sandbox)
	_world.maps.traveller = Node2D.new()
	EnteringNode.entered.clear()


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


## A node named `node_name` in `map`'s Entities, kept by `condition`.
static func _gated(map: WgMap, node_name: String, condition: String) -> Node:
	var node := EnteringNode.new()
	node.name = node_name
	map.entities_node().add_child(node)
	var gate := WgShowIf.new()
	gate.name = "ShowIf"
	gate.condition = condition
	node.add_child(gate)
	return node


func _town() -> void:
	var town := _build.map(&"town")
	MapBuilder.spawn(town, "Spawn", Vector2(8, 8))
	_gated(town, "Odile", "bell_told")
	_gated(town, "Worker", "!bell_hung")
	var crate := _gated(town, "Crate", "!bell_told")
	var inner := WgShowIf.new()
	inner.condition = "!bell_told"
	crate.get_node("ShowIf").add_child(inner)
	_build.save("town", town)


func test_what_does_not_show_is_freed_before_it_enters_the_tree() -> void:
	_town()
	_world.story.set_flag(&"bell_hung")
	_world.story.set_flag(&"bell_told")
	await _world.maps.go_to(&"town", &"Spawn")
	var entities := _world.maps.current.entities_node()
	assert_bool(entities.has_node("Odile")).is_true()
	assert_bool(entities.has_node("Worker")).is_false()
	assert_bool(entities.has_node("Crate")).is_false()
	assert_array(EnteringNode.entered).is_equal(["Odile"])


func test_it_is_decided_when_the_map_loads_again() -> void:
	_town()
	await _world.maps.go_to(&"town", &"Spawn")
	assert_bool(_world.maps.current.entities_node().has_node("Odile")).is_false()
	_world.story.set_flag(&"bell_told")
	assert_bool(_world.maps.current.entities_node().has_node("Odile")).is_false()
	await _world.maps.reload(&"none")
	assert_bool(_world.maps.current.entities_node().has_node("Odile")).is_true()


func test_a_local_flag_of_the_node_kept_off_on_its_own_map() -> void:
	var town := _build.map(&"town")
	MapBuilder.spawn(town, "Spawn", Vector2(8, 8))
	_gated(town, "Ball", "!local:taken")
	_build.save("town", town)
	await _world.maps.go_to(&"town", &"Spawn")
	var ball := _world.maps.current.get_node("Entities/Ball")
	_world.story.set_flag(_world.story.local(ball, &"taken"))
	assert_str(_world.story.local(ball, &"taken")).is_equal("town/Entities/Ball:taken")
	await _world.maps.reload(&"none")
	assert_bool(_world.maps.current.entities_node().has_node("Ball")).is_false()


func test_a_neighbour_loaded_in_the_background_shows_only_what_holds() -> void:
	var route := _build.map(&"route")
	route.size = Vector2i(10, 8)
	MapBuilder.spawn(route, "Spawn", Vector2(32, 120))
	MapBuilder.link(route, WgMapLink.Side.SOUTH, &"island", 0)
	_build.save("route", route)
	var island := _build.map(&"island")
	island.size = Vector2i(10, 6)
	MapBuilder.link(island, WgMapLink.Side.NORTH, &"route", 0)
	MapBuilder.link(island, WgMapLink.Side.SOUTH, &"beach", 0)
	_build.save("island", island)
	var beach := _build.map(&"beach")
	beach.size = Vector2i(10, 6)
	MapBuilder.link(beach, WgMapLink.Side.NORTH, &"island", 0)
	_gated(beach, "Swimmer", "summer")
	_gated(beach, "Surfer", "!summer")
	_build.save("beach", beach)
	await _world.maps.go_to(&"route", &"Spawn")
	(_world.maps.traveller as Node2D).global_position = Vector2(32, 136)
	_world.maps.cross()
	if _world.maps.is_loading_neighbours:
		await _world.maps.neighbours_loaded
	var shown: WgMap = _world.maps.neighbours.filter(func(map: WgMap) -> bool: return _world.maps.id_of(map) == &"beach")[0]
	assert_bool(shown.entities_node().has_node("Surfer")).is_true()
	assert_bool(shown.entities_node().has_node("Swimmer")).is_false()
	assert_bool(EnteringNode.entered.has("Swimmer")).is_false()
