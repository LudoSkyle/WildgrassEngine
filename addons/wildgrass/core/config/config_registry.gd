## Configurations by name, each read from `Data/configs/<file>.json`.
extends RefCounted

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")

var _paths: Paths
var _log: Log
## name -> {"script": GDScript, "file": String}
var _entries: Dictionary[StringName, Dictionary] = {}
var _loaded: Dictionary[StringName, WgConfig] = {}


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


## Path of the JSON file of a registered config, or "".
func file_path(config_name: StringName) -> String:
	if not _entries.has(config_name):
		return ""
	return _paths.resolve(&"data", "configs/%s.json" % _entries[config_name]["file"])


## True if the game provides the file of this config.
func has_file(config_name: StringName) -> bool:
	return _paths.exists(file_path(config_name))


## The config, loaded on first access. Null for an unknown name.
func get_config(config_name: StringName) -> WgConfig:
	if _loaded.has(config_name):
		return _loaded[config_name]
	if not _entries.has(config_name):
		_log.error(&"config", "unknown config '%s'" % config_name)
		return null
	var config: WgConfig = _entries[config_name]["script"].new()
	var path := file_path(config_name)
	if _paths.exists(path):
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
