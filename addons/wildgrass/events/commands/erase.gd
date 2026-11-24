## Removes the event running the list until its map is built again.
class_name WgEventErase
extends WgEventCommand


func run(running: _Run) -> bool:
	running.erase_event()
	running.index += 1
	return false
