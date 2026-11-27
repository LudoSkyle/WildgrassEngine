## Stops every effect playing.
class_name WgEventStopEffects
extends WgEventCommand


func run(running: _Run) -> bool:
	var audio: Object = running.events.get(&"audio")
	if audio != null:
		audio.call(&"stop_effects")
	return true
