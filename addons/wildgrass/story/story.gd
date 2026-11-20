## Where the player is in the story: named flags and values, and conditions
## on them.
extends RefCounted

const Log := preload("res://addons/wildgrass/core/log/log.gd")
const Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")
const Maps := preload("res://addons/wildgrass/maps/maps.gd")
const Dialogue := preload("res://addons/wildgrass/dialogue/dialogue.gd")

## A flag or a value changed.
signal changed(name: StringName)
## The whole state was put back or emptied.
signal restored

@warning_ignore("shadowed_global_identifier")
var log: Log

var _hooks: Hooks
var _maps: Maps
var _flags: Dictionary[StringName, bool] = {}
var _values: Dictionary[StringName, Variant] = {}
var _warned: Dictionary[String, bool] = {}
## True once a [reload] tag was reached, until the dialogue closes or a warp.
var _reload_asked := false

static var _comparison := RegEx.create_from_string("^(\\w+)\\s*(!=|<=|>=|=|<|>)\\s*(.+)$")
static var _identifier := RegEx.create_from_string("^\\w+$")


func _init(logger: Log, hook_registry: Hooks, maps_service: Maps) -> void:
	log = logger
	_hooks = hook_registry
	_maps = maps_service
	_hooks.add(&"text_value", &"wildgrass_story", _text_value)
	_hooks.add(&"map_built", &"wildgrass_story", _keep_what_shows)
	# Before the dialogue's own: a warp drops a reload asked, then closes it.
	_maps.map_changed.connect(_on_map_changed)


func set_flag(flag: StringName) -> void:
	if not _flags.has(flag):
		_flags[flag] = true
		changed.emit(flag)


func clear_flag(flag: StringName) -> void:
	if _flags.erase(flag):
		changed.emit(flag)


func has(flag: StringName) -> bool:
	return _flags.has(flag)


## Sets a value: a number or a text. `null` removes it.
func set_value(value_name: StringName, value: Variant) -> void:
	if value == null:
		if _values.erase(value_name):
			changed.emit(value_name)
		return
	if not _is_value(value):
		log.error(&"story", "%s: a value is a number or a text, got %s" % [value_name, type_string(typeof(value))])
		return
	var kept: Variant = str(value) if value is StringName else value
	var old: Variant = _values.get(value_name)
	if old == null or typeof(old) != typeof(kept) or old != kept:
		_values[value_name] = kept
		changed.emit(value_name)


## A value; 0 if unset.
func value(value_name: StringName) -> Variant:
	return _values.get(value_name, 0)


func has_value(value_name: StringName) -> bool:
	return _values.has(value_name)


## The name of a flag that belongs to `node`, on its own map: the map's id,
## the node's path in it, and `flag`.
func local(node: Node, flag: StringName) -> StringName:
	var map := _map_of(node)
	if map == null:
		return StringName("%s:%s" % [node.name, flag])
	return StringName("%s/%s:%s" % [_maps.id_of(map), map.get_path_to(node), flag])


## True if every term of `condition` holds: `flag`, `!flag`, `name >= 3`,
## `local:flag` (of `node`), or a term the `story_term` hook reads. Empty: true.
func check(condition: String, node: Node = null) -> bool:
	for raw: String in condition.split(","):
		var term := raw.strip_edges()
		if term.is_empty():
			continue
		var denied := term.begins_with("!")
		if denied:
			term = term.substr(1).strip_edges()
		if _holds(term, node) == denied:
			return false
	return true


## Adds the message tags `[flag=name]`, `[unflag=name]` and `[reload]`, which
## reloads the map once the dialogue is closed, unless a warp closed it.
func add_tags(dialogue: Dialogue) -> void:
	# Methods, not lambdas: a lambda would keep this service alive.
	dialogue.add_tag(&"flag", _flag_tag)
	dialogue.add_tag(&"unflag", _unflag_tag)
	dialogue.add_tag(&"reload", _ask_reload)
	dialogue.closed.connect(_on_dialogue_closed)


func _flag_tag(flag: String) -> void:
	set_flag(StringName(flag))


func _unflag_tag(flag: String) -> void:
	clear_flag(StringName(flag))


func _ask_reload(_value: String) -> void:
	_reload_asked = true


func _on_dialogue_closed() -> void:
	if _reload_asked:
		_reload_asked = false
		_maps.reload()


func _on_map_changed(_map: WgMap) -> void:
	if not _maps.is_crossing:
		_reload_asked = false


## Everything, as a dictionary JSON can hold.
func state() -> Dictionary:
	var flags: Array[String] = []
	for flag: StringName in _flags:
		flags.append(str(flag))
	flags.sort()
	var values := {}
	for value_name: StringName in _values:
		values[str(value_name)] = _values[value_name]
	return {"flags": flags, "values": values}


## Puts back what `state()` gave.
func restore(saved: Dictionary) -> void:
	_flags.clear()
	_values.clear()
	for flag: Variant in saved.get("flags", []):
		_flags[StringName(str(flag))] = true
	var values: Variant = saved.get("values", {})
	if values is Dictionary:
		for value_name: Variant in values:
			if _is_value(values[value_name]):
				_values[StringName(str(value_name))] = values[value_name]
			else:
				log.error(&"story", "%s: a value is a number or a text" % value_name)
	restored.emit()


## Empties the story: a new game.
func reset() -> void:
	_flags.clear()
	_values.clear()
	restored.emit()


func _holds(term: String, node: Node) -> bool:
	if term.begins_with("local:"):
		if node == null:
			_warn_once("%s: no node for a local flag" % term)
			return false
		return has(local(node, StringName(term.substr(6))))
	var compared := _comparison.search(term)
	if compared != null:
		return _compare(value(StringName(compared.get_string(1))), compared.get_string(2), compared.get_string(3).strip_edges())
	if _identifier.search(term) != null:
		return has(StringName(term))
	var read: Variant = _hooks.filter(&"story_term", null, [term, node])
	if read == null:
		_warn_once("nobody reads the condition term '%s'" % term)
		return false
	return bool(read)


static func _is_value(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME]


static func _compare(left: Variant, operator: String, written: String) -> bool:
	var right: Variant = written.to_float() if written.is_valid_float() else written
	if (left is int or left is float) and (right is int or right is float):
		match operator:
			"=": return left == right
			"!=": return left != right
			"<": return left < right
			"<=": return left <= right
			">": return left > right
			">=": return left >= right
	match operator:
		"=": return str(left) == str(right)
		"!=": return str(left) != str(right)
	return false


## Frees what a WgShowIf of `map` keeps off it.
func _keep_what_shows(map: WgMap, _map_id: StringName) -> void:
	var gates: Array[WgShowIf] = []
	_collect_gates(map, gates)
	for gate in gates:
		if not is_instance_valid(gate):
			continue
		var kept := gate.get_parent()
		if is_instance_valid(kept) and kept != map and not check(gate.condition, kept):
			kept.get_parent().remove_child(kept)
			kept.free()


static func _collect_gates(node: Node, found: Array[WgShowIf]) -> void:
	for child: Node in node.get_children(true):
		if child is WgShowIf:
			found.append(child)
		_collect_gates(child, found)


func _text_value(found: Variant, value_name: StringName) -> Variant:
	if found == null and _values.has(value_name):
		return _values[value_name]
	return found


static func _map_of(node: Node) -> WgMap:
	var parent := node
	while parent != null and not parent is WgMap:
		parent = parent.get_parent()
	return parent as WgMap


func _warn_once(message: String) -> void:
	if not _warned.has(message):
		_warned[message] = true
		log.warn(&"story", message)
