## What natures there are: those the game registers, then its resources
## (`res://natures/<id>.tres`), then what sources give, each read the first
## time it is asked for. The engine ships none. A Pokémon's nature is drawn
## by number: a number modulo `count()`, then the nature of that number.
extends RefCounted

const _Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const _Log := preload("res://addons/wildgrass/core/log/log.gd")
const _Catalog := preload("res://addons/wildgrass/pokemon/catalog.gd")

var _log: _Log
var _catalog: _Catalog
## The natures by number, once all read.
var _numbered: Dictionary[int, WgNature] = {}
var _count := -1


func _init(paths: _Paths, logger: _Log) -> void:
	_log = logger
	_catalog = _Catalog.new(paths, logger, &"natures", WgNature, &"natures", "nature")


## Makes `nature` known by its id; it wins over a resource or a source's.
func register(nature: WgNature) -> void:
	_catalog.register(nature, nature.id)
	_count = -1


## Adds an origin of natures: `read` is given an id the engine does not have
## and returns its `WgNature`, or null; `ids` returns the ids it has.
func add_source(read: Callable, ids := Callable()) -> void:
	_catalog.add_source(read, ids)
	_count = -1


## The nature of that id; null, logged once, if unknown.
func find(id: StringName) -> WgNature:
	return _catalog.find(id) as WgNature


func has(id: StringName) -> bool:
	return _catalog.find(id, false) != null


## How many natures there are.
func count() -> int:
	_index()
	return _count


## The nature of that number; null, logged, if none has it.
func of_number(number: int) -> WgNature:
	_index()
	if not _numbered.has(number):
		_log.error(&"natures", "no nature numbered %d" % number)
		return null
	return _numbered[number]


## The id of every nature known, none read.
func ids() -> Array[StringName]:
	return _catalog.ids()


## Every nature, read, by number then id.
func all() -> Array[WgNature]:
	var found: Array[WgNature] = []
	found.assign(_catalog.all())
	found.sort_custom(func(a: WgNature, b: WgNature) -> bool:
		return a.number < b.number if a.number != b.number else String(a.id) < String(b.id))
	return found


func _index() -> void:
	if _count >= 0:
		return
	_numbered.clear()
	var found := all()
	_count = found.size()
	for nature in found:
		if not _numbered.has(nature.number):
			_numbered[nature.number] = nature
