## Base of the screens shown while the traveller changes map. They swallow
## every input while open.
class_name WgTransition
extends WgScreen

## Length requested by the engine, in seconds.
var seconds := 0.0


func _on_open(args: Dictionary) -> void:
	seconds = float(args.get("seconds", 0.0))


## Hides the game. Awaited by the engine.
func cover() -> void:
	pass


## Shows the game again. Awaited by the engine.
func uncover() -> void:
	pass


func _on_input(_event: InputEvent) -> bool:
	return true
