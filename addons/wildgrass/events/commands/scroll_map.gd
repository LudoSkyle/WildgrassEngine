## Scrolls the view `cells` cells toward `direction` at RPG Maker's `speed`
## (1 to 6), held within the map; it stays there until a scroll brings it
## back. Waits for a scroll under way first, then the list goes on.
class_name WgEventScrollMap
extends WgEventCommand

@export var direction := Vector2i.DOWN
@export var cells := 1
@export_range(1, 6) var speed := 4


func run(running: _Run) -> bool:
	var screen: Object = running.events.get(&"screen")
	if screen == null:
		return true
	if bool(screen.call(&"is_scrolling")):
		return false
	screen.call(&"scroll", direction, cells, speed)
	return true
