## A Studio project's wild groups (`Data/Studio/groups/<dbSymbol>.json`),
## read as they are the first time they are asked for: a source of the
## encounters service's tables.
extends RefCounted

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")

const FOLDER := "Studio/groups/"

@warning_ignore("shadowed_global_identifier")
var log: Log

var _paths: Paths
var _warned: Dictionary[String, bool] = {}


func _init(paths: Paths, logger: Log) -> void:
	_paths = paths
	log = logger


## The table of group `id`, or null if the project has none.
func read(id: StringName) -> WgEncounterTable:
	var path := _paths.resolve(&"data", FOLDER + "%s.json" % id)
	if not FileAccess.file_exists(path):
		return null
	var parser := JSON.new()
	var data: Variant = parser.data if parser.parse(FileAccess.get_file_as_string(path)) == OK else null
	if not data is Dictionary or str(data.get("dbSymbol", "")) != str(id):
		_warn_once(&"error", "%s: not a Studio group" % path.get_file())
		return null
	var table := WgEncounterTable.new()
	table.id = id
	table.terrain = StringName(str(data.get("systemTag", "")).to_snake_case())
	table.area = int(data.get("terrainTag", 0))
	table.tool = StringName(str(data["tool"]).to_snake_case()) if data.get("tool") is String else &""
	var steps := int(data.get("stepsAverage", 0))
	table.rate = 100.0 / steps if steps > 0 else 0.0
	table.double = str(data.get("vsType", "")) == "double"
	table.condition = _condition(id, data.get("customConditions", []))
	var encounters: Variant = data.get("encounters", [])
	for encounter: Variant in encounters if encounters is Array else []:
		if encounter is Dictionary:
			table.pokemon.append(_pokemon(encounter))
	return table


func ids() -> Array[StringName]:
	var found: Array[StringName] = []
	var folder := _paths.resolve(&"data", FOLDER)
	if not DirAccess.dir_exists_absolute(folder):
		return found
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".json"):
			found.append(StringName(file.get_basename()))
	return found


## Its switches as story flags, all of them; the map is the one choosing the
## table; another kind is logged once and ignored.
func _condition(id: StringName, conditions: Variant) -> String:
	var flags: PackedStringArray = []
	for condition: Variant in conditions if conditions is Array else []:
		if not condition is Dictionary:
			continue
		match str(condition.get("type", "")):
			"enabledSwitch":
				flags.append("switch_%d" % int(condition.get("value", 0)))
			"mapId":
				pass
			var kind:
				_warn_once(&"warn", "group %s: its condition '%s' is not read yet; ignored" % [id, kind])
		if str(condition.get("relationWithPreviousCondition", "AND")) != "AND":
			_warn_once(&"warn", "group %s: conditions joined by OR are read as AND" % id)
	return ", ".join(flags)


func _pokemon(encounter: Dictionary) -> Dictionary:
	var setup: Variant = encounter.get("levelSetup", {})
	var low := 1
	var high := 1
	if setup is Dictionary:
		var level: Variant = setup.get("level", 1)
		if level is Dictionary:
			low = int(level.get("minimumLevel", 1))
			high = int(level.get("maximumLevel", low))
		else:
			low = int(level)
			high = low
	var shiny: Variant = encounter.get("shinySetup", {})
	var shiny_rate := 0
	if shiny is Dictionary and str(shiny.get("kind", "")) == "rate":
		var chance := float(shiny.get("rate", 0.0))
		shiny_rate = maxi(1, roundi(1.0 / chance)) if chance > 0.0 else -1
	return {
		"species": StringName(str(encounter.get("specie", ""))),
		"form": int(encounter.get("form", 0)),
		"min_level": low,
		"max_level": high,
		"weight": float(encounter.get("randomEncounterChance", 1)),
		"shiny_rate": shiny_rate,
	}


func _warn_once(level: StringName, message: String) -> void:
	if _warned.has(message):
		return
	_warned[message] = true
	if level == &"error":
		log.error(&"studio", message)
	else:
		log.warn(&"studio", message)
