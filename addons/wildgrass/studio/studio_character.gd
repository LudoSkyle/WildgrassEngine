## A character as Studio's scripts see it (feature 22): its cell from its
## map's origin (`x`, `y`), its direction numbered 2, 4, 6, 8 (down, left,
## right, up). The Studio layer's; nothing of the engine depends on it.
extends RefCounted

const DIRECTIONS: Dictionary[int, Vector2i] = {2: Vector2i.DOWN, 4: Vector2i.LEFT, 6: Vector2i.RIGHT, 8: Vector2i.UP}

## The engine's character.
var walker: WgWalker
var x: int:
	get:
		return walker.cell.x - _origin().x
var y: int:
	get:
		return walker.cell.y - _origin().y
## Set as Studio sets it: at once, whatever fixes its direction.
var direction: int:
	get:
		return DIRECTIONS.find_key(walker.facing) if DIRECTIONS.values().has(walker.facing) else 2
	set(value):
		if DIRECTIONS.has(value):
			walker.facing = DIRECTIONS[value]

var _events: WeakRef


func _init(moved: WgWalker, events: Object) -> void:
	walker = moved
	_events = weakref(events)


## Puts it on cell (`to_x`, `to_y`) of its map, at once.
func moveto(to_x: int, to_y: int) -> void:
	walker.place_at(_origin() + Vector2i(to_x, to_y), walker.level)


func _origin() -> Vector2i:
	var events: Object = _events.get_ref()
	return events.call(&"map_origin_of", walker) if events != null else Vector2i.ZERO
