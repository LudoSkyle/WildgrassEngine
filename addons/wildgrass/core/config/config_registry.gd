## Configurations by name: the defaults, then what sources give (a plugin
## reading another tool's files), then the project's own file in the
## `config` folder, `<file>.tres` (a resource edited in the inspector) or
## `<file>.json`, field by field.
extends RefCounted

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")

var _paths: Paths
var _log: Log
## name -> {"script": GDScript, "file": String}
var _entries: Dictionary[StringName, Dictionary] = {}
var _loaded: Dictionary[StringName, WgConfig] = {}
## name -> callables returning a dictionary of fields.
var _sources: Dictionary[StringName, Array] = {}


func _init(paths: Paths, logger: Log) -> void:
	_paths = paths
	_log = logger


## Registers a config. Registering an existing name replaces it, provided the
## new script extends the old one. Returns false if refused.
func register(config_name: StringName, script: GDScript, file: String) -> bool:
	if not _extends(script, WgConfig):
		_log.error(&"config", "%s: %s does not extend WgConfig" % [config_name, script.resource_path])
		return false
	if _entries.has(config_name) and not _extends(script, _entries[config_name]["script"]):
		_log.error(&"config", "%s: %s does not extend %s" % [config_name, script.resource_path, _entries[config_name]["script"].resource_path])
		return false
	_entries[config_name] = {"script": script, "file": file}
	_loaded.erase(config_name)
	return true


func is_registered(config_name: StringName) -> bool:
	return _entries.has(config_name)


## Path of the project's file of a registered config, its resource if there
## is one, else its JSON; "" for an unknown name.
func file_path(config_name: StringName) -> String:
	if not _entries.has(config_name):
		return ""
	var resource := _paths.resolve(&"config", "%s.tres" % _entries[config_name]["file"])
	if _paths.exists(resource):
		return resource
	return _paths.resolve(&"config", "%s.json" % _entries[config_name]["file"])


## True if the game provides a file for this config.
func has_file(config_name: StringName) -> bool:
	return _paths.exists(file_path(config_name))


## Adds a source of a config's fields: `source` returns a dictionary of them,
## applied over the defaults, before the project's own file. It is asked
## once, when the config is first read.
func add_source(config_name: StringName, source: Callable) -> void:
	_sources.get_or_add(config_name, []).append(source)
	_loaded.erase(config_name)


## The config, loaded on first access. Null for an unknown name.
func get_config(config_name: StringName) -> WgConfig:
	if _loaded.has(config_name):
		return _loaded[config_name]
	if not _entries.has(config_name):
		_log.error(&"config", "unknown config '%s'" % config_name)
		return null
	var script: GDScript = _entries[config_name]["script"]
	var config: WgConfig = script.new()
	for source: Callable in _sources.get(config_name, []):
		var given: Variant = source.call()
		if given is Dictionary:
			for problem in config.load_data(given, "%s (source)" % config_name):
				_log.warn(&"config", problem)
	var path := file_path(config_name)
	if path.ends_with(".tres"):
		var own := load(path) as WgConfig
		if own == null or not _extends(own.get_script(), script):
			var kind: String = str(script.get_global_name()) if not str(script.get_global_name()).is_empty() else script.resource_path.get_file()
			_log.error(&"config", "%s: not a %s, ignored" % [path.get_file(), kind])
		else:
			for problem in config.take_from(own, script.new()):
				_log.warn(&"config", problem)
	elif _paths.exists(path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:
			for problem in config.load_data(data, path.get_file()):
				_log.warn(&"config", problem)
		else:
			_log.error(&"config", "%s: not a JSON object, using defaults" % path.get_file())
	_loaded[config_name] = config
	return config


static func _extends(script: Script, base: Script) -> bool:
	var current := script
	while current != null:
		if current == base:
			return true
		current = current.get_base_script()
	return false
