## Goes back to the start of the loop at its indent.
class_name WgEventRepeat
extends WgEventCommand


func run(running: _Run) -> bool:
	running.back_to_loop(indent)
	return true
