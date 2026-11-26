## What abilities there are: those the game registers, then its resources
## (`res://abilities/<id>.tres`), then what sources give, each read the
## first time it is asked for. The engine ships none.
extends RefCounted

const _Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const _Log := preload("res://addons/wildgrass/core/log/log.gd")
const _Catalog := preload("res://addons/wildgrass/pokemon/catalog.gd")

var _catalog: _Catalog


func _init(paths: _Paths, logger: _Log) -> void:
	_catalog = _Catalog.new(paths, logger, &"abilities", WgAbility, &"abilities", "ability")


## Makes `ability` known by its id; it wins over a resource or a source's.
func register(ability: WgAbility) -> void:
	_catalog.register(ability, ability.id)


## Adds an origin of abilities: `read` is given an id the engine does not
## have and returns its `WgAbility`, or null; `ids` returns the ids it has.
func add_source(read: Callable, ids := Callable()) -> void:
	_catalog.add_source(read, ids)


## The ability of that id; null, logged once, if unknown.
func find(id: StringName) -> WgAbility:
	return _catalog.find(id) as WgAbility


func has(id: StringName) -> bool:
	return _catalog.find(id, false) != null


## The id of every ability known, none read.
func ids() -> Array[StringName]:
	return _catalog.ids()


## Every ability, read, by number then id.
func all() -> Array[WgAbility]:
	var found: Array[WgAbility] = []
	found.assign(_catalog.all())
	found.sort_custom(func(a: WgAbility, b: WgAbility) -> bool:
		return a.number < b.number if a.number != b.number else String(a.id) < String(b.id))
	return found
