## What items there are: the game's, and a Studio project's, each read the
## first time it is asked for. And what using one does.
extends RefCounted

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")
const ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")

## Studio's item files, inside the data folder: `<id>.json`.
const STUDIO_FOLDER := "Studio/items/"
## Studio's item icons, inside the graphics folder: `<icon>.png`.
const STUDIO_ICONS := "icons/"
const NAME_TEXTS := 100012
const DESCRIPTION_TEXTS := 100013
const PLURAL_TEXTS := 9001
## Fields every Studio item has; the others go to `data`.
const STUDIO_FIELDS: Array[String] = [
	"klass", "id", "dbSymbol", "icon", "price", "socket", "position", "isLimited", "isMapUsable",
]

@warning_ignore("shadowed_global_identifier")
var log: Log

var _paths: Paths
var _config: ConfigRegistry
var _items: Dictionary[StringName, WgItem] = {}
var _uses: Dictionary[StringName, Callable] = {}
var _unknown: Dictionary[StringName, bool] = {}


func _init(paths: Paths, logger: Log, config_registry: ConfigRegistry) -> void:
	_paths = paths
	log = logger
	_config = config_registry


## Makes `item` known by its id; it wins over a Studio item of that id.
func register(item: WgItem) -> void:
	if item.id.is_empty():
		log.error(&"items", "an item needs an id")
		return
	_items[item.id] = item


## The item of that id, the game's or Studio's; null, logged once, if unknown.
func item(id: StringName) -> WgItem:
	if not _items.has(id):
		var read := _read_studio(id)
		if read == null:
			if not _unknown.has(id):
				_unknown[id] = true
				log.error(&"items", "unknown item '%s'" % id)
			return null
		_items[id] = read
	return _items[id]


func has(id: StringName) -> bool:
	return _items.has(id) or FileAccess.file_exists(_studio_path(id))


## `use` is what using an item does, by its id or its kind: called with the
## item's id, maybe a coroutine; it returns false if the item was not used up.
func add_use(id_or_kind: StringName, use: Callable) -> void:
	_uses[id_or_kind] = use


## What using `found` does, by its id, else its kind; invalid if nothing.
func use_of(found: WgItem) -> Callable:
	if _uses.has(found.id):
		return _uses[found.id]
	if not found.kind.is_empty() and _uses.has(found.kind):
		return _uses[found.kind]
	return Callable()


func bag_config() -> WgBagConfig:
	return _config.get_config(&"bag") as WgBagConfig


func _studio_path(id: StringName) -> String:
	return _paths.resolve(&"data", STUDIO_FOLDER + "%s.json" % id)


func _read_studio(id: StringName) -> WgItem:
	var path := _studio_path(id)
	if not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or str(data.get("dbSymbol", "")) != str(id):
		log.error(&"items", "%s: not a Studio item" % path)
		return null
	var read := WgItem.new()
	read.id = id
	read.kind = StringName(str(data.get("klass", "Item")).trim_suffix("Item").to_snake_case())
	var number := int(data.get("id", 0))
	read.name = "{text:%d:%d}" % [NAME_TEXTS, number]
	read.description = "{text:%d:%d}" % [DESCRIPTION_TEXTS, number]
	read.plural = "{text:%d:%d}" % [PLURAL_TEXTS, number]
	read.pocket = bag_config().pocket_of_socket(int(data.get("socket", 0)))
	read.position = int(data.get("position", 0))
	read.price = int(data.get("price", 0))
	read.consumed = bool(data.get("isLimited", true))
	read.usable = bool(data.get("isMapUsable", false))
	if data.has("icon"):
		read.icon_path = _paths.resolve(&"graphics", STUDIO_ICONS + "%s.png" % data["icon"])
		read.on_missing_icon = _paths.report_missing.bind("item %s" % id)
	for key: String in data:
		if key not in STUDIO_FIELDS:
			read.data[key.to_snake_case()] = data[key]
	return read
