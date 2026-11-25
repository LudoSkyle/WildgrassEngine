## Studio's text variables, as its scripts set them (feature 22): `[TEAM]`
## in a message is `{team}` (the importer writes it so), its value one of
## the texts service's. The Studio layer's.
extends RefCounted

var _texts: WeakRef
## The variables set, for `reset_variables()`.
var _set: Dictionary[StringName, bool] = {}


func _init(texts: Object) -> void:
	_texts = weakref(texts)


## Gives `token` (`[TEAM]`) its `value`, shown as text.
func set_variable(token: String, value: Variant) -> void:
	var texts: Object = _texts.get_ref()
	if texts == null:
		return
	var name := name_of(token)
	texts.call(&"set_value", name, str(value))
	_set[name] = true


## Takes `token`'s value back.
func unset_variable(token: String) -> void:
	var texts: Object = _texts.get_ref()
	if texts != null:
		texts.call(&"set_value", name_of(token), null)
	_set.erase(name_of(token))


## Takes back every variable set.
func reset_variables() -> void:
	var texts: Object = _texts.get_ref()
	for name: StringName in _set:
		if texts != null:
			texts.call(&"set_value", name, null)
	_set.clear()


## The placeholder `token` is in messages: `[TEAM]` is `team`.
static func name_of(token: String) -> StringName:
	return StringName(token.trim_prefix("[").trim_suffix("]").to_lower())
