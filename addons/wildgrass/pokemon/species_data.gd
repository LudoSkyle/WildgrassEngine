## What species there are: those the game registers, then its resources
## (`res://pokemon/<id>.tres`), then what sources give, each read the first
## time it is asked for, no picture loaded before it shows.
extends RefCounted

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")
const Catalog := preload("res://addons/wildgrass/pokemon/catalog.gd")

@warning_ignore("shadowed_global_identifier")
var log: Log

var _paths: Paths
var _catalog: Catalog
var _warned: Dictionary[String, bool] = {}


func _init(paths: Paths, logger: Log) -> void:
	_paths = paths
	log = logger
	_catalog = Catalog.new(paths, logger, &"pokemon", WgSpecies, &"species", "species")


## Makes `species` known by its id; it wins over a resource or a source's.
func register(species: WgSpecies) -> void:
	_catalog.register(species, species.id)


## Adds an origin of species: `read` is given an id the engine does not have
## and returns its `WgSpecies`, or null; `ids` returns the ids it has.
func add_source(read: Callable, ids := Callable()) -> void:
	_catalog.add_source(read, ids)


## The species of that id; null, logged once, if unknown.
func find(id: StringName) -> WgSpecies:
	return _prepared(_catalog.find(id) as WgSpecies)


func has(id: StringName) -> bool:
	return _catalog.find(id, false) != null


## Form `form_number` of species `id`: its form 0 if it has no such form,
## logged once; null if the species is unknown or has no form.
func form(id: StringName, form_number := 0) -> WgSpeciesForm:
	var species := find(id)
	if species == null:
		return null
	var found := species.find_form(form_number)
	if found != null:
		return found
	if species.forms.is_empty() or species.forms[0] == null:
		_warn_once("species '%s' has no form" % id)
		return null
	_warn_once("species '%s' has no form %d; form %d instead" % [id, form_number, species.forms[0].form])
	return species.forms[0]


## The id of every species known, none read.
func ids() -> Array[StringName]:
	return _catalog.ids()


## Every species, read, by national number then id.
func all() -> Array[WgSpecies]:
	var found: Array[WgSpecies] = []
	for species: Resource in _catalog.all():
		found.append(_prepared(species as WgSpecies))
	found.sort_custom(func(a: WgSpecies, b: WgSpecies) -> bool:
		return a.number < b.number if a.number != b.number else String(a.id) < String(b.id))
	return found


## `species`, its forms reporting a missing picture or cry.
func _prepared(species: WgSpecies) -> WgSpecies:
	if species != null:
		for found in species.forms:
			if found != null and not found.on_missing.is_valid():
				found.on_missing = _paths.report_missing.bind("species %s" % species.id)
	return species


func _warn_once(message: String) -> void:
	if _warned.has(message):
		return
	_warned[message] = true
	log.warn(&"species", message)
