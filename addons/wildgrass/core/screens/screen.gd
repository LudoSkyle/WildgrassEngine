## Base of every screen the engine opens. Override the `_on_…` methods.
class_name WgScreen
extends Control

## Emitted once, when the screen closes.
signal closed

## The name it was opened under.
var screen_name: StringName

var _closed := false


## Called right after the screen is added, with the arguments given to `open()`.
func _on_open(_args: Dictionary) -> void:
	pass


## Called just before the screen is removed.
func _on_close() -> void:
	pass


## Input for the top screen only. Return true if handled.
func _on_input(_event: InputEvent) -> bool:
	return false


func is_closed() -> bool:
	return _closed


func close() -> void:
	if _finish():
		queue_free()


## A screen freed or removed from the tree without `close()` still closes.
func _exit_tree() -> void:
	_finish()


func _finish() -> bool:
	if _closed:
		return false
	_closed = true
	_on_close()
	closed.emit()
	return true
