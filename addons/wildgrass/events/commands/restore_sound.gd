## Plays again the music and ambience a `WgEventMemorizeSound` kept.
class_name WgEventRestoreSound
extends WgEventCommand


func run(running: _Run) -> bool:
	var audio: Object = running.events.get(&"audio")
	if audio != null:
		audio.call(&"restore")
	return true
