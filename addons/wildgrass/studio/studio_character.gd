## A character as Studio's scripts see it (feature 22): its cell from its
## map's origin (`x`, `y`), its direction numbered 2, 4, 6, 8 (down, left,
## right, up), how far it shows from its cell and its shadow (Studio's
## screen units, 32 a cell). The Studio layer's; nothing of the engine
## depends on it.
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

## How far it shows from its cell (`offset_screen_x`, `offset_screen_y`) and
## its shadow (`offset_shadow_screen_x`, `offset_shadow_screen_y`), in
## Studio's screen units; set to `null`, 0.
var offset_screen_x: Variant:
	get:
		return _units(walker.look_offset.x)
	set(value):
		walker.look_offset.x = _pixels(value)
var offset_screen_y: Variant:
	get:
		return _units(walker.look_offset.y)
	set(value):
		walker.look_offset.y = _pixels(value)
var offset_shadow_screen_x: Variant:
	get:
		return _units(walker.shadow_offset.x)
	set(value):
		walker.shadow_offset.x = _pixels(value)
var offset_shadow_screen_y: Variant:
	get:
		return _units(walker.shadow_offset.y)
	set(value):
		walker.shadow_offset.y = _pixels(value)
var shadow_disabled: bool:
	get:
		return not walker.shadow_shown
	set(value):
		walker.shadow_shown = not value

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


## Studio lets go of the characters following this one: the player's line
## is put back on its cell; no event leads a line.
func reset_follower() -> void:
	var events: Object = _events.get_ref()
	var followers: Object = events.get(&"followers") if events != null else null
	if followers != null and walker == events.get(&"maps").get(&"traveller"):
		followers.call(&"put_back")


## Nothing: the engine has no bike yet, the player never rides.
func leave_cycling_state() -> void:
	pass


## Game pixels a Studio screen unit is: a cell is 32 of them.
func _unit() -> float:
	var events: Object = _events.get_ref()
	var maps: Object = events.get(&"maps") if events != null else null
	return (float(maps.call(&"tile_size")) if maps != null else 16.0) / 32.0


func _units(pixels: float) -> int:
	return roundi(pixels / _unit())


func _pixels(units: Variant) -> float:
	return float(units) * _unit() if units != null else 0.0
