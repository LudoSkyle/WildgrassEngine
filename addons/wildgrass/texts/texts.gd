## The language of the game, and the texts it shows.
extends RefCounted

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")
const ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")

## The language changed.
signal language_changed(code: String)

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


func config() -> WgLanguageConfig:
	return _config.get_config(&"language") as WgLanguageConfig
