## Walks to each cell of its route in turn, in a straight line (across, then
## along), and loops; waits while someone is in the way.
class_name WgPatrol
extends WgWalkerController

## Cells of its map, in order.
@export var route: Array[Vector2i] = []

var _index := 0
var _warned: Array[int] = []


func _drive(walker: WgWalker, _delta: float) -> void:
	if route.is_empty():
		return
	var walkers := walker.walkers
	var map := walkers.map_of(walker)
	for _point in route.size():
		var local := route[_index]
		if map != null and map.size != Vector2i.ZERO and not Rect2i(Vector2i.ZERO, map.size).has_point(local):
			if _index not in _warned:
				_warned.append(_index)
				walkers.log.warn(&"walking", "%s: route point %s is off its map" % [walker.name, local])
			_index = (_index + 1) % route.size()
			continue
		var target := walkers.world_cell(map, local) if map != null else local
		if walker.cell == target:
			_index = (_index + 1) % route.size()
			continue
		var offset := target - walker.cell
		var direction := Vector2i(signi(offset.x), 0) if offset.x != 0 else Vector2i(0, signi(offset.y))
		if walkers.tiles.can_step(walker.cell, direction, walker.level, walker):
			walker.step(direction)
		else:
			walker.turn(direction)
		return
