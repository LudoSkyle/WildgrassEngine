## Turns a local switch (`A` to `D`) on or off: of the event running the
## list, or of event `event` of map `map` (empty: the map the list started
## on; there, 0 is the list's own event).
class_name WgEventSetLocalSwitch
extends WgEventCommand

@export var letter := "A"
@export var on := true
@export var event := 0
@export var map: StringName = &""


func run(running: _Run) -> bool:
	running.set_local_switch(letter, on, event, map)
	return true
