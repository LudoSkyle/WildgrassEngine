## Compiles the events' scripts (feature 22), each once: a script's lines,
## or a condition's expression, wrapped in a class extending the project's
## script context. The events service owns it.
extends RefCounted

const _Log := preload("res://addons/wildgrass/core/log/log.gd")
## Lines before a script's first in the class it is wrapped in.
const HEADER_LINES := 3
## A script is a few lines, often written by an importer: typing warnings,
## errors in the engine's own code, do not stop it.
const IGNORED := "@warning_ignore_start(\"untyped_declaration\", \"inferred_declaration\", \"unsafe_property_access\", \"unsafe_method_access\", \"unsafe_call_argument\", \"unsafe_cast\", \"unused_variable\", \"unused_parameter\", \"unused_local_constant\", \"shadowed_variable\", \"shadowed_global_identifier\", \"return_value_discarded\", \"standalone_expression\", \"integer_division\", \"narrowing_conversion\", \"redundant_await\", \"inference_on_variant\", \"unsafe_void_return\")"

var log: _Log

## Compiled scripts, by their context's path, kind and text.
var _compiled: Dictionary[String, GDScript] = {}
var _failed: Dictionary[String, bool] = {}
var _context_problem_logged := false


func _init(logger: _Log) -> void:
	log = logger


## The project's script context: the setting's script if it extends
## `WgScriptContext`, else that one (logged once).
func context_script() -> Script:
	var path := str(ProjectSettings.get_setting(WgScriptContext.SETTING, ""))
	if path.is_empty():
		return WgScriptContext
	var script := load(path) as Script if ResourceLoader.exists(path) else null
	if script != null and _extends(script, WgScriptContext):
		return script
	if not _context_problem_logged:
		_context_problem_logged = true
		log.error(&"events", "%s: %s is not a script extending WgScriptContext; using WgScriptContext" % [WgScriptContext.SETTING, path])
	return WgScriptContext


## A context running `source` (a script's lines, or a condition's expression
## if `condition`), bound to `events`, `run`, `event` and `kept`; null if it
## does not compile (logged once, with `place`).
func make(source: String, condition: bool, place: String, events: Object, run: RefCounted, event: WgEvent, kept: Dictionary) -> WgScriptContext:
	var compiled := _compile(source, condition, place)
	if compiled == null:
		return null
	var made := compiled.new() as WgScriptContext
	made.bind(events, run, event, kept)
	return made


func _compile(source: String, condition: bool, place: String) -> GDScript:
	var context := context_script()
	var key := "%s\n%s\n%s" % [context.resource_path, "check" if condition else "run", source]
	if _compiled.has(key):
		return _compiled[key]
	if _failed.has(key):
		return null
	var text := "extends \"%s\"\n%s\n" % [context.resource_path, IGNORED]
	if condition:
		# Untyped: an answer that is not true or false is seen as it is.
		text += "func check():\n\treturn (%s\n\t)\n" % source.strip_edges()
	else:
		text += "func run() -> void:\n"
		for line in source.split("\n"):
			text += "\t" + line + "\n"
		text += "\tpass\n"
	var made := GDScript.new()
	made.source_code = text
	if made.reload() != OK:
		_failed[key] = true
		log.error(&"events", "%s: its script does not compile (Godot's error above; the script's line n is its line n + %d)" % [place, HEADER_LINES])
		return null
	_compiled[key] = made
	return made


static func _extends(script: Script, base: Script) -> bool:
	var current := script
	while current != null:
		if current == base:
			return true
		current = current.get_base_script()
	return false
