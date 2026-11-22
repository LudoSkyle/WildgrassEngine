## What the player has seen and caught, form by form, and the Pokédexes that
## list species in a region's order: those the game registers, then its
## resources (`res://dex/<id>.tres`), then what sources give; `national`, if
## none has that id, is every species by national number.
extends RefCounted

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")
const ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const Catalog := preload("res://addons/wildgrass/pokemon/catalog.gd")
const SpeciesData := preload("res://addons/wildgrass/pokemon/species_data.gd")

## A form of species `id` was seen; `first`: the first time.
signal seen(id: StringName, form: int, first: bool)
signal caught(id: StringName, form: int, first: bool)

@warning_ignore("shadowed_global_identifier")
var log: Log
## The ids of the player's Pokédexes, in order: the config's at a new game.
var dexes: Array[StringName]:
	get:
		if _dexes.is_empty():
			var given: Array[StringName] = []
			for id in config().dexes:
				given.append(StringName(id))
			return given
		return _dexes.duplicate()
## The Pokédex shown: the first of `dexes` unless one was chosen.
var dex: StringName:
	get:
		return _dex if not _dex.is_empty() and _dex in dexes else dexes[0]
	set(value):
		_dex = value

var _config: ConfigRegistry
var _species: SpeciesData
var _catalog: Catalog
## Species id -> its forms seen, sorted.
var _seen: Dictionary[StringName, Array] = {}
var _caught: Dictionary[StringName, Array] = {}
var _dexes: Array[StringName] = []
var _dex: StringName = &""
var _national: WgDex
var _skipped: Dictionary[String, bool] = {}


func _init(paths: Paths, logger: Log, config_registry: ConfigRegistry, species: SpeciesData) -> void:
	log = logger
	_config = config_registry
	_species = species
	_catalog = Catalog.new(paths, logger, &"dex", WgDex, &"pokedex", "Pokédex")


func config() -> WgPokedexConfig:
	return _config.get_config(&"pokedex") as WgPokedexConfig


## Records form `form` of species `id` as seen; true the first time. False
## for an unknown species.
func see(id: StringName, form := 0) -> bool:
	if _species.find(id) == null:
		return false
	var first := _add(_seen, id, form)
	seen.emit(id, form, first)
	return first


## Records form `form` of species `id` as caught, so seen too; true the first
## time it is caught.
func catch(id: StringName, form := 0) -> bool:
	if _species.find(id) == null:
		return false
	var first_seen := _add(_seen, id, form)
	seen.emit(id, form, first_seen)
	var first := _add(_caught, id, form)
	caught.emit(id, form, first)
	return first


## True if form `form` of species `id` was seen; -1: any form.
func is_seen(id: StringName, form := -1) -> bool:
	return _has(_seen, id, form)


func is_caught(id: StringName, form := -1) -> bool:
	return _has(_caught, id, form)


## The forms of species `id` seen, sorted.
func forms_seen(id: StringName) -> Array[int]:
	var forms: Array[int] = []
	forms.assign(_seen.get(id, []))
	return forms


func forms_caught(id: StringName) -> Array[int]:
	var forms: Array[int] = []
	forms.assign(_caught.get(id, []))
	return forms


## Species `id` as never seen.
func forget(id: StringName) -> void:
	_seen.erase(id)
	_caught.erase(id)


## Makes `found` known by its id; it wins over a resource or a source's.
func register(found: WgDex) -> void:
	_catalog.register(found, found.id)


## Adds an origin of Pokédexes: `read` is given an id the engine does not
## have and returns its `WgDex`, or null; `ids` returns the ids it has.
func add_source(read: Callable, ids := Callable()) -> void:
	_catalog.add_source(read, ids)


## The Pokédex of that id; `national` is the engine's if none has that id.
## Null, logged once, if unknown.
func find(id: StringName) -> WgDex:
	var found := _catalog.find(id, id != &"national") as WgDex
	if found == null and id == &"national":
		return national()
	return found


## Every species by national number, form 0.
func national() -> WgDex:
	if _national == null:
		_national = WgDex.new()
		_national.id = &"national"
		_national.name = "National Pokédex"
		var every := _species.all()
		for species in every:
			_national.creatures.append({"species": species.id, "form": 0})
		if not every.is_empty():
			_national.start = every[0].number
	return _national


## The species of Pokédex `id` the engine knows, each `{species, form,
## number}`, in order; one it does not know is logged once and skipped.
func entries(id: StringName = dex) -> Array[Dictionary]:
	var found := find(id)
	var listed: Array[Dictionary] = []
	if found == null:
		return listed
	for index in found.creatures.size():
		var creature: Dictionary = found.creatures[index]
		var species := StringName(str(creature.get("species", "")))
		if not _species.has(species):
			var problem := "Pokédex '%s' lists an unknown species '%s'" % [id, species]
			if not _skipped.has(problem):
				_skipped[problem] = true
				log.warn(&"pokedex", problem)
			continue
		var number := found.start + index
		if found == _national:
			number = _species.find(species).number
		listed.append({"species": species, "form": int(creature.get("form", 0)), "number": number})
	return listed


## The species of Pokédex `id` seen, any form.
func seen_count(id: StringName = dex) -> int:
	return entries(id).filter(func(entry: Dictionary) -> bool: return is_seen(entry["species"])).size()


func caught_count(id: StringName = dex) -> int:
	return entries(id).filter(func(entry: Dictionary) -> bool: return is_caught(entry["species"])).size()


## Gives the player Pokédex `id`, last; false if it is unknown or theirs
## already.
func add_dex(id: StringName) -> bool:
	if id in dexes or find(id) == null:
		return false
	_dexes = dexes
	_dexes.append(id)
	return true


## Everything seen and caught, and the player's Pokédexes, as JSON holds them.
func state() -> Dictionary:
	return {"seen": _forms_state(_seen), "caught": _forms_state(_caught), "dexes": dexes.map(func(id: StringName) -> String: return str(id)), "dex": str(dex)}


func restore(saved: Dictionary) -> void:
	reset()
	_seen = _forms_read(saved.get("seen", {}))
	_caught = _forms_read(saved.get("caught", {}))
	for id: Variant in saved.get("dexes", []) if saved.get("dexes") is Array else []:
		_dexes.append(StringName(str(id)))
	_dex = StringName(str(saved.get("dex", "")))


## A new game: nothing seen, the config's Pokédexes.
func reset() -> void:
	_seen.clear()
	_caught.clear()
	_dexes.clear()
	_dex = &""


## The `save_summary` hook: the species seen in the Pokédex shown.
func save_summary(summary: Dictionary, _slot: int) -> Dictionary:
	summary["pokedex"] = seen_count()
	return summary


static func _add(forms: Dictionary[StringName, Array], id: StringName, form: int) -> bool:
	var held: Array = forms.get_or_add(id, [])
	if form in held:
		return false
	held.append(form)
	held.sort()
	return true


static func _has(forms: Dictionary[StringName, Array], id: StringName, form: int) -> bool:
	return forms.has(id) and (form < 0 or form in forms[id])


static func _forms_state(forms: Dictionary[StringName, Array]) -> Dictionary:
	var saved := {}
	for id: StringName in forms:
		saved[str(id)] = forms[id].duplicate()
	return saved


static func _forms_read(saved: Variant) -> Dictionary[StringName, Array]:
	var forms: Dictionary[StringName, Array] = {}
	if not saved is Dictionary:
		return forms
	for id: Variant in saved:
		var held := []
		for form: Variant in saved[id] if saved[id] is Array else []:
			if not int(form) in held:
				held.append(int(form))
		held.sort()
		forms[StringName(str(id))] = held
	return forms
