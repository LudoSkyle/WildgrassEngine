## A command of an event's list (feature 21). Lists are flat, in order:
## a block (a branch, a loop) is the commands after it at a greater `indent`.
class_name WgEventCommand
extends Resource

const _Run := preload("res://addons/wildgrass/events/event_run.gd")

@export var indent := 0


## Runs it in `running` (the list running). True: the next command runs now.
## False: the run stops until the next frame and runs this command again,
## unless it moved `running.index` itself.
func run(_running: _Run) -> bool:
	return true
