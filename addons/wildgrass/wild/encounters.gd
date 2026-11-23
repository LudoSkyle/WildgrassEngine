## Wild Pokémon: the tables found by id (registered, then
## `res://encounters/<id>.tres`, then what sources give), and drawing one
## among the current map's tables.
extends RefCounted

const _Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const _Log := preload("res://addons/wildgrass/core/log/log.gd")
const _ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const _Catalog := preload("res://addons/wildgrass/pokemon/catalog.gd")
const _Maps := preload("res://addons/wildgrass/maps/maps.gd")
const _Story := preload("res://addons/wildgrass/story/story.gd")
const _SpeciesData := preload("res://addons/wildgrass/pokemon/species_data.gd")
const _Tiles := preload("res://addons/wildgrass/tiles/tiles.gd")
const _Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")
const _Pokedex := preload("res://addons/wildgrass/pokedex/pokedex.gd")
const _Dialogue := preload("res://addons/wildgrass/dialogue/dialogue.gd")

## What the engine's `start` says.
const ANNOUNCE := "A wild {name} appeared!"

## A wild Pokémon came out: `{species, form, level, shiny, table}`.
signal encountered(pokemon: Dictionary)

@warning_ignore("shadowed_global_identifier")
var log: _Log
## -1: the chance; 1: every step that can; 0: never.
var forced := -1
## How many wild Pokémon came out.
var count := 0
## The last one.
var last := {}
## Awaited with a wild Pokémon once it came out: the engine's says so in the
## message box. Battles replace it.
var start: Callable

var _config: _ConfigRegistry
var _maps: _Maps
var _story: _Story
var _species: _SpeciesData
var _catalog: _Catalog
var _tiles: _Tiles
var _hooks: _Hooks
var _pokedex: _Pokedex
var _dialogue: _Dialogue
var _rng := RandomNumberGenerator.new()
var _warned: Dictionary[String, bool] = {}


func _init(paths: _Paths, logger: _Log, config_registry: _ConfigRegistry, maps: _Maps, story: _Story, species: _SpeciesData, tiles: _Tiles, hooks: _Hooks, pokedex: _Pokedex, dialogue: _Dialogue) -> void:
	log = logger
	_tiles = tiles
	_hooks = hooks
	_pokedex = pokedex
	_dialogue = dialogue
	start = announce
	_config = config_registry
	_maps = maps
	_story = story
	_species = species
	_catalog = _Catalog.new(paths, logger, &"encounters", WgEncounterTable, &"encounters", "encounter table")
	_rng.randomize()


func config() -> WgEncountersConfig:
	return _config.get_config(&"encounters") as WgEncountersConfig


## Makes `table` known by its id; it wins over a resource or a source's.
func register(table: WgEncounterTable) -> void:
	_catalog.register(table, table.id)


## Adds an origin of tables: `read` is given an id the engine does not have
## and returns its `WgEncounterTable`, or null; `ids` returns the ids it has.
func add_source(read: Callable, ids := Callable()) -> void:
	_catalog.add_source(read, ids)


## The table of that id; null, logged once, if unknown.
func find(id: StringName) -> WgEncounterTable:
	return _catalog.find(id) as WgEncounterTable


## The id of every table known, none read.
func ids() -> Array[StringName]:
	return _catalog.ids()


## Makes the chance repeatable.
@warning_ignore("shadowed_global_identifier")
func seed(value: int) -> void:
	_rng.seed = value


## The current map's `WgEncounters` node, or null.
func map_node() -> WgEncounters:
	return _find_node(_maps.current) if _maps.current != null else null


## The tables of the current map that fit the terrain, the tool and the area,
## their condition holding.
func tables_for(terrain: StringName, tool := &"", area := 0) -> Array[WgEncounterTable]:
	var found: Array[WgEncounterTable] = []
	var node := map_node()
	if node == null:
		return found
	var all: Array[WgEncounterTable] = node.tables.duplicate()
	for id in node.table_ids:
		var table := find(id)
		if table != null:
			all.append(table)
	for table in all:
		if table != null and table.fits(terrain, tool, area) and _story.check(table.condition):
			found.append(table)
	return found


## A wild Pokémon of the current map's tables, `{species, form, level,
## shiny, table}`, or {} if none fits.
func draw(terrain: StringName, tool := &"", area := 0) -> Dictionary:
	var pool: Array[Dictionary] = []
	var total := 0.0
	for table in tables_for(terrain, tool, area):
		for entry in table.pokemon:
			if _valid(entry, table):
				pool.append({"entry": entry, "table": table.id})
				total += float(entry.get("weight", 1.0))
	if pool.is_empty():
		return {}
	var pick := _rng.randf() * total
	var chosen: Dictionary = pool.back()
	for candidate in pool:
		pick -= float(candidate["entry"].get("weight", 1.0))
		if pick < 0.0:
			chosen = candidate
			break
	var entry: Dictionary = chosen["entry"]
	var low := int(entry.get("min_level", 1))
	var shiny_rate := int(entry.get("shiny_rate", 0))
	if shiny_rate == 0:
		shiny_rate = config().shiny_rate
	return {
		"species": StringName(str(entry["species"])),
		"form": int(entry.get("form", 0)),
		"level": _rng.randi_range(low, int(entry.get("max_level", low))),
		"shiny": shiny_rate > 0 and _rng.randi_range(1, shiny_rate) == 1,
		"table": chosen["table"],
	}


## What a step of `walker` brings out: a wild Pokémon, or {}. Its cell's
## terrain must have a table; the chance is the tables' own, else the map's
## for a step walked or run.
func roll(walker: WgWalker) -> Dictionary:
	if forced == 0:
		return {}
	var terrain: Variant = _tiles.data(walker.cell, &"encounter")
	if terrain == null or str(terrain).is_empty():
		return {}
	var area := int(_tiles.data(walker.cell, &"encounter_area")) if _tiles.data(walker.cell, &"encounter_area") != null else 0
	var tables := tables_for(StringName(str(terrain)), &"", area)
	if tables.is_empty():
		return {}
	var rate := 0.0
	for table in tables:
		rate = maxf(rate, table.rate)
	if rate <= 0.0:
		rate = map_node().chance(walker.is_running)
	if forced != 1 and _rng.randf() * 100.0 >= rate:
		return {}
	return draw(StringName(str(terrain)), &"", area)


## A wild Pokémon comes out: the hook `wild_encounter` may change it or return
## {} to cancel it; then it is counted, seen in the Pokédex, and `start` is
## awaited. False if cancelled.
func meet(pokemon: Dictionary) -> bool:
	var met: Variant = _hooks.filter(&"wild_encounter", pokemon)
	if not met is Dictionary or (met as Dictionary).is_empty():
		return false
	count += 1
	last = met
	encountered.emit(met)
	_pokedex.see(met["species"], int(met.get("form", 0)))
	await start.call(met)
	return true


## The engine's `start`: "A wild {name} appeared!".
func announce(pokemon: Dictionary) -> void:
	var found := _species.find(pokemon["species"])
	await _dialogue.say(ANNOUNCE, {"values": {"name": found.name if found != null else str(pokemon["species"])}})


## True for an entry that can be drawn; a wrong one is logged once.
func _valid(entry: Dictionary, table: WgEncounterTable) -> bool:
	var species := StringName(str(entry.get("species", "")))
	var low := int(entry.get("min_level", 1))
	var high := int(entry.get("max_level", low))
	var problem := ""
	if not _species.has(species):
		problem = "unknown species '%s'" % species
	elif low < 1 or high < low:
		problem = "levels %d to %d" % [low, high]
	elif float(entry.get("weight", 1.0)) <= 0.0:
		problem = "no weight"
	if problem.is_empty():
		return true
	var message := "encounter table '%s': %s, left out" % [table.id, problem]
	if not _warned.has(message):
		_warned[message] = true
		log.warn(&"encounters", message)
	return false


static func _find_node(node: Node) -> WgEncounters:
	if node is WgEncounters:
		return node
	for child in node.get_children():
		var found := _find_node(child)
		if found != null:
			return found
	return null
