## The language of the game, and the texts it shows: Studio's text files are
## read here, as data.
extends RefCounted

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")
const ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")

## The language changed.
signal language_changed(code: String)

## Studio's text files, `<file>.csv`, inside the data folder.
const STUDIO_FOLDER := "Text/Dialogs/"

@warning_ignore("shadowed_global_identifier")
var log: Log
## The current language: Godot's locale.
var language: String:
	get:
		return TranslationServer.get_locale()
	set(code):
		if code == TranslationServer.get_locale():
			return
		TranslationServer.set_locale(code)
		language_changed.emit(TranslationServer.get_locale())

var _paths: Paths
var _config: ConfigRegistry
var _hooks: Hooks
## File -> `{"header": its language codes, "rows": its lines}`; empty if missing.
var _files: Dictionary[int, Dictionary] = {}
var _warned: Dictionary[String, bool] = {}


func _init(paths: Paths, logger: Log, config_registry: ConfigRegistry, hook_registry: Hooks) -> void:
	_paths = paths
	log = logger
	_config = config_registry
	_hooks = hook_registry


## Sets the default language of the config, if it has one.
func apply_default() -> void:
	var code := config().default_language
	if not code.is_empty():
		language = code


## The languages the player may choose, in order.
func languages() -> Array[String]:
	var codes := config().choosable_language_code
	if not codes.is_empty():
		return codes.duplicate()
	var loaded: Array[String] = []
	loaded.assign(TranslationServer.get_loaded_locales())
	return loaded


## The name of a language, written in that language if the config gives it,
## else Godot's.
func language_name(code: String) -> String:
	var settings := config()
	var index := settings.choosable_language_code.find(code)
	if index >= 0 and index < settings.choosable_language_texts.size() and not settings.choosable_language_texts[index].is_empty():
		return settings.choosable_language_texts[index]
	return TranslationServer.get_locale_name(code)


## Line `line` of Studio's text file `file`, in the current language: its
## column, else the fallback locale's, else the first. "" if missing, logged
## once.
func studio(file: int, line: int) -> String:
	var data := _studio_file(file)
	if data.is_empty():
		return ""
	var rows: Array = data["rows"]
	if line < 0 or line >= rows.size():
		_warn_once("no line %d in Studio text file %d" % [line, file])
		return ""
	return _pick(data["header"], rows[line])


## Every line of Studio's text file `file`, in the current language.
func studio_file(file: int) -> PackedStringArray:
	var data := _studio_file(file)
	var lines := PackedStringArray()
	if data.is_empty():
		return lines
	for row: PackedStringArray in data["rows"]:
		lines.append(_pick(data["header"], row))
	return lines


func config() -> WgLanguageConfig:
	return _config.get_config(&"language") as WgLanguageConfig


func _studio_file(file: int) -> Dictionary:
	if _files.has(file):
		return _files[file]
	var path := _paths.resolve(&"data", STUDIO_FOLDER + "%d.csv" % file)
	var data := {}
	var csv := FileAccess.open(path, FileAccess.READ) if FileAccess.file_exists(path) else null
	if csv == null:
		_warn_once("no Studio text file %s" % path)
	else:
		var header := PackedStringArray()
		for code: String in csv.get_csv_line():
			header.append(code.strip_edges().to_lower())
		var rows: Array[PackedStringArray] = []
		while not csv.eof_reached():
			var row := csv.get_csv_line()
			if csv.eof_reached() and row.size() <= 1 and (row.is_empty() or row[0].is_empty()):
				break
			rows.append(row)
		data = {"header": header, "rows": rows}
	_files[file] = data
	return data


## The cell of the current language, else of the fallback locale, else the
## first one; `\nl` is a line break.
func _pick(header: PackedStringArray, row: PackedStringArray) -> String:
	var fallback := str(ProjectSettings.get_setting("internationalization/locale/fallback", "en"))
	for locale: String in [language, fallback]:
		var index := _column(header, locale)
		if index >= 0 and index < row.size() and not row[index].is_empty():
			return row[index].replace("\\nl", "\n")
	return row[0].replace("\\nl", "\n") if not row.is_empty() else ""


## The column of a Godot locale: mapped by `studioColumns`, or its own code,
## or its language alone (`fr_FR` -> `fr`).
func _column(header: PackedStringArray, locale: String) -> int:
	var columns := config().studio_columns
	for code: String in [locale, locale.get_slice("_", 0)]:
		var index := header.find(columns.get(code, code).to_lower())
		if index >= 0:
			return index
	return -1


func _warn_once(message: String) -> void:
	if _warned.has(message):
		return
	_warned[message] = true
	log.warn(&"texts", message)
