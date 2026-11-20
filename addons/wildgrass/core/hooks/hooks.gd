## Named, ordered extension points. Handlers run by priority (lowest first),
## then in the order they were first added. Adding a handler under an existing
## name replaces it in place.
extends RefCounted

## event -> entries {"name": StringName, "callable": Callable, "priority": int, "order": int}
var _events: Dictionary[StringName, Array] = {}
var _next_order := 0


func add(event: StringName, handler_name: StringName, callable: Callable, priority := 0) -> void:
	var entries: Array = _events.get_or_add(event, [])
	for entry: Dictionary in entries:
		if entry["name"] == handler_name:
			entry["callable"] = callable
			entry["priority"] = priority
			return
	entries.append({"name": handler_name, "callable": callable, "priority": priority, "order": _next_order})
	_next_order += 1


## Returns false if there was no such handler.
func remove(event: StringName, handler_name: StringName) -> bool:
	var entries: Array = _events.get(event, [])
	for index in entries.size():
		if entries[index]["name"] == handler_name:
			entries.remove_at(index)
			return true
	return false


func has(event: StringName, handler_name: StringName) -> bool:
	return names(event).has(handler_name)


## Handler names of an event, in run order.
func names(event: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for entry: Dictionary in _sorted(event):
		result.append(entry["name"])
	return result


## Calls every handler with `args`. Handlers whose object was freed are dropped.
func run(event: StringName, args: Array = []) -> void:
	for entry: Dictionary in _sorted(event):
		var callable: Callable = entry["callable"]
		if callable.is_valid():
			callable.callv(args)
		else:
			remove(event, entry["name"])


## Passes `value` through every handler; each receives it first, then `args`,
## and returns the new value.
func filter(event: StringName, value: Variant, args: Array = []) -> Variant:
	for entry: Dictionary in _sorted(event):
		var callable: Callable = entry["callable"]
		if callable.is_valid():
			value = callable.callv([value] + args)
		else:
			remove(event, entry["name"])
	return value


## A snapshot, so handlers may add or remove handlers while running.
func _sorted(event: StringName) -> Array:
	var entries: Array = _events.get(event, []).duplicate()
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["priority"] < b["priority"] or (a["priority"] == b["priority"] and a["order"] < b["order"]))
	return entries
