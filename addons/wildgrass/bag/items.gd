## What items there are: those the game registers, then its resources
## (`res://items/<id>.tres`), then what sources give, each read the first time
## it is asked for. And what using one does.
extends RefCounted

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")
const ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")

@warning_ignore("shadowed_global_identifier")
var log: Log

var _paths: Paths
var _config: ConfigRegistry
var _items: Dictionary[StringName, WgItem] = {}
var _uses: Dictionary[StringName, Callable] = {}
var _unknown: Dictionary[StringName, bool] = {}
var _sources: Array[Callable] = []
var _listers: Array[Callable] = []


func _init(paths: Paths, logger: Log, config_registry: ConfigRegistry) -> void:
	_paths = paths
	log = logger
	_config = config_registry


## Makes `item` known by its id; it wins over a resource or a source's.
func register(item: WgItem) -> void:
	if item.id.is_empty():
		log.error(&"items", "an item needs an id")
		return
	_items[item.id] = item


## Adds an origin of items: `source` is given an id the engine does not have
## and returns its `WgItem`, or null; `lister`, if given, returns the ids it
## has.
func add_source(source: Callable, lister := Callable()) -> void:
	_sources.append(source)
	if lister.is_valid():
		_listers.append(lister)


## Every item id known, none read: registered, the folder's, the sources'
## that list theirs.
func ids() -> Array[StringName]:
	var known: Array[StringName] = []
	known.assign(_items.keys())
	var folder := _paths.root(&"items")
	if not folder.is_empty() and DirAccess.dir_exists_absolute(folder):
		var files := DirAccess.get_files_at(folder)
		files.sort()
		for file in files:
			var name := file.trim_suffix(".remap")
			if name.ends_with(".tres") and StringName(name.get_basename()) not in known:
				known.append(StringName(name.get_basename()))
	for lister in _listers:
		var listed: Variant = lister.call()
		for id: Variant in listed if listed is Array else []:
			if StringName(str(id)) not in known:
				known.append(StringName(str(id)))
	return known


## The item of that id; null, logged once, if unknown.
func item(id: StringName) -> WgItem:
	var found := _find(id)
	if found == null and not _unknown.has(id):
		_unknown[id] = true
		log.error(&"items", "unknown item '%s'" % id)
	return found


func has(id: StringName) -> bool:
	return _find(id) != null


func _find(id: StringName) -> WgItem:
	if _items.has(id):
		return _items[id]
	var found := _from_folder(id)
	for source in _sources:
		if found != null:
			break
		found = source.call(id) as WgItem
	if found == null:
		return null
	if found.id.is_empty():
		found.id = id
	_items[id] = found
	return found


func _from_folder(id: StringName) -> WgItem:
	var path := _paths.resolve(&"items", "%s.tres" % id)
	if not ResourceLoader.exists(path):
		return null
	var found := load(path) as WgItem
	if found == null:
		log.error(&"items", "%s: not a WgItem" % path.get_file())
	return found


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
