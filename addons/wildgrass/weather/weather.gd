## The weather of the maps outside: the one on, a map's own, and the
## weathers known (registered, then `res://weather/<id>.tres`, then what
## sources give; `none`, the engine's).
extends RefCounted

const _Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const _Log := preload("res://addons/wildgrass/core/log/log.gd")
const _Catalog := preload("res://addons/wildgrass/pokemon/catalog.gd")

## The weather on changed.
signal changed(old: StringName, new: StringName)

@warning_ignore("shadowed_global_identifier")
var log: _Log
## What draws the weather, under the maps' host, on maps outside.
var layer: WgWeatherLayer
## The day and night the sun's tone fades with.
var daytime: RefCounted
## The weather on, unless the current map has its own; not saved.
var current: StringName = &"none":
	set(value):
		current = value
		_tell()

var _catalog: _Catalog
var _none: WgWeather
var _maps: Object
var _shown: StringName = &"none"


func _init(paths: _Paths, logger: _Log) -> void:
	log = logger
	_catalog = _Catalog.new(paths, logger, &"weather", WgWeather, &"weather", "weather")
	_none = WgWeather.new()
	_none.id = &"none"
	_none.name = "wg.weather.clear"


## Makes `weather` known by its id; it wins over a resource or a source's.
func register(weather: WgWeather) -> void:
	_catalog.register(weather, weather.id)


## Adds an origin of weathers: `read` is given an id the engine does not have
## and returns its `WgWeather`, or null; `ids` returns the ids it has.
func add_source(read: Callable, ids := Callable()) -> void:
	_catalog.add_source(read, ids)


## The weather of that id: `none` is the engine's unless the game has its
## own; null, logged once, if unknown.
func find(id: StringName) -> WgWeather:
	var found := _catalog.find(id, id != &"none") as WgWeather
	return found if found != null or id != &"none" else _none


## Every weather's id, `none` first.
func ids() -> Array[StringName]:
	var known: Array[StringName] = [&"none"]
	for id in _catalog.ids():
		if id != &"none":
			known.append(id)
	return known


## Follows the current map: its own weather wins.
func follow(maps: Object) -> void:
	_maps = maps
	_shown = shown()
	maps.map_changed.connect(_on_map_changed)


func _on_map_changed(_map: WgMap) -> void:
	_tell()
	_refresh()


## The id of the weather shown now: the current map's own, else `current`.
func shown() -> StringName:
	var map: WgMap = _maps.current if _maps != null else null
	if map != null and not map.weather.is_empty():
		return map.weather
	return current


## The weather shown now; `none` if it is unknown.
func weather() -> WgWeather:
	var found := find(shown())
	return found if found != null else _none


## The next weather known, then `none`: the debug tools.
func cycle() -> void:
	var known := ids()
	current = known[(known.find(current) + 1) % known.size()]


func _tell() -> void:
	var now := shown()
	if now != _shown:
		var old := _shown
		_shown = now
		changed.emit(old, now)
		_refresh()


## The layer draws the weather shown on a map outside, nothing inside.
func _refresh() -> void:
	if _maps == null or not is_instance_valid(_maps.host):
		return
	if not is_instance_valid(layer):
		layer = WgWeatherLayer.new()
		_maps.host.add_child(layer)
	layer.daytime = daytime
	var map: WgMap = _maps.current
	layer.show_weather(weather() if map != null and map.outside else null)
