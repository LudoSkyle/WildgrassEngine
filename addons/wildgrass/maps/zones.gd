## What zones there are: those the game registers, then its resources
## (`res://zones/<id>.tres`), then what sources give. And the place's banner,
## shown when the traveller arrives in a zone whose name differs from the
## last one's, once no transition covers the map.
extends RefCounted

const _Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const _Log := preload("res://addons/wildgrass/core/log/log.gd")
const _Catalog := preload("res://addons/wildgrass/pokemon/catalog.gd")
const _Maps := preload("res://addons/wildgrass/maps/maps.gd")
const _ScreenRegistry := preload("res://addons/wildgrass/core/screens/screen_registry.gd")
const _Texts := preload("res://addons/wildgrass/texts/texts.gd")

## The banner was shown with this name and style.
signal banner_shown(zone_name: String, style: StringName)

@warning_ignore("shadowed_global_identifier")
var log: _Log
## The banner, made the first time it shows: the scene of the screen
## `location_banner`, put on the screens' layer but never on their stack, so
## it takes no key and stops no one.
var banner: WgLocationBanner

var _catalog: _Catalog
var _maps: _Maps
var _screens: _ScreenRegistry
var _texts: _Texts
var _layer: Node
## The name last shown.
var _last_name := ""
## The zone waiting for the transition to uncover.
var _pending: WgZone


func _init(paths: _Paths, logger: _Log, maps: _Maps, screens: _ScreenRegistry, texts: _Texts, layer: Node) -> void:
	log = logger
	_catalog = _Catalog.new(paths, logger, &"zones", WgZone, &"zones", "zone")
	_maps = maps
	_screens = screens
	_texts = texts
	_layer = layer
	maps.zone_changed.connect(_on_zone_changed)
	maps.map_changed.connect(_on_map_changed)
	maps.cleared.connect(_on_cleared)
	screens.screen_closed.connect(_on_screen_closed)


## Makes `zone` known by its id; it wins over a resource or a source's.
func register(zone: WgZone) -> void:
	_catalog.register(zone, zone.id)


## Adds an origin of zones: `read` is given an id the engine does not have
## and returns its `WgZone`, or null; `ids` returns the ids it has.
func add_source(read: Callable, ids := Callable()) -> void:
	_catalog.add_source(read, ids)


## The zone of that id; null, logged once, if unknown.
func find(id: StringName) -> WgZone:
	return _catalog.find(id) as WgZone


func has(id: StringName) -> bool:
	return _catalog.find(id, false) != null


## The id of every zone known, none read.
func ids() -> Array[StringName]:
	return _catalog.ids()


## The zone of the current map, or null: a zone needs no data.
func current() -> WgZone:
	var map := _maps.current
	return _catalog.find(map.zone, false) as WgZone if map != null and not map.zone.is_empty() else null


## Shows the banner of `zone` now, whatever was shown before.
func show_banner(zone: WgZone) -> void:
	var zone_name := _texts.label(zone.name)
	_last_name = zone_name
	if banner == null or not is_instance_valid(banner):
		banner = _make_banner()
		if banner == null:
			return
	banner.show_zone(zone_name, zone.banner)
	banner_shown.emit(zone_name, zone.banner)


func _make_banner() -> WgLocationBanner:
	var path := _screens.scene_path(&"location_banner")
	var scene := load(path) as PackedScene if not path.is_empty() and ResourceLoader.exists(path) else null
	var node := scene.instantiate() if scene != null else null
	if not node is WgLocationBanner:
		log.error(&"zones", "location_banner: no WgLocationBanner at '%s'" % path)
		if node != null:
			node.free()
		return null
	# Under every screen: a transition or a message covers it.
	_layer.add_child(node)
	_layer.move_child(node, 0)
	return node


func _on_zone_changed(_old: StringName, new_zone: StringName) -> void:
	_pending = null
	# A zone needs no data: without any, no banner.
	var zone := _catalog.find(new_zone, false) as WgZone if not new_zone.is_empty() else null
	if zone == null or zone.name.is_empty() or _texts.label(zone.name) == _last_name:
		return
	_pending = zone
	_show_pending()


func _on_map_changed(_map: WgMap) -> void:
	_show_pending()


func _on_screen_closed(_screen_name: StringName) -> void:
	_show_pending()


## The zone waiting shows once no transition covers the map: the maps' own,
## or the title's fade into the game.
func _show_pending() -> void:
	if _pending == null or _maps.is_changing or _screens.stack().any(func(screen: WgScreen) -> bool: return screen is WgTransition):
		return
	var zone := _pending
	_pending = null
	show_banner(zone)


func _on_cleared() -> void:
	_last_name = ""
	_pending = null
