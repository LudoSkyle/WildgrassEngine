## Tones the map toward `tone` over `seconds` (feature 21, step 2): red,
## green, blue added (-255 to 255), gray (0 to 255); zero: back to the day's
## tint. The list goes on.
class_name WgEventScreenTone
extends WgEventCommand

@export var tone := Vector4.ZERO
@export var seconds := 0.0


func run(running: _Run) -> bool:
	var screen: Object = running.events.get(&"screen")
	if screen != null:
		screen.call(&"tone_to", tone, seconds)
	return true
