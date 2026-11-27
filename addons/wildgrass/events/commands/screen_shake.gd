## Shakes the map sideways, `power` and `speed` 1 to 9, for `seconds`. The
## list goes on.
class_name WgEventScreenShake
extends WgEventCommand

@export_range(1, 9) var power := 5
@export_range(1, 9) var speed := 5
@export var seconds := 0.0


func run(running: _Run) -> bool:
	var screen: Object = running.events.get(&"screen")
	if screen != null:
		screen.call(&"shake_screen", power, speed, seconds)
	return true
