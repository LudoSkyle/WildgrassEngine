## Leaves the loop it is in.
class_name WgEventBreak
extends WgEventCommand


func run(running: _Run) -> bool:
	running.leave_loop(indent)
	return true
