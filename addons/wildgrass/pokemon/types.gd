## What types there are: those the game registers, then its resources
## (`res://types/<id>.tres`), then what sources give, each read the first
## time it is asked for. The engine ships none.
extends RefCounted

const _Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const _Log := preload("res://addons/wildgrass/core/log/log.gd")
const _Catalog := preload("res://addons/wildgrass/pokemon/catalog.gd")

@warning_ignore("shadowed_global_identifier")
var log: _Log

var _catalog: _Catalog


func _init(paths: _Paths, logger: _Log) -> void:
	log = logger
	_catalog = _Catalog.new(paths, logger, &"types", WgType, &"types", "type")


## Makes `type` known by its id; it wins over a resource or a source's.
func register(type: WgType) -> void:
	_catalog.register(type, type.id)


## Adds an origin of types: `read` is given an id the engine does not have
## and returns its `WgType`, or null; `ids` returns the ids it has.
func add_source(read: Callable, ids := Callable()) -> void:
	_catalog.add_source(read, ids)


## The type of that id; null, logged once, if unknown.
func find(id: StringName) -> WgType:
	return _catalog.find(id) as WgType


func has(id: StringName) -> bool:
	return _catalog.find(id, false) != null


## How hard `attacking` hits a Pokémon of the types `defending`: the factors
## multiplied. An unknown type is logged once and counts 1.
func factor(attacking: StringName, defending: Array) -> float:
	var attacker := find(attacking)
	var result := 1.0
	for defender: Variant in defending:
		var id := StringName(str(defender))
		if find(id) != null and attacker != null:
			result *= attacker.factor_against(id)
	return result


## The id of every type known, none read.
func ids() -> Array[StringName]:
	return _catalog.ids()


## Every type, read, by id.
func all() -> Array[WgType]:
	var found: Array[WgType] = []
	found.assign(_catalog.all())
	found.sort_custom(func(a: WgType, b: WgType) -> bool: return String(a.id) < String(b.id))
	return found
