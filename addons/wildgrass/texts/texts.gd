## The language of the game, and the texts it shows: Studio's text files are
## read here, as data, and placeholders filled.
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
var _values: Dictionary[StringName, Variant] = {}

## What Studio writes in a cell not translated: `[~ 0]`, `[~ 1]`…
static var _untranslated := RegEx.create_from_string("^\\[~ ?\\d+\\]$")

static var _placeholder: RegEx
static var _token: RegEx
static var _studio: RegEx


func _init(paths: Paths, logger: Log, config_registry: ConfigRegistry, hook_registry: Hooks) -> void:
	_paths = paths
	log = logger
	_config = config_registry
	_hooks = hook_registry


## Sets the default language of the config, if it has one.
func apply_default() -> void:
	var code := config().default
	if not code.is_empty():
		language = code


## The languages the player may choose, in order.
func languages() -> Array[String]:
	var codes := config().choosable
	if not codes.is_empty():
		return codes.duplicate()
	var loaded: Array[String] = []
	loaded.assign(TranslationServer.get_loaded_locales())
	return loaded


## The name of a language, written in that language if the config gives it,
## else Godot's.
func language_name(code: String) -> String:
	var settings := config()
	var index := settings.choosable.find(code)
	if index >= 0 and index < settings.names.size() and not settings.names[index].is_empty():
		return settings.names[index]
	return TranslationServer.get_locale_name(code)


## Line `line` of Studio's text file `file`, in the current language: its
## column, else the fallback locale's, else the first. "" if missing, logged
## once.
func studio(file: int, line: int) -> String:
	return _studio_text(file, line, true)


func _studio_text(file: int, line: int, report: bool) -> String:
	var data := _studio_file(file, report)
	if data.is_empty():
		return ""
	var rows: Array = data["rows"]
	if line < 0 or line >= rows.size():
		if report:
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


## Sets the value of `{name}`: anything shown as text, or a Callable called
## each time it is shown. `null` removes it.
func set_value(value_name: StringName, value: Variant) -> void:
	if value == null:
		_values.erase(value_name)
	else:
		_values[value_name] = value


## The value of `{name}`: the one set, then the `text_value` filter hook.
## `null` if there is none.
func value(value_name: StringName) -> Variant:
	var found: Variant = _values.get(value_name)
	if found is Callable:
		found = (found as Callable).call()
	return _hooks.filter(&"text_value", found, [value_name])


## `text` with its placeholders filled: `{name}`, `{name?yes|no}`,
## `{key:action}`, `{text:file:line}`, and Studio's `[VAR …]` tokens. With
## `escape`, what values put in is escaped for messages: it never reads as a
## tag. `values` come first: one text's own.
func format(text: String, escape := false, values := {}) -> String:
	if _placeholder == null:
		_placeholder = RegEx.create_from_string("\\{(\\w+)(?::([^{}?|]*))?(?:\\?([^{}|]*)\\|([^{}]*))?\\}")
		_token = RegEx.create_from_string("\\[VAR (\\w+)(?:\\(([^)]*)\\))?\\]")
	if _studio == null:
		_studio = RegEx.create_from_string("\\{text:([^{}|]*)(?:\\|([^{}]*))?\\}")
	var result := _replace(_studio, text, _studio_reference)
	result = _replace(_token, result, _fill_token.bind(escape, values))
	return _replace(_placeholder, result, _fill_placeholder.bind(escape, values))


func config() -> WgLanguageConfig:
	return _config.get_config(&"language") as WgLanguageConfig


func _studio_file(file: int, report := true) -> Dictionary:
	if _files.has(file):
		if report and _files[file].is_empty():
			_warn_once("no Studio text file %s" % _paths.resolve(&"data", STUDIO_FOLDER + "%d.csv" % file))
		return _files[file]
	var path := _paths.resolve(&"data", STUDIO_FOLDER + "%d.csv" % file)
	var data := {}
	var csv := FileAccess.open(path, FileAccess.READ) if FileAccess.file_exists(path) else null
	if csv == null:
		if report:
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
## first one with a text; `\nl` is a line break.
func _pick(header: PackedStringArray, row: PackedStringArray) -> String:
	var fallback := str(ProjectSettings.get_setting("internationalization/locale/fallback", "en"))
	for locale: String in [language, fallback]:
		var index := _column(header, locale)
		if index >= 0 and index < row.size() and not _is_empty(row[index]):
			return row[index].replace("\\nl", "\n")
	for cell in row:
		if not _is_empty(cell):
			return cell.replace("\\nl", "\n")
	return ""


## The column of a Godot locale: mapped by `studioColumns`, or its own code,
## or its language alone (`fr_FR` -> `fr`).
func _column(header: PackedStringArray, locale: String) -> int:
	var columns := config().studio_columns
	for code: String in [locale, locale.get_slice("_", 0)]:
		var index := header.find(columns.get(code, code).to_lower())
		if index >= 0:
			return index
	return -1


## An empty cell, or one Studio left untranslated.
static func _is_empty(cell: String) -> bool:
	return cell.is_empty() or _untranslated.search(cell) != null


func _warn_once(message: String) -> void:
	if _warned.has(message):
		return
	_warned[message] = true
	log.warn(&"texts", message)


static func _replace(pattern: RegEx, text: String, fill: Callable) -> String:
	var result := ""
	var from := 0
	for found: RegExMatch in pattern.search_all(text):
		result += text.substr(from, found.get_start() - from) + str(fill.call(found))
		from = found.get_end()
	return result + text.substr(from)


## `{text:file:line}`, or `{text:file:line|fallback}`: the fallback, through
## `tr()`, when the file or the line is missing or the cell empty, unlogged.
func _studio_reference(found: RegExMatch) -> String:
	var parts := found.get_string(1).split(":")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		_warn_once("bad Studio text reference %s" % found.get_string())
		return found.get_string()
	if found.get_start(2) < 0:
		return studio(parts[0].to_int(), parts[1].to_int())
	var shown := _studio_text(parts[0].to_int(), parts[1].to_int(), false)
	return shown if not shown.is_empty() else TranslationServer.translate(found.get_string(2))


func _fill_placeholder(found: RegExMatch, escape: bool, values: Dictionary) -> String:
	var value_name := found.get_string(1)
	var argument := found.get_string(2)
	var shown: Variant = null
	if value_name == "text" and not argument.is_empty():
		return found.get_string()
	if value_name == "key" and not argument.is_empty():
		shown = _key_name(argument)
	elif argument.is_empty():
		shown = values[value_name] if values.has(value_name) else value(StringName(value_name))
	if shown == null:
		_warn_once("no value for %s" % found.get_string())
		return found.get_string()
	if found.get_start(3) >= 0:
		return found.get_string(3) if _is_true(shown) else found.get_string(4)
	return _escaped(str(shown), escape)


## `[VAR NAME(000n, …)]` is the value `name_n`; `[VAR NAME]`, `name`.
func _fill_token(found: RegExMatch, escape: bool, values: Dictionary) -> String:
	var value_name := found.get_string(1).to_lower()
	var index := found.get_string(2).get_slice(",", 0).strip_edges()
	if index.is_valid_hex_number():
		value_name += "_%d" % index.hex_to_int()
	var shown: Variant = values[value_name] if values.has(value_name) else value(StringName(value_name))
	if shown == null:
		_warn_once("no value for Studio token %s" % found.get_string())
		return ""
	return _escaped(str(shown), escape)


## The key bound to `action`, else its first input, through the `key_name`
## filter hook. `null` for an unknown action.
func _key_name(action: String) -> Variant:
	if not InputMap.has_action(action):
		return null
	var events := InputMap.action_get_events(action)
	var shown := ""
	for event: InputEvent in events:
		var key := event as InputEventKey
		if key != null:
			var code := key.keycode if key.keycode != KEY_NONE else DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode)
			shown = OS.get_keycode_string(code)
			break
	if shown.is_empty() and not events.is_empty():
		shown = events[0].as_text()
	return _hooks.filter(&"key_name", shown, [action])


static func _is_true(shown: Variant) -> bool:
	match typeof(shown):
		TYPE_BOOL:
			return shown
		TYPE_INT, TYPE_FLOAT:
			return shown != 0
		TYPE_STRING, TYPE_STRING_NAME:
			return not str(shown).is_empty()
	return true


static func _escaped(shown: String, escape: bool) -> String:
	return shown.replace("[", "[lb]") if escape else shown
