## The words of Studio's events (feature 10 quater): a message or a choice
## that names a line of Studio's dialog files becomes a key, its words in
## each language written into a translation file; Studio's codes in them
## become the engine's tags and placeholders, read in the order Studio reads
## them. What the engine cannot show yet is counted, never kept as code.
extends RefCounted

const _StudioTexts := preload("res://addons/wildgrass/studio/studio_texts.gd")

## Studio's money sign, after a space that must not break.
const MONEY := " $"
## The flag Studio reads as the player's gender (switch 1: a girl).
const GIRL := "switch_1"
## Studio's names of the keys, as Godot's input actions.
const KEYS: Dictionary[String, String] = {
	"a": "ui_accept", "b": "ui_cancel", "x": "ui_focus_next", "y": "ui_focus_prev",
	"up": "ui_up", "down": "ui_down", "left": "ui_left", "right": "ui_right", "start": "ui_menu", "select": "ui_select",
}

## The Studio project's `Data` folder.
var data_folder := ""
## What could not be shown yet, by what it is: "message: money window".
var counts: Dictionary[String, int] = {}
## The text variables scripts set (`[POKE]`): placeholders, `{poke}`.
var text_variables: Array[String] = []
## The words written so far: key -> {language: text}.
var translations: Dictionary[String, Dictionary] = {}

var _files: Dictionary[int, Dictionary] = {}
var _counting := true
var _colors: Image
var _languages: Array[String] = []
var _ref := RegEx.create_from_string("^([0-9]+),( |)([0-9]+)")
var _whole_text := RegEx.create_from_string("^\\\\t\\[([0-9]+), *([0-9]+)\\]$")
var _properties_pattern := RegEx.create_from_string(":\\[([^\\]]+)\\]:")
var _markers_pattern := RegEx.create_from_string("(?i)\\\\c\\[([0-9]+)\\]|\\[WAIT ([0-9]+)\\]|\\\\s\\[([bir]+)\\]|\\\\\\^|\\\\spd\\[([0-9]+)\\]|\\\\img\\[([^\\]]+)\\]|\\\\d\\[[^\\]]*\\]")


func _init(data: String) -> void:
	data_folder = data


## The languages Studio's dialog files give that Godot knows, in their order.
func languages() -> Array[String]:
	if not _languages.is_empty():
		return _languages
	var folder := data_folder.path_join("Text/Dialogs")
	for file in DirAccess.get_files_at(folder) if DirAccess.dir_exists_absolute(folder) else PackedStringArray():
		if not file.ends_with(".csv") or not file.get_basename().is_valid_int():
			continue
		for code: String in _file(file.get_basename().to_int()).get("header", PackedStringArray()):
			if not code in _languages and TranslationServer.get_all_languages().has(code):
				_languages.append(code)
		if not _languages.is_empty():
			break
	return _languages


## What a message or a choice of an event says: a key when it names a line
## of Studio's files (its words written for each language), else its words.
func text_of(raw: String) -> String:
	var found := _ref.search(raw)
	if found != null:
		return _key(found.get_string(1).to_int(), found.get_string(3).to_int())
	found = _whole_text.search(raw.strip_edges())
	if found != null:
		return _key(100000 + found.get_string(1).to_int(), found.get_string(2).to_int())
	return convert_text(raw, _default_language())


## Studio's `text`, in `language`, as the engine shows it.
func convert_text(text: String, language: String) -> String:
	text = text.replace("\\\\", "\u0001")
	text = _sub(text, "(?i)\\\\v\\[([0-9]+)\\]", func(m: RegExMatch) -> String: return "{value:variable_%s}" % m.get_string(1))
	text = _sub(text, "(?i)\\\\n\\[([0-9]+)\\]", _actor_name)
	text = _sub(text, "(?i)\\\\p\\[([0-9]+)\\]", func(m: RegExMatch) -> String: return _count("message: a party Pokémon's name", "{party_%s}" % m.get_string(1)))
	text = _sub(text, "(?i)\\\\k\\[([^\\]]+)\\]", func(m: RegExMatch) -> String: return "{key:%s}" % KEYS.get(m.get_string(1).to_lower(), "ui_accept"))
	text = text.replace("\\E", "{flag:%s?e|}" % GIRL)
	text = _sub(text, "(?i)\\\\f\\[([^\\]]+)\\]", _gendered)
	text = _sub(text, "(?i)\\\\t\\[([0-9]+), *([0-9]+)\\]", func(m: RegExMatch) -> String: return line(100000 + m.get_string(1).to_int(), m.get_string(2).to_int(), language))
	text = text.replace("...", "…").replace(" $", MONEY)
	for token in text_variables:
		text = text.replace(token, "{%s}" % token.trim_prefix("[").trim_suffix("]").to_lower())
	text = _sub(text, "\\[VAR (\\w+)(?:\\(([^)]*)\\))?\\]", _var)
	if text.contains("\\G") or text.contains("\\g"):
		_count("message: money window", "")
		text = text.replace("\\G", "").replace("\\g", "")
	var tags := ""
	for found: RegExMatch in _properties_pattern.search_all(text):
		tags += _properties(found.get_string(1))
	text = _properties_pattern.sub(text, "", true)
	return tags + _markers(text).replace("\u0001", "\\")


## The words of line `at` of Studio's file `file` in `language`, Studio's
## codes left in: the cell, else the fallback language's, else the first.
func line(file: int, at: int, language: String) -> String:
	var data := _file(file)
	var rows: Array = data.get("rows", [])
	if at < 0 or at >= rows.size():
		_count("message: no line %d in Studio's file %d" % [at, file], "")
		return ""
	var header: PackedStringArray = data["header"]
	var row: PackedStringArray = rows[at]
	var fallback := str(ProjectSettings.get_setting("internationalization/locale/fallback", "en"))
	for code: String in [language, fallback]:
		var index := header.find(code)
		if index >= 0 and index < row.size() and not _StudioTexts.is_empty(row[index]):
			return row[index].replace("\\nl", "\n")
	for cell in row:
		if not _StudioTexts.is_empty(cell):
			return cell.replace("\\nl", "\n")
	return ""


## Writes the words of every key into `path`, a translation file Godot reads
## (`keys`, then a column per language), and sets its import to take the
## words as written: Godot would read `\v` in Studio's own words as a code.
## Returns false if it cannot.
func write_translations(path: String) -> bool:
	var codes := languages()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	var header := PackedStringArray(["keys"])
	header.append_array(PackedStringArray(codes))
	file.store_csv_line(header)
	var keys := translations.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	for key: String in keys:
		var row := PackedStringArray([key])
		for code in codes:
			row.append(str(translations[key].get(code, "")))
		file.store_csv_line(row)
	file.close()
	return _keep_words_as_written(path + ".import")


## The import settings of the translation file at `import_path`: its words
## not unescaped. An existing file keeps its other settings.
static func _keep_words_as_written(import_path: String) -> bool:
	var settings := ConfigFile.new()
	if FileAccess.file_exists(import_path):
		settings.load(import_path)
	else:
		settings.set_value("remap", "importer", "csv_translation")
		settings.set_value("remap", "type", "Translation")
	settings.set_value("params", "unescape_keys", false)
	settings.set_value("params", "unescape_translations", false)
	return settings.save(import_path) == OK


func _key(file: int, at: int) -> String:
	var key := "dialogs.%d.%d" % [file, at]
	if not translations.has(key):
		var words := {}
		for code in languages():
			# What cannot be shown is counted once, in the first language.
			_counting = code == languages()[0]
			words[code] = convert_text(line(file, at, code), code)
		_counting = true
		translations[key] = words
	return key


func _default_language() -> String:
	var codes := languages()
	return codes[0] if not codes.is_empty() else "en"


## `\N[1]`, the player's name; another actor's is counted.
func _actor_name(found: RegExMatch) -> String:
	if found.get_string(1) == "1":
		return "{player}"
	return _count("message: an actor's name", "{actor_%s}" % found.get_string(1))


## `\f[girl§boy]`: the form for the player's gender.
func _gendered(found: RegExMatch) -> String:
	var forms := found.get_string(1).split("§")
	return "{flag:%s?%s|%s}" % [GIRL, forms[0], forms[1] if forms.size() > 1 else ""]


## Studio's `[VAR NAME(000n)]`: the value `name_n`, as the Studio layer reads it.
func _var(found: RegExMatch) -> String:
	var value_name := found.get_string(1).to_lower()
	var index := found.get_string(2).get_slice(",", 0).strip_edges()
	if index.is_valid_hex_number():
		value_name += "_%d" % index.hex_to_int()
	return "" if value_name.is_valid_int() else "{%s}" % value_name


## The properties of `:[name=…;align=…]:` as the engine's tags.
func _properties(properties: String) -> String:
	var tags := ""
	for property in properties.split(";"):
		var key := property.get_slice("=", 0)
		var value := property.substr(key.length() + 1)
		match key:
			"name":
				var parts := value.split(",")
				tags += "[speaker=%s]" % _escaped(parts[0])
				if parts.size() > 1 and parts[1].is_valid_int():
					tags += "[speaker_color=#%s]" % _color(parts[1].to_int()).to_html(false)
			"align":
				tags += "[align=%s]" % value
			"lookto":
				tags += "[look_to=%s]" % value
			_:
				_count("message: %s" % key, "")
	return tags


## Studio's markers as the engine's tags; the rest escaped.
func _markers(text: String) -> String:
	var result := ""
	var from := 0
	var colored := false
	var styles: Array[String] = []
	for found: RegExMatch in _markers_pattern.search_all(text):
		result += _escaped(text.substr(from, found.get_start() - from))
		from = found.get_end()
		if not found.get_string(1).is_empty():
			if colored:
				result += "[/color]"
			colored = found.get_string(1).to_int() != 0
			if colored:
				result += "[color=#%s]" % _color(found.get_string(1).to_int()).to_html(false)
		elif not found.get_string(2).is_empty():
			result += "[pause=%s]" % String.num(found.get_string(2).to_int() / 60.0, 3)
		elif not found.get_string(3).is_empty():
			while not styles.is_empty():
				result += "[/%s]" % styles.pop_back()
			var style := found.get_string(3).to_lower()
			if not "r" in style:
				for tag: String in ["b", "i"]:
					if tag in style:
						result += "[%s]" % tag
						styles.append(tag)
		elif found.get_string() == "\\^":
			_count("message: big text", "")
		elif not found.get_string(4).is_empty():
			_count("message: writing speed", "")
		elif not found.get_string(5).is_empty():
			_count("message: picture", "")
		else:
			_count("message: a day-care Pokémon's name", "")
	result += _escaped(text.substr(from))
	while not styles.is_empty():
		result += "[/%s]" % styles.pop_back()
	if colored:
		result += "[/color]"
	return result


## Studio's text colour `index`: the fill row of its colour picture.
func _color(index: int) -> Color:
	if _colors == null:
		var path := data_folder.path_join("../graphics/windowskins/_colors.png").simplify_path()
		_colors = Image.load_from_file(path) if FileAccess.file_exists(path) else null
		if _colors == null:
			_colors = Image.create(1, 3, false, Image.FORMAT_RGBA8)
			_colors.fill(Color.WHITE)
	return _colors.get_pixel(clampi(index, 0, _colors.get_width() - 1), 1)


## `[` written as text, never read as a tag.
static func _escaped(text: String) -> String:
	return text.replace("[", "[lb]")


func _count(what: String, shown: String) -> String:
	if _counting:
		counts[what] = counts.get(what, 0) + 1
	return shown


static func _sub(text: String, pattern: String, fill: Callable) -> String:
	var found := RegEx.create_from_string(pattern)
	var result := ""
	var from := 0
	for each: RegExMatch in found.search_all(text):
		result += text.substr(from, each.get_start() - from) + str(fill.call(each))
		from = each.get_end()
	return result + text.substr(from)


func _file(file: int) -> Dictionary:
	if not _files.has(file):
		var data := {}
		var path := data_folder.path_join("Text/Dialogs/%d.csv" % file)
		var handle := FileAccess.open(path, FileAccess.READ) if FileAccess.file_exists(path) else null
		if handle != null:
			var header := handle.get_csv_line()
			for index in header.size():
				header[index] = header[index].strip_edges().to_lower()
			var rows: Array = []
			while not handle.eof_reached():
				var row := handle.get_csv_line()
				if row.size() > 1 or (row.size() == 1 and not row[0].is_empty()):
					rows.append(row)
			data = {"header": header, "rows": rows}
		_files[file] = data
	return _files[file]
