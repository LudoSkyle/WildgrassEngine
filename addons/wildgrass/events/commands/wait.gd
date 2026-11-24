## Waits, the player held as for any command.
class_name WgEventWait
extends WgEventCommand

@export var seconds := 0.0


func run(running: _Run) -> bool:
	running.wait_left = seconds
	return true
