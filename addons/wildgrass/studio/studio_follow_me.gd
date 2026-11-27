## The followers' line as Studio's scripts call it (feature 22): turned off
## for a scene and back as it was. The Studio layer's; nothing of the engine
## depends on it.
extends RefCounted

## The story flag that remembers the line was on when a scene turned it off.
const WAS_ON := &"follow_me_was_on"

var _events: WeakRef


func _init(events: Object) -> void:
	_events = weakref(events)


## The line off if it is on, remembered (kept by the save).
func smart_disable() -> void:
	var followers := _followers()
	if followers == null or not bool(followers.get(&"enabled")):
		return
	_story().call(&"set_flag", WAS_ON)
	followers.set(&"enabled", false)


## The line as `smart_disable()` found it.
func smart_enable() -> void:
	var followers := _followers()
	if followers != null:
		followers.set(&"enabled", bool(_story().call(&"has", WAS_ON)))


## Nothing to do: the line follows by itself.
func update() -> void:
	pass


## The line back on the player's cell.
func reset_position() -> void:
	var followers := _followers()
	if followers != null:
		followers.call(&"put_back")


func _followers() -> Object:
	var events: Object = _events.get_ref()
	return events.get(&"followers") if events != null else null


func _story() -> Object:
	return _events.get_ref().get(&"story")
