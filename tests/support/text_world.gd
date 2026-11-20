## The texts service built for one test, with its config, a data folder and the
## locale put back afterwards.
extends RefCounted

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")
const ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")
const Texts := preload("res://addons/wildgrass/texts/texts.gd")
const Sandbox := preload("res://tests/support/sandbox.gd")

var sandbox: Sandbox
var logged: Array[String] = []
var hooks: Hooks
var texts: Texts
var _locale: String


func _init() -> void:
	_locale = TranslationServer.get_locale()
	sandbox = Sandbox.new()
	sandbox.use_data_folder()
	var logger := Log.new()
	logger.echo = false
	# A local array: a lambda reaching `self` would keep this world alive.
	var lines: Array[String] = []
	logged = lines
	logger.logged.connect(func(level: Log.Level, _channel: StringName, message: String) -> void:
		lines.append("%s %s" % [Log.Level.keys()[level], message]))
	var config := ConfigRegistry.new(Paths.new(false), logger)
	config.register(&"language", WgLanguageConfig, "language_config")
	hooks = Hooks.new()
	texts = Texts.new(Paths.new(false), logger, config, hooks)


func cleanup() -> void:
	TranslationServer.set_locale(_locale)
	sandbox.cleanup()
