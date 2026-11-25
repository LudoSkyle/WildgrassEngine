## The Studio layer: recognises a Pokémon Studio project and turns its files
## into the engine's settings and data, through the engine's public API only.
## Nothing of the engine depends on it.
extends RefCounted

const _Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const _Log := preload("res://addons/wildgrass/core/log/log.gd")
const _ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const _Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")
const _Texts := preload("res://addons/wildgrass/texts/texts.gd")
const _Items := preload("res://addons/wildgrass/bag/items.gd")
const _Quests := preload("res://addons/wildgrass/story/quests.gd")
const _StudioTexts := preload("res://addons/wildgrass/studio/studio_texts.gd")
const _StudioItems := preload("res://addons/wildgrass/studio/studio_items.gd")
const _StudioQuests := preload("res://addons/wildgrass/studio/studio_quests.gd")
const _StudioSpecies := preload("res://addons/wildgrass/studio/studio_species.gd")
const _StudioEncounters := preload("res://addons/wildgrass/studio/studio_encounters.gd")
const _StudioZones := preload("res://addons/wildgrass/studio/studio_zones.gd")
const _Encounters := preload("res://addons/wildgrass/wild/encounters.gd")
const _Zones := preload("res://addons/wildgrass/maps/zones.gd")
const _SpeciesData := preload("res://addons/wildgrass/pokemon/species_data.gd")
const _Types := preload("res://addons/wildgrass/pokemon/types.gd")
const _Pokedex := preload("res://addons/wildgrass/pokedex/pokedex.gd")

## Studio's words for events' scripts (feature 22).
const SCRIPT_CONTEXT := "res://addons/wildgrass/studio/studio_script_context.gd"
## The project setting turning the layer on: `auto` (when the project has
## `project.studio`), `on`, `off`.
const SETTING := "wildgrass/studio/enabled"
## The title's images, inside the graphics folder.
const TITLES := "titles/"
## Studio's names of the engine's sound roles.
const SOUND_ROLES: Dictionary[String, String] = {
	"decision": "confirm", "receiveItem": "item", "receiveKeyItem": "key_item",
}
## Each part of Studio's sound design, and the kind of its sounds.
const SOUND_KINDS: Dictionary[String, String] = {
	"soundEffects": "effect", "musicEffects": "jingle", "backgroundMusic": "music", "backgroundSound": "ambience",
}
## The keys of the engine's words, and the Studio text line that says them.
## The others (a line with Studio's own variables, or none) are the game's.
const LABELS: Dictionary[String, String] = {
	"wg.yes": "100011:27",
	"wg.no": "100011:28",
	"wg.cancel": "100022:7",
	"wg.menu.pokedex": "100014:1",
	"wg.menu.bag": "100014:2",
	"wg.menu.save": "100014:4",
	"wg.menu.options": "100014:5",
	"wg.menu.exit": "9000:26",
	"wg.title.play": "100032:77",
	"wg.title.options": "100014:5",
	"wg.title.quit": "9000:26",
	"wg.title.prompt": "100032:113",
	"wg.slots.new_game": "9000:0",
	"wg.slots.continue": "100025:0",
	"wg.slots.erase": "9000:22",
	"wg.slots.options": "100014:5",
	"wg.save.question": "100026:15",
	"wg.save.failed": "100026:19",
	"wg.bag.use": "100022:0",
	"wg.bag.toss": "100022:1",
	"wg.options.text_speed": "100042:3",
	"wg.options.text_speed_help": "100042:7",
	"wg.options.slow": "100042:4",
	"wg.options.normal": "100042:5",
	"wg.options.fast": "100042:6",
	"wg.options.message_frame": "9000:165",
	"wg.options.message_frame_help": "9000:166",
	"wg.options.volume": "9000:29",
	"wg.options.volume_help": "9000:30",
	"wg.options.language": "9000:167",
	"wg.options.language_help": "9000:168",
}

@warning_ignore("shadowed_global_identifier")
var log: _Log
## Studio's text files.
var texts: _StudioTexts
## True once installed.
var installed := false

var _paths: _Paths
var _config: _ConfigRegistry
var _hooks: _Hooks
var _texts: _Texts
var _items: _StudioItems
var _quests: _StudioQuests
var _species: _StudioSpecies
var _encounters: _StudioEncounters
var _zones: _StudioZones
## Studio config file -> its data, read once.
var _files: Dictionary[String, Dictionary] = {}
var _translations: Array[Translation] = []
## True once the layer named Studio's script context in the settings.
var _named_context := false


func _init(paths: _Paths, logger: _Log, config_registry: _ConfigRegistry, hook_registry: _Hooks) -> void:
	_paths = paths
	log = logger
	_config = config_registry
	_hooks = hook_registry
	texts = _StudioTexts.new(paths, logger, config_registry)
	_items = _StudioItems.new(paths, logger)
	_quests = _StudioQuests.new(paths, logger)
	_species = _StudioSpecies.new(paths, logger)
	_encounters = _StudioEncounters.new(paths, logger)
	_zones = _StudioZones.new(paths, logger)


## True when the project is a Studio project, as the setting says.
func is_project() -> bool:
	match str(ProjectSettings.get_setting(SETTING, "auto")):
		"on":
			return true
		"off":
			return false
	return FileAccess.file_exists(_paths.resolve(&"studio", "project.studio"))


## Plugs the project into the engine: its configs as sources, its texts, its
## items, pockets, quests, species, types, Pokédexes, wild groups and
## zones, its words for events' scripts. Done once.
func install(engine_texts: _Texts, items: _Items, quests: _Quests, species: _SpeciesData, types: _Types, pokedex: _Pokedex, encounters: _Encounters, zones: _Zones) -> void:
	if installed:
		return
	installed = true
	_texts = engine_texts
	name_script_context()
	_config.add_source(&"display", _display)
	_config.add_source(&"language", _language)
	_config.add_source(&"save", _save)
	_config.add_source(&"options", _options)
	_config.add_source(&"bag", _bag)
	_config.add_source(&"title", _title)
	_config.add_source(&"pokedex", _pokedex)
	_config.add_source(&"audio", _audio)
	engine_texts.add_placeholder("text", texts.text_reference, texts.text_given)
	texts.language_of = engine_texts.reading_language
	_hooks.add(&"text_tokens", &"wildgrass_studio", texts.tokens)
	items.add_source(_items.read, _items.ids)
	quests.add_source(_quests.read_all)
	species.add_source(_species.read_species, _species.species_ids)
	types.add_source(_species.read_type, _species.type_ids)
	pokedex.add_source(_species.read_dex, _species.dex_ids)
	encounters.add_source(_encounters.read, _encounters.ids)
	zones.add_source(_zones.read, _zones.ids)
	_add_translations()


## Names Studio's words for events' scripts in the settings (feature 22),
## unless the game names its own. Done by `install()`.
func name_script_context() -> void:
	if str(ProjectSettings.get_setting(WgScriptContext.SETTING, "")).is_empty():
		ProjectSettings.set_setting(WgScriptContext.SETTING, SCRIPT_CONTEXT)
		_named_context = true


## Takes back the labels' translations and the script context it named:
## tests, a project switched.
func uninstall() -> void:
	if _named_context:
		ProjectSettings.set_setting(WgScriptContext.SETTING, "")
		_named_context = false
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
	given["pockets"] = _StudioItems.pockets()
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
	var music := str(config_file("scene_title_config").get("bgmName", ""))
	if not music.is_empty():
		given["music"] = _paths.resolve(&"studio", music)
	for field: String in ["background", "logo"]:
		var path := _paths.resolve(&"graphics", TITLES + ("title" if field == "logo" else field) + ".png")
		if _paths.exists(path):
			given[field] = path
	return given


## Studio's folders, and its sound design as named sounds: its names of the
## engine's roles mapped, the others kept in snake case.
func _audio() -> Dictionary:
	var sounds := {}
	var design := config_file("sound_design_config")
	for part: String in SOUND_KINDS:
		var entries: Variant = design.get(part, {})
		for key: Variant in entries if entries is Dictionary else {}:
			var sound: Variant = entries[key]
			if not sound is Dictionary or str(sound.get("name", "")).is_empty():
				continue
			var role: String = SOUND_ROLES.get(str(key), str(key).to_snake_case())
			sounds[role] = {"kind": SOUND_KINDS[part], "name": _paths.resolve(&"studio", str(sound["name"])), "volume": float(sound.get("volume", 100)), "pitch": float(sound.get("pitch", 100))}
	var given := {"folders": {"music": "bgm", "ambience": "bgs", "jingles": "me", "effects": "se"}}
	if not sounds.is_empty():
		given["sounds"] = sounds
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
