## Goes on from the first `WgEventLabel` of that name; none: goes on.
class_name WgEventJump
extends WgEventCommand

@export var label := ""


func run(running: _Run) -> bool:
	running.jump_to(label)
	return true
