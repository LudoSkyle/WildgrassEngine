## Resources by id: those registered, then the folder's (`<id>.tres`), then
## what sources give, each read the first time it is asked for. Species and
## types keep theirs in one.
extends RefCounted

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")

var _paths: Paths
var _log: Log
## The paths kind of the folder.
var _kind: StringName
var _script: GDScript
var _channel: StringName
## What one is called in the log: `species`, `type`.
var _what: String
var _found: Dictionary[StringName, Resource] = {}
var _unknown: Dictionary[StringName, bool] = {}
## Each {"read", "ids"}.
var _sources: Array[Dictionary] = []


func _init(paths: Paths, logger: Log, kind: StringName, script: GDScript, channel: StringName, what: String) -> void:
	_paths = paths
	_log = logger
	_kind = kind
	_script = script
	_channel = channel
	_what = what


func register(resource: Resource, id: StringName) -> void:
	if id.is_empty():
		_log.error(_channel, "a %s needs an id" % _what)
		return
	_found[id] = resource


func add_source(read: Callable, ids: Callable) -> void:
	_sources.append({"read": read, "ids": ids})


## The resource of that id; null if unknown, logged once when `report`.
func find(id: StringName, report := true) -> Resource:
	if _found.has(id):
		return _found[id]
	var found := _from_folder(id)
	for source: Dictionary in _sources:
		if found != null:
			break
		var given: Variant = (source["read"] as Callable).call(id)
		found = given as Resource if _is_ours(given) else null
	if found == null:
		if report and not _unknown.has(id):
			_unknown[id] = true
			_log.error(_channel, "unknown %s '%s'" % [_what, id])
		return null
	if StringName(found.get(&"id")).is_empty():
		found.set(&"id", id)
	_found[id] = found
	return found


## Every id known, none read: registered, the folder's, the sources'.
func ids() -> Array[StringName]:
	var known: Array[StringName] = []
	known.assign(_found.keys())
	var folder := _paths.root(_kind)
	if not folder.is_empty() and DirAccess.dir_exists_absolute(folder):
		var files := DirAccess.get_files_at(folder)
		files.sort()
		for file in files:
			var id := StringName(file.trim_suffix(".remap").trim_suffix(".tres")) if file.trim_suffix(".remap").ends_with(".tres") else &""
			if not id.is_empty() and id not in known:
				known.append(id)
	for source: Dictionary in _sources:
		var listed: Variant = (source["ids"] as Callable).call() if (source["ids"] as Callable).is_valid() else []
		for id: Variant in listed:
			if StringName(str(id)) not in known:
				known.append(StringName(str(id)))
	return known


## Every resource known, read.
func all() -> Array[Resource]:
	var found: Array[Resource] = []
	for id in ids():
		var resource := find(id, false)
		if resource != null:
			found.append(resource)
	return found


func _from_folder(id: StringName) -> Resource:
	var path := _paths.resolve(_kind, "%s.tres" % id)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var loaded := load(path)
	if not _is_ours(loaded):
		_log.error(_channel, "%s: not a %s" % [path.get_file(), _script.get_global_name()])
		return null
	return loaded


func _is_ours(value: Variant) -> bool:
	return value is Resource and is_instance_of(value, _script)
