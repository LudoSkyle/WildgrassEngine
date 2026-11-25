## Takes the player to a cell of a map: `cell` of `map` (empty: the map
## shown), or, `by_variables`, the map numbered by variable `map_variable`
## (the `map` config's `numbers`) and the cell of variables `x_variable` and
## `y_variable`; cells counted from the map's origin. It faces `direction`
## (zero: as it faces). Waits while a message is under way or a warp runs;
## the list goes on once the player has arrived.
class_name WgEventTransfer
extends WgEventCommand

@export var map: StringName = &""
@export var cell := Vector2i.ZERO
@export var by_variables := false
@export var map_variable := 0
@export var x_variable := 0
@export var y_variable := 0
@export var direction := Vector2i.ZERO
## `dissolve` (RPG Maker's fade: the last picture dissolves into the new
## one) or `none`.
@export var transition: StringName = &"dissolve"

## RPG Maker's fade: 20 ticks.
const DISSOLVE_SECONDS := 20.0 / 60.0


func run(running: _Run) -> bool:
	if running.message_busy() or running.events.get(&"maps").get(&"is_changing"):
		return false
	var target := map
	var at := cell
	if by_variables:
		var number := _variable(running, map_variable)
		target = running.events.get(&"maps").call(&"map_of_number", number)
		if target.is_empty():
			running.log.error(&"events", "no map numbered %d to transfer to: give it in the map config's numbers" % number)
			return true
		at = Vector2i(_variable(running, x_variable), _variable(running, y_variable))
	running.transfer(target, at, direction, transition, DISSOLVE_SECONDS if transition == &"dissolve" else 0.0)
	return true


static func _variable(running: _Run, number: int) -> int:
	return int(running.story.value(StringName("variable_%d" % number)))
