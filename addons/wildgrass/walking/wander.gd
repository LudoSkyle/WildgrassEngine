## Wanders: after each pause, turns to a random direction and, most of the
## time, steps that way, never leaving its map, its area or its tiles, never
## onto a ledge or ice.
class_name WgWander
extends WgWalkerController

## Seconds between two gestures, at least and at most.
@export var pause := Vector2(1.0, 3.0)
## How often a gesture is a step, not only a turn.
@export_range(0.0, 1.0) var step_chance := 0.7
## Cells of its map it stays in; empty: anywhere.
@export var area := Rect2i()
## Tile data it stays on (`&"grass"`); empty: any tile.
@export var tile_data: StringName = &""
## Seed of its moves, for a wander that plays the same again; 0: random.
@export var random_seed := 0

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var _random := RandomNumberGenerator.new()
var _wait := -1.0


func _ready() -> void:
	if random_seed != 0:
		_random.seed = random_seed


func _drive(walker: WgWalker, delta: float) -> void:
	if _wait < 0.0:
		_wait = _random.randf_range(pause.x, pause.y)
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = _random.randf_range(pause.x, pause.y)
	var direction := DIRECTIONS[_random.randi_range(0, 3)]
	walker.turn(direction)
	if _random.randf() < step_chance and _allowed(walker, direction):
		walker.step(direction)


func _allowed(walker: WgWalker, direction: Vector2i) -> bool:
	var walkers := walker.walkers
	var tiles := walkers.tiles
	var cell := walker.cell + direction
	var jump: Variant = tiles.data(cell, &"jump")
	if tiles.data(cell, &"ice") == true or (jump is Vector2i and jump != Vector2i.ZERO):
		return false
	if not tiles.can_step(walker.cell, direction, walker.level, walker):
		return false
	var map := walkers.map_of(walker)
	if map != null:
		var local := cell - walkers.world_cell(map, Vector2i.ZERO)
		if map.size != Vector2i.ZERO and not Rect2i(Vector2i.ZERO, map.size).has_point(local):
			return false
		if area.has_area() and not area.has_point(local):
			return false
	return tile_data.is_empty() or _is_true(tiles.data(cell, tile_data))


static func _is_true(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return value
		TYPE_INT, TYPE_FLOAT:
			return value != 0
		TYPE_STRING, TYPE_STRING_NAME:
			return not str(value).is_empty()
	return true
