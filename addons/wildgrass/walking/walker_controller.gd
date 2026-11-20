## Decides what a walker does next. A child of the walker; the player's input
## is one, characters' behaviours are others.
class_name WgWalkerController
extends Node


## Called every frame while `walker` is free to act, and again at once when a
## step ends during a frame: `delta` is then the time left in that frame.
## Start a step, turn, or do nothing.
func _drive(_walker: WgWalker, _delta: float) -> void:
	pass
