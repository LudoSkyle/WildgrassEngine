## Where the engine finds the game's files, and where it writes the player's.
extends RefCounted

## Emitted the first time a missing asset is reported.
signal asset_missing(path: String, requester: String)

const SETTING_PREFIX := "wildgrass/paths/"
## `data` and `studio` are the Studio layer's: a Studio project's data
## folder and its root.
const DEFAULTS: Dictionary[StringName, String] = {
	&"data": "res://Data/",
	&"graphics": "res://graphics/",
	&"audio": "res://audio/",
	&"maps": "res://maps/",
	&"saves": "user://",
	&"config": "res://config/",
	&"items": "res://items/",
	&"quests": "res://quests/",
	&"pokemon": "res://pokemon/",
	&"types": "res://types/",
	&"dex": "res://dex/",
	&"encounters": "res://encounters/",
	&"weather": "res://weather/",
	&"zones": "res://zones/",
	&"common_events": "res://common_events/",
	&"studio": "res://",
}

## True when the game was launched with `-- --test`: player files are redirected.
var testing: bool

var _reported: Dictionary[String, bool] = {}


func _init(testing_mode: Variant = null) -> void:
	testing = OS.get_cmdline_user_args().has("--test") if testing_mode == null else bool(testing_mode)


## Folder of a kind of file (`data`, `graphics`, `audio`, or any kind set in the
## project settings), ending with "/". Empty for an unknown kind.
func root(kind: StringName) -> String:
	var folder := str(ProjectSettings.get_setting(SETTING_PREFIX + kind, DEFAULTS.get(kind, "")))
	if folder.is_empty():
		return ""
	return folder if folder.ends_with("/") else folder + "/"


## Full path of `relative` inside the folder of `kind`. Empty for an unknown kind.
func resolve(kind: StringName, relative: String) -> String:
	var folder := root(kind)
	if folder.is_empty():
		return ""
	return folder + relative.trim_prefix("/")


## True if the file exists, as an imported resource or as a plain file.
func exists(path: String) -> bool:
	return not path.is_empty() and (ResourceLoader.exists(path) or FileAccess.file_exists(path))


## Reports a missing asset once per path. Returns true the first time.
func report_missing(path: String, requester: String) -> bool:
	if _reported.has(path):
		return false
	_reported[path] = true
	asset_missing.emit(path, requester)
	return true


## Path of a file written on the player's machine (settings, saves).
func user_file(file_name: String) -> String:
	return "user://" + ("test_" if testing else "") + file_name
