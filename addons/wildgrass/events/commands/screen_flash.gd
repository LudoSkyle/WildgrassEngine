## Flashes `color` over the map and the pictures, fading over `seconds`. The
## list goes on.
class_name WgEventScreenFlash
extends WgEventCommand

@export var color := Color.WHITE
@export var seconds := 0.0


func run(running: _Run) -> bool:
	var screen: Object = running.events.get(&"screen")
	if screen != null:
		screen.call(&"flash", color, seconds)
	return true
