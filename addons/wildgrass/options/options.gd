## The player's options: what can be set, each applied as it changes and kept
## on the player's machine, apart from any saved game.
extends RefCounted

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")
const ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const Dialogue := preload("res://addons/wildgrass/dialogue/dialogue.gd")
const Texts := preload("res://addons/wildgrass/texts/texts.gd")

## The speeds of `message_speed`, times the config's letters per second.
const SPEEDS: Array[float] = [0.5, 1.0, 2.0]

signal changed(id: StringName, value: Variant)

@warning_ignore("shadowed_global_identifier")
var log: Log
## Where the options are kept.
var file_path: String

var _config: ConfigRegistry
## id -> the option as added.
var _options: Dictionary[StringName, Dictionary] = {}
## id -> its value, kept or not yet.
var _values: Dictionary[StringName, Variant] = {}
## Values read from the file for options not added yet.
var _read: Dictionary = {}
var _dialogue: Dialogue
var _texts: Texts


func _init(paths: Paths, logger: Log, config_registry: ConfigRegistry) -> void:
	log = logger
	_config = config_registry
	file_path = paths.user_file("options.json")


func config() -> WgOptionsConfig:
	return _config.get_config(&"options") as WgOptionsConfig


## Adds an option: `values` (an array, or a callable returning one),
## `default`, `apply` (a callable given the value), and for the screen
## `name`, `description`, `texts` (one per value), `slider`, `format`. Its
## kept value, if any, is applied at once. False, logged, without values or
## a default among them.
func add_option(id: StringName, option: Dictionary) -> bool:
	if not (option.get("values") is Array or option.get("values") is Callable):
		log.error(&"options", "option '%s' needs values" % id)
		return false
	_options[id] = option
	var values := values_of(id)
	if not values.is_empty() and option.get("default") not in values:
		log.error(&"options", "option '%s': its default %s is not among its values" % [id, option.get("default")])
		_options.erase(id)
		return false
	var key := str(id)
	var kept: Variant = _read.get(key, option.get("default"))
	if _read.has(key) and _index(values, kept) < 0:
		log.warn(&"options", "option '%s': %s is not among its values; using %s" % [id, kept, option.get("default")])
		kept = option.get("default")
	_values[id] = values[_index(values, kept)] if _index(values, kept) >= 0 else option.get("default")
	_apply(id)
	return true


func has_option(id: StringName) -> bool:
	return _options.has(id)


func option(id: StringName) -> Dictionary:
	return _options.get(id, {})


## The values an option may take now.
func values_of(id: StringName) -> Array:
	var found: Variant = _options.get(id, {}).get("values", [])
	if found is Callable:
		found = (found as Callable).call()
	return found if found is Array else []


func value(id: StringName) -> Variant:
	return _values.get(id)


## Sets an option, applies it and keeps it. False, logged, for an unknown
## option or a value not among its values.
func set_value(id: StringName, new_value: Variant) -> bool:
	if not _options.has(id):
		log.error(&"options", "no option '%s'" % id)
		return false
	var values := values_of(id)
	var at := _index(values, new_value)
	if at < 0:
		log.error(&"options", "option '%s': %s is not among its values" % [id, new_value])
		return false
	_values[id] = values[at]
	_apply(id)
	write()
	changed.emit(id, _values[id])
	return true


## The options shown, in the config's order: those added, with two values or
## more.
func shown() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key: String in config().order:
		var id := StringName(key)
		if _options.has(id) and values_of(id).size() >= 2:
			ids.append(id)
	return ids


## The text of an option's value: its `texts`, else `format`, else the value.
func text_of(id: StringName) -> String:
	var found := option(id)
	var values := values_of(id)
	var at := _index(values, value(id))
	var texts: Variant = found.get("texts", [])
	if texts is Array and at >= 0 and at < texts.size():
		return str(texts[at])
	if found.has("format"):
		return str(found["format"]) % value(id)
	return str(value(id))


## Reads the kept options; each option added since takes its value from them.
func read() -> void:
	_read = {}
	if not FileAccess.file_exists(file_path):
		return
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(file_path)) != OK or not parser.data is Dictionary:
		log.error(&"options", "%s is not a JSON object; using the defaults" % file_path.get_file())
		return
	_read = parser.data


## Keeps every option's value, and those read for options not added.
func write() -> void:
	var kept := _read.duplicate()
	for id: StringName in _values:
		kept[str(id)] = _values[id]
	DirAccess.make_dir_recursive_absolute(file_path.get_base_dir())
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		log.error(&"options", "cannot write %s: %s" % [file_path, error_string(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify(kept, "\t"))


## The engine's options: message speed, message frame, volume, language.
func add_engine_options(dialogue: Dialogue, texts: Texts) -> void:
	_dialogue = dialogue
	_texts = texts
	add_option(&"message_speed", {
		"name": "Text speed",
		"description": "Choose how fast messages are written.",
		"values": [1, 2, 3],
		"texts": ["Slow", "Normal", "Fast"],
		"default": 2,
		"apply": _apply_speed,
	})
	add_option(&"message_frame", {
		"name": "Message frame",
		"description": "Choose the frame of the message box.",
		"values": _frame_styles,
		"texts": _frame_names(),
		"default": "",
		"apply": _apply_frame,
	})
	add_option(&"volume", {
		"name": "Volume",
		"description": "Set the volume of the music and sound effects.",
		"values": range(0, 101, 5),
		"slider": true,
		"format": "%d%%",
		"default": 100,
		"apply": _apply_volume,
	})
	add_option(&"language", {
		"name": "Language",
		"description": "Choose the language of the game.",
		"values": texts.languages,
		"texts": texts.languages().map(texts.language_name),
		"default": texts.language if texts.language in texts.languages() else (texts.languages()[0] if not texts.languages().is_empty() else ""),
		"apply": _apply_language,
	})


func _apply(id: StringName) -> void:
	var apply: Variant = _options[id].get("apply")
	if apply is Callable and (apply as Callable).is_valid():
		(apply as Callable).call(_values[id])


static func _index(values: Array, wanted: Variant) -> int:
	for at in values.size():
		if typeof(values[at]) == typeof(wanted) and values[at] == wanted:
			return at
		if (values[at] is int or values[at] is float) and (wanted is int or wanted is float) and is_equal_approx(float(values[at]), float(wanted)):
			return at
	return -1


func _apply_speed(speed: Variant) -> void:
	_dialogue.letters_per_second = _dialogue.config().letters_per_second * SPEEDS[clampi(int(speed) - 1, 0, SPEEDS.size() - 1)]


func _frame_styles() -> Array:
	var styles := []
	for frame: Dictionary in _dialogue.config().frames:
		styles.append(frame["style"])
	return styles


func _frame_names() -> Array:
	var names := []
	for frame: Dictionary in _dialogue.config().frames:
		names.append(str(frame.get("name", frame["style"])))
	return names


func _apply_frame(style: Variant) -> void:
	_dialogue.style = str(style)


func _apply_volume(volume: Variant) -> void:
	var bus := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(float(volume) / 100.0))
	AudioServer.set_bus_mute(bus, float(volume) <= 0.0)


func _apply_language(code: Variant) -> void:
	if not str(code).is_empty():
		_texts.language = str(code)
