## A door: warps the traveller to a point of a map. Never blocks. Also an
## arrival point for other doors.
class_name WgDoor
extends Area2D

enum Kind {
	## Used by walking onto it. Arrival: one tile away along `direction`.
	CONTACT,
	## Used by walking off it in `direction`. Arrival: on it, facing back.
	EXIT,
}

## Map id; empty means this map.
@export var target_map: StringName = &""
## Name of a door or spawn point in the target map.
@export var target_door: StringName = &""
@export var kind := Kind.CONTACT
## Contact: where you arrive and face. Exit: the way out.
@export var direction := Vector2i.DOWN
## Name of the transition screen, without its `transition_` prefix.
@export var transition: StringName = &"fade"
