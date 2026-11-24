## A page of an event (feature 21): when it shows (its condition), how the
## event looks, what starts it and the commands it runs. An event shows the
## last of its pages whose condition holds.
class_name WgEventPage
extends Resource

enum Trigger {
	## The action key, facing it (or standing on it, when it can be stepped on).
	ACTION,
	## The player steps onto it, or into it when it blocks.
	TOUCH,
	## As TOUCH, and when it walks into the player.
	EVENT_TOUCH,
	## By itself, holding the player, as long as this page shows.
	AUTORUN,
	## By itself, beside the rest, as long as this page shows.
	PARALLEL,
}

## A story condition (feature 7): `switch_12`, `variable_3 >= 2`, `local:A`
## (the event's own local flag). Empty: always.
@export var condition := ""
## Its character sheet; none: nothing shows, and it never blocks.
@export var sheet: Texture2D
@export var direction := Vector2i.DOWN
## The column of the sheet it shows at rest.
@export var pattern := 0
@export_range(0.0, 1.0) var opacity := 1.0
@export var trigger := Trigger.ACTION
## Walks through and is walked through.
@export var through := false
@export var always_on_top := false
## Keeps its direction, even when talked to.
@export var fixed_direction := false
@export var walk_animation := true
## Steps in place, even at rest.
@export var step_animation := false
@export var commands: Array[WgEventCommand] = []
