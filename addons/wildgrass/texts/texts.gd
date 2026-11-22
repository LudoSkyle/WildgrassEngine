## The language of the game, and the texts it shows, placeholders filled.
extends RefCounted

const _Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const _Log := preload("res://addons/wildgrass/core/log/log.gd")
const _ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const _Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")

## The language changed.
signal language_changed(code: String)

@warning_ignore("shadowed_global_identifier")
var log: _Log
## The current language: Godot's locale.
var language: String:
	get:
		return TranslationServer.get_locale()
	set(code):
		if code == TranslationServer.get_locale():
			return
		TranslationServer.set_locale(code)
		language_changed.emit(TranslationServer.get_locale())

var _paths: _Paths
var _config: _ConfigRegistry
var _hooks: _Hooks
var _warned: Dictionary[String, bool] = {}
var _values: Dictionary[StringName, Variant] = {}

static var _placeholder: RegEx
## Placeholders plugins add: name -> callable given the argument.
var _placeholders: Dictionary[String, Callable] = {}
## Name -> callable given the argument and a language, true if the
## placeholder has a text of its own in it.
var _givens: Dictionary[String, Callable] = {}


func _init(paths: _Paths, logger: _Log, config_registry: _ConfigRegistry, hook_registry: _Hooks) -> void:
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
## `{key:action}`, and those plugins add; the filter hook `text_tokens(text)`
## may rewrite it first.
## With `escape`, what values put in is escaped for messages: it never reads
## as a tag. `values` come first: one text's own.
func format(text: String, escape := false, values := {}) -> String:
	text = str(_hooks.filter(&"text_tokens", text))
	return _replace(_pattern(), text, _fill_placeholder.bind(escape, values))


## A label of the game or the engine, written in English: translated through
## Godot's translations, then its placeholders filled.
func label(text: String, values := {}) -> String:
	return format(TranslationServer.translate(text), false, values)


## A label as `label()` gives it, in language `code` instead of the one
## shown: Godot's translations and the placeholders alike. Nothing that
## follows the language is told.
func label_in(code: String, text: String, values := {}) -> String:
	var main := TranslationServer.get_or_add_domain(&"")
	var before := main.get_locale_override()
	main.set_locale_override(code)
	var result := label(text, values)
	main.set_locale_override(before)
	return result


## True if `text` has its own words in language `code`, not another's in
## their place: each placeholder that can tell has a text of its own there,
## and what is written around them is translated to `code`, or `code` has no
## translation at all (the language it is written in).
func is_given_in(code: String, text: String) -> bool:
	if text.strip_edges().is_empty():
		return false
	for found in _pattern().search_all(text):
		var given: Callable = _givens.get(found.get_string(1), Callable())
		if given.is_valid() and not bool(given.call(found.get_string(2), code)):
			return false
	if _pattern().sub(text, "", true).strip_edges().is_empty():
		return true
	if not TranslationServer.has_translation_for_locale(code, true):
		return true
	var translation := TranslationServer.get_translation_object(code)
	return translation != null and not String(translation.get_message(text)).is_empty()


## The language texts are read in now: the one shown, or `label_in()`'s
## while it reads. A placeholder that picks a language asks it.
func reading_language() -> String:
	var override := TranslationServer.get_or_add_domain(&"").get_locale_override()
	return override if not override.is_empty() else TranslationServer.get_locale()


## `{name}`, `{name:argument}`, `{name?if true|if false}`.
static func _pattern() -> RegEx:
	if _placeholder == null:
		_placeholder = RegEx.create_from_string("\\{(\\w+)(?::([^{}?|]*))?(?:\\?([^{}|]*)\\|([^{}]*))?\\}")
	return _placeholder


## Adds a placeholder `{name:argument}`: `callable` is given the argument and
## returns what shows, or null to leave it as written. A name taken again is
## replaced. `given`, if any, is given the argument and a language, and says
## whether the placeholder has a text of its own in it (`is_given_in()`).
func add_placeholder(placeholder_name: String, callable: Callable, given := Callable()) -> void:
	_placeholders[placeholder_name] = callable
	if given.is_valid():
		_givens[placeholder_name] = given
	else:
		_givens.erase(placeholder_name)


func config() -> WgLanguageConfig:
	return _config.get_config(&"language") as WgLanguageConfig


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


func _fill_placeholder(found: RegExMatch, escape: bool, values: Dictionary) -> String:
	var value_name := found.get_string(1)
	var argument := found.get_string(2)
	var shown: Variant = null
	if _placeholders.has(value_name) and not argument.is_empty():
		shown = (_placeholders[value_name] as Callable).call(argument)
	elif value_name == "key" and not argument.is_empty():
		shown = _key_name(argument)
	elif argument.is_empty():
		shown = values[value_name] if values.has(value_name) else value(StringName(value_name))
	if shown == null:
		_warn_once("no value for %s" % found.get_string())
		return found.get_string()
	if found.get_start(3) >= 0:
		return found.get_string(3) if _is_true(shown) else found.get_string(4)
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
