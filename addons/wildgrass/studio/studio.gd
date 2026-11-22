## The Studio layer: recognises a Pokémon Studio project and turns its files
## into the engine's settings and data, through the engine's public API only.
## Nothing of the engine depends on it.
extends RefCounted

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")
const ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")
const Texts := preload("res://addons/wildgrass/texts/texts.gd")
const Items := preload("res://addons/wildgrass/bag/items.gd")
const Quests := preload("res://addons/wildgrass/story/quests.gd")
const StudioTexts := preload("res://addons/wildgrass/studio/studio_texts.gd")
const StudioItems := preload("res://addons/wildgrass/studio/studio_items.gd")
const StudioQuests := preload("res://addons/wildgrass/studio/studio_quests.gd")
const StudioSpecies := preload("res://addons/wildgrass/studio/studio_species.gd")
const SpeciesData := preload("res://addons/wildgrass/pokemon/species_data.gd")
const Types := preload("res://addons/wildgrass/pokemon/types.gd")
const Pokedex := preload("res://addons/wildgrass/pokedex/pokedex.gd")

## The project setting turning the layer on: `auto` (when the project has
## `project.studio`), `on`, `off`.
const SETTING := "wildgrass/studio/enabled"
## The title's images, inside the graphics folder.
const TITLES := "titles/"
## The engine's English labels, and the Studio text line that says them.
const LABELS: Dictionary[String, String] = {
	"Bag": "100014:2",
	"Save": "100014:4",
	"Options": "100014:5",
	"Exit": "9000:26",
	"Quit": "9000:26",
	"Play": "9000:126",
	"New game": "9000:0",
	"Continue": "100025:0",
	"Erase": "9000:22",
	"Text speed": "100042:3",
	"Choose how fast messages are written.": "100042:7",
	"Slow": "100042:4",
	"Normal": "100042:5",
	"Fast": "100042:6",
	"Message frame": "9000:165",
	"Choose the frame of the message box.": "9000:166",
	"Volume": "9000:29",
	"Set the volume of the music and sound effects.": "9000:30",
	"Language": "9000:167",
	"Choose the language of the game.": "9000:168",
}

@warning_ignore("shadowed_global_identifier")
var log: Log
## Studio's text files.
var texts: StudioTexts
## True once installed.
var installed := false

var _paths: Paths
var _config: ConfigRegistry
var _hooks: Hooks
var _texts: Texts
var _items: StudioItems
var _quests: StudioQuests
var _species: StudioSpecies
## Studio config file -> its data, read once.
var _files: Dictionary[String, Dictionary] = {}
var _translations: Array[Translation] = []


func _init(paths: Paths, logger: Log, config_registry: ConfigRegistry, hook_registry: Hooks) -> void:
	_paths = paths
	log = logger
	_config = config_registry
	_hooks = hook_registry
	texts = StudioTexts.new(paths, logger, config_registry)
	_items = StudioItems.new(paths, logger)
	_quests = StudioQuests.new(paths, logger)
	_species = StudioSpecies.new(paths, logger)


## True when the project is a Studio project, as the setting says.
func is_project() -> bool:
	match str(ProjectSettings.get_setting(SETTING, "auto")):
		"on":
			return true
		"off":
			return false
	return FileAccess.file_exists(_paths.resolve(&"studio", "project.studio"))


## Plugs the project into the engine: its configs as sources, its texts, its
## items, pockets, quests, species, types and Pokédexes. Done once.
func install(engine_texts: Texts, items: Items, quests: Quests, species: SpeciesData, types: Types, pokedex: Pokedex) -> void:
	if installed:
		return
	installed = true
	_texts = engine_texts
	_config.add_source(&"display", _display)
	_config.add_source(&"language", _language)
	_config.add_source(&"save", _save)
	_config.add_source(&"options", _options)
	_config.add_source(&"bag", _bag)
	_config.add_source(&"title", _title)
	_config.add_source(&"pokedex", _pokedex)
	engine_texts.add_placeholder("text", texts.text_reference)
	_hooks.add(&"text_tokens", &"wildgrass_studio", texts.tokens)
	items.add_source(_items.read)
	quests.add_source(_quests.read_all)
	species.add_source(_species.read_species, _species.species_ids)
	types.add_source(_species.read_type, _species.type_ids)
	pokedex.add_source(_species.read_dex, _species.dex_ids)
	_add_translations()


## Takes back the labels' translations: tests, a project switched.
func uninstall() -> void:
	for translation in _translations:
		TranslationServer.remove_translation(translation)
	_translations.clear()


## A Studio config file, `Data/configs/<name>.json`; {} if missing.
func config_file(file_name: String) -> Dictionary:
	if not _files.has(file_name):
		var path := _paths.resolve(&"data", "configs/%s.json" % file_name)
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		if FileAccess.file_exists(path) and not data is Dictionary:
			log.error(&"studio", "%s: not a JSON object" % path.get_file())
		_files[file_name] = data if data is Dictionary else {}
	return _files[file_name]


## The fields of `file` the engine has a use for, renamed.
func _fields(file_name: String, names: Dictionary) -> Dictionary:
	var data := config_file(file_name)
	var given := {}
	for key: String in names:
		if data.has(key):
			given[names[key]] = data[key]
	return given


func _display() -> Dictionary:
	return _fields("display_config", {"gameResolution": "resolution", "windowScale": "window_scale", "isFullscreen": "fullscreen"})


func _language() -> Dictionary:
	return _fields("language_config", {"defaultLanguage": "default", "choosableLanguageCode": "choosable", "choosableLanguageTexts": "names"})


func _save() -> Dictionary:
	if int(config_file("save_config").get("saveKey", 0)) != 0:
		log.warn(&"studio", "save_config.json: saveKey is for Studio's binary saves; games are written as JSON, not encrypted")
	return _fields("save_config", {"maximumSave": "slots", "baseFilename": "file", "isCanSaveOnAnySave": "save_anywhere"})


func _options() -> Dictionary:
	return _fields("game_options_config", {"order": "order"})


func _bag() -> Dictionary:
	var given := _fields("settings_config", {"maxBagItemCount": "max_count"})
	given["pockets"] = StudioItems.pockets()
	return given


## Studio's splashes, its language at first launch, its controls' delay, its
## game's name, its title images when they exist; no prompt.
func _title() -> Dictionary:
	var given := _fields("scene_title_config", {"isLanguageSelectionEnabled": "choose_language", "controlWaitTime": "controls_delay"})
	var splashes: Variant = config_file("scene_title_config").get("additionalSplashes")
	if splashes is Array:
		given["splashes"] = (splashes as Array).map(func(splash: Variant) -> String: return _paths.resolve(&"graphics", TITLES + "%s.png" % splash))
	given.merge(_fields("infos_config", {"gameTitle": "name"}))
	given["show_prompt"] = false
	for field: String in ["background", "logo"]:
		var path := _paths.resolve(&"graphics", TITLES + ("title" if field == "logo" else field) + ".png")
		if _paths.exists(path):
			given[field] = path
	return given


func _pokedex() -> Dictionary:
	return {"dexes": ["regional"]} if _species.has_regional() else {}


## A translation per language of Studio's texts, saying the engine's labels
## with Studio's words.
func _add_translations() -> void:
	var by_column: Dictionary[String, Translation] = {}
	var columns := (_config.get_config(&"studio") as WgStudioConfig).columns
	for label: String in LABELS:
		var place := LABELS[label].split(":")
		var cells := texts.cells(int(place[0]), int(place[1]))
		for column: String in cells:
			if not by_column.has(column):
				var translation := Translation.new()
				translation.locale = _locale_of(column, columns)
				by_column[column] = translation
			by_column[column].add_message(label, cells[column])
	for column: String in by_column:
		TranslationServer.add_translation(by_column[column])
		_translations.append(by_column[column])


## The Godot locale of a column: the one the config maps to it, else its code.
static func _locale_of(column: String, columns: Dictionary[String, String]) -> String:
	for locale: String in columns:
		if columns[locale].to_lower() == column:
			return locale
	return column
