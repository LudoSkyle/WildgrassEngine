## Where the next messages show, and whether with their frame (`style`
## `transparent` without: the game's theme draws it).
class_name WgEventTextOptions
extends WgEventCommand

enum Place { TOP, MIDDLE, BOTTOM }

@export var place := Place.BOTTOM
@export var frame := true


func run(running: _Run) -> bool:
	if running.message_busy():
		return false
	running.events.set(&"message_place", ["top", "middle", "bottom"][place])
	running.events.set(&"message_frame", frame)
	return true
