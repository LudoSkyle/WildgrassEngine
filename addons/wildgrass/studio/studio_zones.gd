## A Studio project's zones (`Data/Studio/zones/<dbSymbol>.json`), read the
## first time they are asked for: a source of the zones service. A zone's
## name is its line of the zone names' texts, its banner `panel_<panelId>`.
extends RefCounted

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")

const FOLDER := "Studio/zones/"
const NAME_TEXTS := 100010

@warning_ignore("shadowed_global_identifier")
var log: Log

var _paths: Paths
var _warned: Dictionary[String, bool] = {}


func _init(paths: Paths, logger: Log) -> void:
	_paths = paths
	log = logger


## The zone `id`, or null if the project has none.
func read(id: StringName) -> WgZone:
	var path := _paths.resolve(&"data", FOLDER + "%s.json" % id)
	if not FileAccess.file_exists(path):
		return null
	var parser := JSON.new()
	var data: Variant = parser.data if parser.parse(FileAccess.get_file_as_string(path)) == OK else null
	if not data is Dictionary or str(data.get("dbSymbol", "")) != str(id) or not data.get("id") is float:
		if not _warned.has(path):
			_warned[path] = true
			log.error(&"studio", "%s: not a Studio zone" % path.get_file())
		return null
	var zone := WgZone.new()
	zone.id = id
	zone.name = "{text:%d:%d}" % [NAME_TEXTS, int(data["id"])]
	zone.banner = StringName("panel_%d" % int(data.get("panelId", 0)))
	return zone


func ids() -> Array[StringName]:
	var found: Array[StringName] = []
	var folder := _paths.resolve(&"data", FOLDER)
	if not DirAccess.dir_exists_absolute(folder):
		return found
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".json"):
			found.append(StringName(file.get_basename()))
	return found
