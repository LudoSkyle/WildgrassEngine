## Steps in one direction whenever asked; counts how often it is asked.
extends WgWalkerController

var direction := Vector2i.RIGHT
var run := false
var asked := 0


func _drive(walker: WgWalker, _delta: float) -> void:
	asked += 1
	if direction != Vector2i.ZERO:
		walker.step(direction, run)
