## Wild Pokémon: the tables found by id (registered, then
## `res://encounters/<id>.tres`, then what sources give), and drawing one
## among the current map's tables.
extends RefCounted

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")
const ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const Catalog := preload("res://addons/wildgrass/pokemon/catalog.gd")
const Maps := preload("res://addons/wildgrass/maps/maps.gd")
const Story := preload("res://addons/wildgrass/story/story.gd")
const SpeciesData := preload("res://addons/wildgrass/pokemon/species_data.gd")

@warning_ignore("shadowed_global_identifier")
var log: Log

var _config: ConfigRegistry
var _maps: Maps
var _story: Story
var _species: SpeciesData
var _catalog: Catalog
var _rng := RandomNumberGenerator.new()
var _warned: Dictionary[String, bool] = {}


func _init(paths: Paths, logger: Log, config_registry: ConfigRegistry, maps: Maps, story: Story, species: SpeciesData) -> void:
	log = logger
	_config = config_registry
	_maps = maps
	_story = story
	_species = species
	_catalog = Catalog.new(paths, logger, &"encounters", WgEncounterTable, &"encounters", "encounter table")
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
	if shiny_rate <= 0:
		shiny_rate = config().shiny_rate
	return {
		"species": StringName(str(entry["species"])),
		"form": int(entry.get("form", 0)),
		"level": _rng.randi_range(low, int(entry.get("max_level", low))),
		"shiny": _rng.randi_range(1, shiny_rate) == 1,
		"table": chosen["table"],
	}


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
