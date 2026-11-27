## Holds what shows still, until a `WgEventScreenTransition`; waits for a
## message under way first, as RPG Maker's.
class_name WgEventFreezeScreen
extends WgEventCommand


func run(running: _Run) -> bool:
	if running.message_busy():
		return false
	var screen: Object = running.events.get(&"screen")
	if screen != null:
		screen.call(&"freeze")
	return true
