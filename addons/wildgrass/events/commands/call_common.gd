## Runs a common event's list, then goes on.
class_name WgEventCallCommon
extends WgEventCommand

## Its number: `res://common_events/<number>.tres`.
@export var common_event := 0


func run(running: _Run) -> bool:
	running.call_common(common_event)
	return true
