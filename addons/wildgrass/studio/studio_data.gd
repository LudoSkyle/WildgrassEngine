## A Studio project's data written as a Godot project's own, so that the
## game reads no Studio file: its species, types, moves, abilities and
## natures as resources in the engine's folders (`res://pokemon/<id>.tres`,
## `res://moves/<id>.tres`…), each text a key (`move.<id>.name`) whose words
## in each language go into one translation file; the species' pictures
## copied into the game's `graphics/` as Studio places them, their cries
## into `audio/cries/`; its highest level as the `pokemon` config. Run by
## `import_data.gd`.
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
	&"type": [&"name"],
	&"species": [&"name", &"genus", &"description"],
}
## Where the cries go, in the game's `audio` folder.
const CRIES := "cries/"


## Paths whose `data`, `graphics` and `audio` folders are the Studio
## project's, the others the game's.
class _StudioPaths extends _Paths:
	var data := ""

	func root(kind: StringName) -> String:
		match kind:
			&"data":
				return data
			&"graphics", &"audio":
				return data.get_base_dir().get_base_dir() + "/%s/" % kind
		return super(kind)


## The Studio project's `Data` folder.
var data_folder := ""
## The translation file written.
var texts_file := "res://locale/data.csv"
## How many pictures and cries were copied.
var copied := 0
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


## Writes every species, its pictures and cries copied; returns how many.
func write_species() -> int:
	return _write(&"pokemon", &"species", _reader.species_ids(), _species_with_files)


## Writes every type; returns how many.
func write_types() -> int:
	return _write(&"types", &"type", _reader.type_ids(), _reader.read_type)


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


## The species of `id`, its forms' texts as keys, their pictures and cry
## copied into the game; a file Studio names but has not is left out.
func _species_with_files(id: StringName) -> WgSpecies:
	var species := _reader.read_species(id)
	if species == null:
		return null
	var graphics := _paths.root(&"graphics")
	var audio := _paths.root(&"audio")
	var game := _Paths.new(false)
	for form in species.forms:
		var prefix := "species.%s.form_%d." % [id, form.form]
		form.name = _keyed(form.name, prefix + "name")
		form.description = _keyed(form.description, prefix + "description")
		for key: StringName in form.pictures.keys():
			var source := str(form.pictures[key])
			var target := game.resolve(&"audio", CRIES + source.get_file()) if key == &"cry" else game.resolve(&"graphics", source.trim_prefix(graphics))
			if key != &"cry" and not source.begins_with(graphics) or key == &"cry" and not source.begins_with(audio) or not _copy(source, target):
				form.pictures.erase(key)
			else:
				form.pictures[key] = target
	return species


## Copies `source` to `target`, unless it is there already the same; false
## if `source` is not there.
func _copy(source: String, target: String) -> bool:
	if not FileAccess.file_exists(source):
		return false
	if FileAccess.file_exists(target) and FileAccess.get_md5(target) == FileAccess.get_md5(source):
		return true
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	if DirAccess.copy_absolute(source, target) != OK:
		problems.append("%s: cannot be written" % target)
		return false
	copied += 1
	return true


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
