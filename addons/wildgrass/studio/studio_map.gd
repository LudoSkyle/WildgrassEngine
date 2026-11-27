## The map's view as Studio's scripts move it (`$game_map`, `gm`, feature
## 22): nudged at once by a distance in Studio's map units, 128 a cell. The
## Studio layer's; nothing of the engine depends on it.
extends RefCounted

## Studio's map units in a cell.
const CELL_UNITS := 128.0

var _events: WeakRef


func _init(events: Object) -> void:
	_events = weakref(events)


func scroll_up(distance: float) -> void:
	_scroll(Vector2.UP, distance)


func scroll_down(distance: float) -> void:
	_scroll(Vector2.DOWN, distance)


func scroll_left(distance: float) -> void:
	_scroll(Vector2.LEFT, distance)


func scroll_right(distance: float) -> void:
	_scroll(Vector2.RIGHT, distance)


func _scroll(direction: Vector2, distance: float) -> void:
	var events: Object = _events.get_ref()
	var screen: Object = events.get(&"screen") if events != null else null
	if screen == null:
		return
	var cell := float(events.get(&"maps").call(&"tile_size"))
	screen.call(&"scroll_by", direction * distance * cell / CELL_UNITS)
