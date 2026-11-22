## Draws the reflections each frame once every walker has moved: processed
## last, before the frame's changes are flushed to be drawn.
extends Node

var reflections: RefCounted


func _init() -> void:
	process_priority = 1 << 20


func _process(_delta: float) -> void:
	reflections.show_all()
