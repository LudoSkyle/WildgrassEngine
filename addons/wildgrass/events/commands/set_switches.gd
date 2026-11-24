## Turns switches `first` to `last` on or off (flags `switch_<n>`).
class_name WgEventSetSwitches
extends WgEventCommand

@export var first := 1
@export var last := 1
@export var on := true


func run(running: _Run) -> bool:
	for number in range(first, last + 1):
		var flag := StringName("switch_%d" % number)
		if on:
			running.story.set_flag(flag)
		else:
			running.story.clear_flag(flag)
	return true
