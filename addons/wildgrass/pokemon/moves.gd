## What moves there are: those the game registers, then its resources
## (`res://moves/<id>.tres`), then what sources give, each read the first
## time it is asked for. The engine ships none.
extends RefCounted

const _Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const _Log := preload("res://addons/wildgrass/core/log/log.gd")
const _Catalog := preload("res://addons/wildgrass/pokemon/catalog.gd")

var _catalog: _Catalog


func _init(paths: _Paths, logger: _Log) -> void:
	_catalog = _Catalog.new(paths, logger, &"moves", WgMove, &"moves", "move")


## Makes `move` known by its id; it wins over a resource or a source's.
func register(move: WgMove) -> void:
	_catalog.register(move, move.id)


## Adds an origin of moves: `read` is given an id the engine does not have
## and returns its `WgMove`, or null; `ids` returns the ids it has.
func add_source(read: Callable, ids := Callable()) -> void:
	_catalog.add_source(read, ids)


## The move of that id; null, logged once, if unknown.
func find(id: StringName) -> WgMove:
	return _catalog.find(id) as WgMove


func has(id: StringName) -> bool:
	return _catalog.find(id, false) != null


## The id of every move known, none read.
func ids() -> Array[StringName]:
	return _catalog.ids()


## Every move, read, by number then id.
func all() -> Array[WgMove]:
	var found: Array[WgMove] = []
	found.assign(_catalog.all())
	found.sort_custom(func(a: WgMove, b: WgMove) -> bool:
		return a.number < b.number if a.number != b.number else String(a.id) < String(b.id))
	return found
