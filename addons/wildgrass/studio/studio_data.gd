## A Studio project's data written as a Godot project's own, so that the
## game reads no Studio file: its moves, abilities and natures as resources
## in the engine's folders (`res://moves/<id>.tres`…), each text a key
## (`move.<id>.name`) whose words in each language go into one translation
## file; its highest level as the `pokemon` config. Run by `import_data.gd`.
extends RefCounted

const _Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const _Log := preload("res://addons/wildgrass/core/log/log.gd")
const _StudioSpecies := preload("res://addons/wildgrass/studio/studio_species.gd")
const _StudioMessages := preload("res://addons/wildgrass/studio/studio_messages.gd")

## The texts of each kind, by the field that holds them.
const TEXT_FIELDS: Dictionary[StringName, Array] = {
	&"move": [&"name", &"description", &"contest_description"],
	&"ability": [&"name", &"description"],
	&"nature": [&"name"],
}


## Paths whose `data` folder is the Studio project's, the others the game's.
class _StudioPaths extends _Paths:
	var data := ""

	func root(kind: StringName) -> String:
		return data if kind == &"data" else super(kind)


## The Studio project's `Data` folder.
var data_folder := ""
## The translation file written.
var texts_file := "res://locale/data.csv"
## What went wrong, to show.
var problems: Array[String] = []

var _paths: _StudioPaths
var _reader: _StudioSpecies
var _words: _StudioMessages
var _label := RegEx.create_from_string("^\\{text:([0-9]+):([0-9]+)\\}$")


func _init(data: String) -> void:
	data_folder = data
	_paths = _StudioPaths.new(false)
	_paths.data = data if data.ends_with("/") else data + "/"
	var logger := _Log.new()
	var found := problems
	logger.logged.connect(func(_level: _Log.Level, _channel: StringName, message: String) -> void: found.append(message))
	_reader = _StudioSpecies.new(_paths, logger)
	_words = _StudioMessages.new(data)


## Writes every move; returns how many.
func write_moves() -> int:
	return _write(&"moves", &"move", _reader.move_ids(), _reader.read_move)


## Writes every ability; returns how many.
func write_abilities() -> int:
	return _write(&"abilities", &"ability", _reader.ability_ids(), _reader.read_ability)


## Writes every nature; returns how many.
func write_natures() -> int:
	return _write(&"natures", &"nature", _reader.nature_ids(), _reader.read_nature)


## Writes the words of every text written so far into `texts_file`, a column
## per language. Returns its path, or "".
func write_translations() -> String:
	return texts_file if _words.write_translations(texts_file) else ""


## Writes the `pokemon` config with Studio's highest level, unless the game
## has one. Returns its path, or "".
func write_config() -> String:
	var path := _paths.resolve(&"config", "pokemon.json")
	var settings := _paths.resolve(&"data", "configs/settings_config.json")
	if FileAccess.file_exists(path) or not FileAccess.file_exists(settings):
		return ""
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(settings))
	if not data is Dictionary or not (data as Dictionary).has("pokemonMaxLevel"):
		return ""
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		problems.append("%s: cannot be written" % path)
		return ""
	file.store_string(JSON.stringify({"max_level": int(data["pokemonMaxLevel"])}, "\t") + "\n")
	return path


func _write(kind: StringName, what: StringName, ids: Array[StringName], read: Callable) -> int:
	var folder := _paths.root(kind)
	DirAccess.make_dir_recursive_absolute(folder)
	var written := 0
	for id in ids:
		var resource: Resource = read.call(id)
		if resource == null:
			continue
		for field: StringName in TEXT_FIELDS[what]:
			resource.set(field, _keyed(str(resource.get(field)), "%s.%s.%s" % [what, id, field]))
		var path := folder + "%s.tres" % id
		if ResourceSaver.save(resource, path) != OK:
			problems.append("%s: cannot be written" % path)
			continue
		written += 1
	return written


## `label`, a line of Studio's files, as `key`, its words kept for each
## language; empty if the line says nothing in any.
func _keyed(label: String, key: String) -> String:
	var found := _label.search(label)
	if found == null:
		return label
	var file := found.get_string(1).to_int()
	var at := found.get_string(2).to_int()
	var words := {}
	for code in _words.languages():
		var said := _words.line(file, at, code)
		if not said.is_empty():
			words[code] = said
	if words.is_empty():
		return ""
	_words.translations[key] = words
	return key
