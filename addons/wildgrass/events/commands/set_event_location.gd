## Puts a character at once on a cell of its map, counted from the map's
## origin: `cell`, the cell of variables `x_variable` and `y_variable`, or
## the cell of character `other`, who takes its place. Then it faces
## `direction` (zero: as it was).
class_name WgEventSetEventLocation
extends WgEventCommand

enum Mode { CELL, VARIABLES, SWAP }

## -1 the player, 0 the event running the list, else an event of its map.
@export var character := 0
@export var mode := Mode.CELL
@export var cell := Vector2i.ZERO
@export var x_variable := 0
@export var y_variable := 0
@export var other := 0
@export var direction := Vector2i.ZERO


func run(running: _Run) -> bool:
	var moved := running.character(character)
	if moved == null:
		return true
	var origin: Vector2i = running.events.call(&"map_origin_of", moved)
	match mode:
		Mode.CELL:
			moved.place_at(origin + cell, moved.level)
		Mode.VARIABLES:
			var at := Vector2i(int(running.story.value(StringName("variable_%d" % x_variable))), int(running.story.value(StringName("variable_%d" % y_variable))))
			moved.place_at(origin + at, moved.level)
		Mode.SWAP:
			var partner := running.character(other)
			if partner != null:
				var was := moved.cell
				var was_level := moved.level
				moved.place_at(partner.cell, partner.level)
				partner.place_at(was, was_level)
	if direction != Vector2i.ZERO:
		moved.turn(direction)
	return true
