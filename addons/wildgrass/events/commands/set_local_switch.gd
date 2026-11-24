## Turns a local switch of the event running the list on or off: its local
## flag `A` to `D`.
class_name WgEventSetLocalSwitch
extends WgEventCommand

@export var letter := "A"
@export var on := true


func run(running: _Run) -> bool:
	running.set_local_switch(letter, on)
	return true
