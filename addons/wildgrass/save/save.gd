## Games kept in slots: the state of every part, written as JSON, read back.
extends RefCounted

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")
const ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")

## The engine's layout of a game file.
const FORMAT := 1

signal written(slot: int)
signal loaded(slot: int)
signal new_game_started(slot: int)
signal erased(slot: int)

@warning_ignore("shadowed_global_identifier")
var log: Log
## The slot of the game played; 0: none yet.
var slot := 0

var _paths: Paths
var _config: ConfigRegistry
var _hooks: Hooks
## Each {"name", "state", "restore", "reset", "check"}, in the order added.
var _parts: Array[Dictionary] = []
## Parts of the game played that no one added: written back as they were.
var _kept: Dictionary = {}


func _init(paths: Paths, logger: Log, config_registry: ConfigRegistry, hook_registry: Hooks) -> void:
	_paths = paths
	log = logger
	_config = config_registry
	_hooks = hook_registry


func config() -> WgSaveConfig:
	return _config.get_config(&"save") as WgSaveConfig


## Adds a part of the game: `state()` returns a dictionary JSON holds, `restore(state)`
## puts it back (it may be a coroutine), `reset()` is a new game; `check(state)`,
## if given, may refuse a load before anything is restored. False, logged, for
## a name already taken.
func add_part(part_name: StringName, state: Callable, restore: Callable, reset: Callable, check := Callable()) -> bool:
	if has_part(part_name):
		log.error(&"save", "a part '%s' is already added" % part_name)
		return false
	_parts.append({"name": part_name, "state": state, "restore": restore, "reset": reset, "check": check})
	return true


func has_part(part_name: StringName) -> bool:
	return _parts.any(func(part: Dictionary) -> bool: return part["name"] == part_name)


## The parts' names, in the order they are restored.
func part_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for part: Dictionary in _parts:
		names.append(part["name"])
	return names


## The file of a slot.
func path_of(game_slot: int) -> String:
	var settings := config()
	var file := settings.base_filename + ("" if settings.maximum_save == 1 else "-%d" % game_slot) + ".json"
	return _paths.resolve(&"saves", ("test_" if _paths.testing else "") + file)


## True if the slot holds a game, readable or not.
func has(game_slot: int) -> bool:
	return _valid(game_slot) and FileAccess.file_exists(path_of(game_slot))


## The slots to show: every one up to `maximumSave`; with no maximum, those
## up to the last used, then a new one.
func slots() -> Array[int]:
	var count := config().maximum_save
	if count == 0:
		count = 1
		for found in _used_numbers():
			count = maxi(count, found + 1)
	var shown: Array[int] = []
	for number in range(1, count + 1):
		shown.append(number)
	return shown


## The first slot holding no game, or 0 if every one is taken.
func first_empty() -> int:
	var number := 1
	while has(number):
		number += 1
	return number if _valid(number) else 0


## What a slot's card shows: `{}` for an empty slot, `{"damaged": true}` for
## a file that cannot be read.
func summary(game_slot: int) -> Dictionary:
	if not has(game_slot):
		return {}
	var game := _read(game_slot, false)
	if game.is_empty():
		return {"damaged": true}
	var shown: Variant = game.get("summary", {})
	return shown if shown is Dictionary else {}


## What the card of the game played would show, through the `save_summary`
## hook.
func summary_now(game_slot := slot) -> Variant:
	return _hooks.filter(&"save_summary", {}, [game_slot])


## Writes the game in `game_slot`, else in `slot`, else in the first empty
## one. False, logged, leaving the old file as it was, if it cannot.
func write(game_slot := 0) -> bool:
	var target := game_slot if game_slot > 0 else (slot if slot > 0 else first_empty())
	if not _valid(target):
		log.error(&"save", "no slot %d to write in (maximumSave %d)" % [target, config().maximum_save])
		return false
	var parts := _kept.duplicate(true)
	for part: Dictionary in _parts:
		var state: Variant = (part["state"] as Callable).call()
		var problem := _not_json(state) if state is Dictionary else "it is not a dictionary"
		if not problem.is_empty():
			log.error(&"save", "part '%s' cannot be written: %s" % [part["name"], problem])
			return false
		parts[str(part["name"])] = state
	var shown: Variant = summary_now(target)
	var unwritable := _not_json(shown) if shown is Dictionary else "it is not a dictionary"
	if not unwritable.is_empty():
		log.error(&"save", "the summary cannot be written: %s" % unwritable)
		return false
	var game := {
		"format": FORMAT,
		"game_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"saved_at": Time.get_datetime_string_from_system(),
		"summary": shown,
		"parts": parts,
	}
	if not _write_file(path_of(target), JSON.stringify(game, "\t", false)):
		return false
	slot = target
	written.emit(target)
	return true


## Plays the game of `game_slot`: reads it, upgrades it, restores every part.
## False, logged, restoring nothing, if it cannot.
func load_game(game_slot: int) -> bool:
	if not has(game_slot):
		log.error(&"save", "slot %d holds no game" % game_slot)
		return false
	var game := _read(game_slot, true)
	if game.is_empty():
		return false
	var parts: Variant = _hooks.filter(&"save_upgrade", game["parts"], [str(game.get("game_version", ""))])
	if not parts is Dictionary:
		log.error(&"save", "save_upgrade must return the parts")
		return false
	for part: Dictionary in _parts:
		var check: Callable = part["check"]
		var key := str(part["name"])
		if check.is_valid() and parts.has(key) and not check.call(parts[key]):
			return false
	_kept = {}
	for key: Variant in parts:
		if not has_part(StringName(str(key))):
			_kept[key] = parts[key]
	slot = game_slot
	for part: Dictionary in _parts:
		var key := str(part["name"])
		if parts.has(key) and parts[key] is Dictionary:
			await (part["restore"] as Callable).call(parts[key])
		else:
			(part["reset"] as Callable).call()
	_hooks.run(&"game_loaded", [game_slot])
	loaded.emit(game_slot)
	return true


## Empties every part for a new game in `game_slot`, else the first empty
## slot, writing nothing.
func new_game(game_slot := 0) -> void:
	_kept = {}
	for part: Dictionary in _parts:
		(part["reset"] as Callable).call()
	slot = game_slot if game_slot > 0 else first_empty()
	_hooks.run(&"new_game", [slot])
	new_game_started.emit(slot)


## Removes the game of a slot. The game played keeps its slot.
func erase(game_slot: int) -> bool:
	if not has(game_slot):
		return false
	var error := DirAccess.remove_absolute(path_of(game_slot))
	if error != OK:
		log.error(&"save", "cannot erase slot %d: %s" % [game_slot, error_string(error)])
		return false
	erased.emit(game_slot)
	return true


func _valid(game_slot: int) -> bool:
	var count := config().maximum_save
	return game_slot >= 1 and (count == 0 or game_slot <= count)


## Slot numbers of the files in the saves folder, with no maximum.
func _used_numbers() -> Array[int]:
	var numbers: Array[int] = []
	var first := path_of(1)
	var prefix := first.get_file().trim_suffix("1.json")
	for file in DirAccess.get_files_at(first.get_base_dir()):
		if file.begins_with(prefix) and file.ends_with(".json"):
			var number := file.trim_prefix(prefix).trim_suffix(".json")
			if number.is_valid_int() and int(number) >= 1:
				numbers.append(int(number))
	return numbers


## The game of a slot, or {} if it cannot be read (logged when `report`).
func _read(game_slot: int, report: bool) -> Dictionary:
	var path := path_of(game_slot)
	var parser := JSON.new()
	var game: Variant = parser.data if parser.parse(FileAccess.get_file_as_string(path)) == OK else null
	var problem := ""
	if not game is Dictionary or not game.get("parts") is Dictionary or not (game.get("format") is float or game.get("format") is int):
		problem = "not a saved game"
	elif int(game["format"]) > FORMAT:
		problem = "written by a newer engine (format %d, this one reads %d)" % [int(game["format"]), FORMAT]
	if problem.is_empty():
		return game
	if report:
		log.error(&"save", "%s: %s" % [path.get_file(), problem])
	return {}


## Writes `text` beside the file, then puts it in its place.
func _write_file(path: String, text: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		log.error(&"save", "cannot write %s: %s" % [temporary, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(text)
	file.close()
	var error := DirAccess.rename_absolute(temporary, path)
	if error != OK:
		log.error(&"save", "cannot replace %s: %s" % [path, error_string(error)])
		DirAccess.remove_absolute(temporary)
		return false
	return true


## Why JSON cannot hold `value` as it is, or "".
static func _not_json(value: Variant, at := "") -> String:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return ""
		TYPE_ARRAY:
			for index in (value as Array).size():
				var problem := _not_json(value[index], "%s[%d]" % [at, index])
				if not problem.is_empty():
					return problem
			return ""
		TYPE_DICTIONARY:
			for key: Variant in value:
				if not key is String:
					return "%s has a key that is not a text: %s" % [at if not at.is_empty() else "it", key]
				var problem := _not_json(value[key], "%s.%s" % [at, key])
				if not problem.is_empty():
					return problem
			return ""
	return "%s is a %s" % [at if not at.is_empty() else "it", type_string(typeof(value))]
