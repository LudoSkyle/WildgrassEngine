extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const StudioProject := preload("res://tests/support/studio_project.gd")
const Studio := preload("res://addons/wildgrass/studio/studio.gd")

var _world: World
var _studio: Studio


func before_test() -> void:
	_world = World.new(self)
	_world.sandbox.write("Data/Text/Dialogs/100010.csv", "en,fr\n——,——\nExterior of The Tower,Extérieur de la Tour\nSeaside Route,Route Bordemer\n")
	_world.sandbox.write_json("Data/Studio/zones/zone_2.json", {"id": 2, "dbSymbol": "zone_2", "klass": "Zone", "maps": [20], "panelId": 7, "forcedWeather": null})
	_world.sandbox.write_json("Data/Studio/zones/zone_1.json", {"id": 1, "dbSymbol": "zone_1", "klass": "Zone", "maps": [19], "panelId": 1})
	_world.sandbox.write("Data/Studio/zones/zone_9.json", "{ broken")
	_studio = StudioProject.install(_world)
	_world.texts.language = "en"


func after_test() -> void:
	_studio.uninstall()
	_world.root.free()
	_world.cleanup()


func test_a_studio_zone_is_named_by_its_line_with_its_panel_as_banner() -> void:
	var zone := _world.zones.find(&"zone_2")
	assert_str(zone.id).is_equal("zone_2")
	assert_str(zone.banner).is_equal("panel_7")
	assert_str(_world.texts.label(zone.name)).is_equal("Seaside Route")
	assert_str(_world.texts.label(_world.zones.find(&"zone_1").name)).is_equal("Exterior of The Tower")
	assert_array(_world.zones.ids()).contains_exactly_in_any_order([&"zone_1", &"zone_2", &"zone_9"])


func test_a_broken_zone_file_is_logged_once() -> void:
	assert_object(_world.zones.find(&"zone_9")).is_null()
	assert_object(_world.zones.find(&"zone_9")).is_null()
	assert_array(_world.logged.filter(func(line: String) -> bool: return line.contains("zone_9.json: not a Studio zone"))).has_size(1)
