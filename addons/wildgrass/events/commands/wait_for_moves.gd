## Waits until every route a command imposed has ended.
class_name WgEventWaitForMoves
extends WgEventCommand


func run(running: _Run) -> bool:
	return not bool(running.events.call(&"any_forced_route"))
