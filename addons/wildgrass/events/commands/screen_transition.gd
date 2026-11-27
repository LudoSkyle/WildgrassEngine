## Shows the frozen screen again: a dissolve, or through `texture` (its dark
## parts first); `seconds` 0: RPG Maker's length (20 ticks, 60 with a
## picture). The list waits until it ends, as RPG Maker's game does.
class_name WgEventScreenTransition
extends WgEventCommand

@export var texture: Texture2D
@export var seconds := 0.0


func run(running: _Run) -> bool:
	var screen: Object = running.events.get(&"screen")
	if screen == null:
		return true
	if bool(screen.call(&"is_transitioning")):
		return false
	if bool(screen.get(&"frozen")):
		screen.call(&"transition", texture, seconds)
		return not bool(screen.call(&"is_transitioning"))
	return true
