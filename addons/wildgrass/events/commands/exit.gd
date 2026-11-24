## Ends the list.
class_name WgEventExit
extends WgEventCommand


func run(running: _Run) -> bool:
	running.finish()
	return true
