## A screen that records what the engine calls on it.
extends WgScreen

var opened_with: Dictionary = {}
var close_calls := 0
var inputs: Array[InputEvent] = []


func _on_open(args: Dictionary) -> void:
	opened_with = args


func _on_close() -> void:
	close_calls += 1


func _on_input(event: InputEvent) -> bool:
	inputs.append(event)
	return true
