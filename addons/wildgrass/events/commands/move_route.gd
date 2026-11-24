## Has a character follow a route now (-1 the player, 0 this event, a
## number an event of its map); its own way of moving waits until it ends.
class_name WgEventMoveRoute
extends WgEventCommand

@export var character := 0
@export var route: WgMoveRoute


func run(running: _Run) -> bool:
	var walker := running.character(character)
	if walker != null and route != null:
		running.events.call(&"force_route", walker, route)
	return true
