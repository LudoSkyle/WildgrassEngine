## A Studio project's items (`Data/Studio/items/<dbSymbol>.json`), read as
## they are the first time they are asked for: a source of the items service.
## An item's name, description and plural are Studio texts.
extends RefCounted

const _Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const _Log := preload("res://addons/wildgrass/core/log/log.gd")

## Studio's pockets, in Studio's order: its number (`socket`), the engine's
## pocket, its name among Studio's texts; giving a key item shows it.
const POCKETS: Array[Dictionary] = [
	{"id": "items", "name": "{text:100015:4}", "socket": 1},
	{"id": "balls", "name": "{text:100015:1}", "socket": 2},
	{"id": "medicine", "name": "{text:100015:0}", "socket": 6},
	{"id": "tms", "name": "{text:100015:5}", "socket": 3},
	{"id": "key_items", "name": "{text:100015:8}", "socket": 5, "reveal": true},
	{"id": "berries", "name": "{text:100015:3}", "socket": 4},
]
## The item files, inside the data folder: `<id>.json`.
const FOLDER := "Studio/items/"
## The item icons, inside the graphics folder: `<icon>.png`.
const ICONS := "icons/"
const NAME_TEXTS := 100012
const DESCRIPTION_TEXTS := 100013
const PLURAL_TEXTS := 9001
## Fields every Studio item has; the others go to `data`.
const FIELDS: Array[String] = [
	"klass", "id", "dbSymbol", "icon", "price", "socket", "position", "isLimited", "isMapUsable",
]

@warning_ignore("shadowed_global_identifier")
var log: _Log

var _paths: _Paths


func _init(paths: _Paths, logger: _Log) -> void:
	_paths = paths
	log = logger


## The bag's pockets of a Studio project, as the bag config has them.
static func pockets() -> Array:
	var shown := []
	for pocket: Dictionary in POCKETS:
		var kept := pocket.duplicate()
		kept.erase("socket")
		shown.append(kept)
	return shown


## Every item id of the project, by its file.
func ids() -> Array[StringName]:
	var found: Array[StringName] = []
	var path := _paths.resolve(&"data", FOLDER)
	if not DirAccess.dir_exists_absolute(path):
		return found
	var files := DirAccess.get_files_at(path)
	files.sort()
	for file in files:
		if file.ends_with(".json"):
			found.append(StringName(file.get_basename()))
	return found


## The item of `id`, or null if the project has none.
func read(id: StringName) -> WgItem:
	var path := _paths.resolve(&"data", FOLDER + "%s.json" % id)
	if not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or str(data.get("dbSymbol", "")) != str(id):
		log.error(&"studio", "%s: not a Studio item" % path)
		return null
	var item := WgItem.new()
	item.id = id
	item.kind = StringName(str(data.get("klass", "Item")).trim_suffix("Item").to_snake_case())
	var number := int(data.get("id", 0))
	item.name = "{text:%d:%d}" % [NAME_TEXTS, number]
	item.description = "{text:%d:%d}" % [DESCRIPTION_TEXTS, number]
	item.plural = "{text:%d:%d}" % [PLURAL_TEXTS, number]
	item.pocket = _pocket(int(data.get("socket", 0)))
	item.position = int(data.get("position", 0))
	item.price = int(data.get("price", 0))
	item.consumed = bool(data.get("isLimited", true))
	item.usable = bool(data.get("isMapUsable", false))
	if data.has("icon"):
		item.icon_path = _paths.resolve(&"graphics", ICONS + "%s.png" % data["icon"])
		item.on_missing_icon = _paths.report_missing.bind("item %s" % id)
	for key: String in data:
		if key not in FIELDS:
			item.data[key.to_snake_case()] = data[key]
	return item


static func _pocket(socket: int) -> StringName:
	for pocket: Dictionary in POCKETS:
		if int(pocket["socket"]) == socket:
			return StringName(str(pocket["id"]))
	return &""
