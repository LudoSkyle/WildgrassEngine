## Studio's text files (`Data/Text/Dialogs/<file>.csv`), read as data in the
## current language: a line, a whole file, `{text:file:line}` in any text, and
## Studio's `[VAR …]` tokens.
extends RefCounted

const _Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const _Log := preload("res://addons/wildgrass/core/log/log.gd")
const _ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")

## The text files, inside the data folder.
const FOLDER := "Text/Dialogs/"

## What Studio writes in a cell not translated: `[~ 0]`, `[~ 1]`…
static var _untranslated := RegEx.create_from_string("^\\[~ ?\\d+\\]$")
static var _token := RegEx.create_from_string("\\[VAR (\\w+)(?:\\(([^)]*)\\))?\\]")

@warning_ignore("shadowed_global_identifier")
var log: _Log
## Gives the language read now; set by the Studio layer to the engine
## texts' `reading_language`.
var language_of := Callable()

var _paths: _Paths
var _config: _ConfigRegistry
## File -> `{"header": its language codes, "rows": its lines}`; empty if missing.
var _files: Dictionary[int, Dictionary] = {}
var _warned: Dictionary[String, bool] = {}


func _init(paths: _Paths, logger: _Log, config_registry: _ConfigRegistry) -> void:
	_paths = paths
	log = logger
	_config = config_registry


## Line `line` of file `file`, in the current language, else the fallback
## locale's, else the first cell with a text; `\nl` is a line break. Empty,
## logged once, if missing.
func line(file: int, at: int) -> String:
	return _line(file, at, true)


## Every line of file `file`, in the current language.
func file_lines(file: int) -> PackedStringArray:
	var data := _file(file, true)
	var lines := PackedStringArray()
	if data.is_empty():
		return lines
	for row: PackedStringArray in data["rows"]:
		lines.append(_pick(data["header"], row, _language()))
	return lines


## Every cell of a line, by its column's language code; {} if missing.
func cells(file: int, at: int) -> Dictionary:
	var data := _file(file, false)
	if data.is_empty() or at < 0 or at >= (data["rows"] as Array).size():
		return {}
	var found := {}
	var row: PackedStringArray = data["rows"][at]
	var header: PackedStringArray = data["header"]
	for index in mini(header.size(), row.size()):
		if not is_empty(row[index]):
			found[header[index]] = row[index].replace("\\nl", "\n")
	return found


## True if `{text:file:line}` has a cell of its own in language `code`, not
## the fallback's.
func text_given(argument: String, code: String) -> bool:
	var parts := argument.split(":")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return false
	var data := _file(parts[0].to_int(), false)
	var at := parts[1].to_int()
	if data.is_empty() or at < 0 or at >= (data["rows"] as Array).size():
		return false
	var row: PackedStringArray = data["rows"][at]
	var index := column(data["header"], code)
	return index >= 0 and index < row.size() and not is_empty(row[index])


## `{text:file:line}`: the placeholder texts gain.
func text_reference(argument: String) -> Variant:
	var parts := argument.split(":")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		_warn_once("bad Studio text reference {text:%s}" % argument)
		return "{text:%s}" % argument
	return line(parts[0].to_int(), parts[1].to_int())


## Studio's `[VAR NAME(000n, …)]` reads the value `name_n`, `[VAR NAME]`
## the value `name`, as placeholders; a token of digits alone (a format code)
## shows nothing.
func tokens(text: String) -> String:
	var result := ""
	var from := 0
	for found: RegExMatch in _token.search_all(text):
		var value_name := found.get_string(1).to_lower()
		var index := found.get_string(2).get_slice(",", 0).strip_edges()
		if index.is_valid_hex_number():
			value_name += "_%d" % index.hex_to_int()
		result += text.substr(from, found.get_start() - from) + ("" if value_name.is_valid_int() else "{%s}" % value_name)
		from = found.get_end()
	return result + text.substr(from)


## An empty cell, or one Studio left untranslated.
static func is_empty(cell: String) -> bool:
	return cell.is_empty() or _untranslated.search(cell) != null


func _line(file: int, at: int, report: bool) -> String:
	var data := _file(file, report)
	if data.is_empty():
		return ""
	var rows: Array = data["rows"]
	if at < 0 or at >= rows.size():
		if report:
			_warn_once("no line %d in Studio text file %d" % [at, file])
		return ""
	return _pick(data["header"], rows[at], _language())


func _file(file: int, report: bool) -> Dictionary:
	var path := _paths.resolve(&"data", FOLDER + "%d.csv" % file)
	if not _files.has(file):
		var data := {}
		var csv := FileAccess.open(path, FileAccess.READ) if FileAccess.file_exists(path) else null
		if csv != null:
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
	if report and _files[file].is_empty():
		_warn_once("no Studio text file %s" % path)
	return _files[file]


## The cell of `locale`, else of the fallback locale, else the first one with
## a text.
func _pick(header: PackedStringArray, row: PackedStringArray, locale: String) -> String:
	var fallback := str(ProjectSettings.get_setting("internationalization/locale/fallback", "en"))
	for code: String in [locale, fallback]:
		var index := column(header, code)
		if index >= 0 and index < row.size() and not is_empty(row[index]):
			return row[index].replace("\\nl", "\n")
	for cell in row:
		if not is_empty(cell):
			return cell.replace("\\nl", "\n")
	return ""


## The column of a Godot locale: mapped by the `studio` config's `columns`,
## or its own code, or its language alone (`fr_FR` -> `fr`).
func column(header: PackedStringArray, locale: String) -> int:
	var columns := (_config.get_config(&"studio") as WgStudioConfig).columns
	for code: String in [locale, locale.get_slice("_", 0)]:
		var index := header.find(columns.get(code, code).to_lower())
		if index >= 0:
			return index
	return -1


## The language read: the engine texts' (`label_in()` reading another), else
## the one shown.
func _language() -> String:
	return language_of.call() if language_of.is_valid() else TranslationServer.get_locale()


func _warn_once(message: String) -> void:
	if _warned.has(message):
		return
	_warned[message] = true
	log.warn(&"studio", message)
