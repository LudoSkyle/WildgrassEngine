## Entries in order, each an id, a text, a callable awaited and a story
## condition: the pause menu's, the title's choices.
extends RefCounted

const _Story := preload("res://addons/wildgrass/story/story.gd")

var _story: _Story
## Each {"id", "text", "callable", "condition"}, in order.
var _entries: Array[Dictionary] = []


func _init(story: _Story) -> void:
	_story = story


## Adds an entry before `before` (the last one if it is not there). An id
## taken again replaces that entry where it stands.
func add(id: StringName, text: String, callable: Callable, condition: String, before: StringName) -> void:
	var entry := {"id": id, "text": text, "callable": callable, "condition": condition}
	var at := _index(id)
	if at >= 0:
		_entries[at] = entry
		return
	var place := _index(before)
	if place < 0:
		_entries.append(entry)
	else:
		_entries.insert(place, entry)


func remove(id: StringName) -> bool:
	var at := _index(id)
	if at < 0:
		return false
	_entries.remove_at(at)
	return true


## Every entry's id, in order.
func ids() -> Array[StringName]:
	var found: Array[StringName] = []
	for entry: Dictionary in _entries:
		found.append(entry["id"])
	return found


## The entries whose condition holds now, in order.
func shown() -> Array[Dictionary]:
	return _entries.filter(func(entry: Dictionary) -> bool: return _story.check(entry["condition"]))


func _index(id: StringName) -> int:
	for index in _entries.size():
		if _entries[index]["id"] == id:
			return index
	return -1
