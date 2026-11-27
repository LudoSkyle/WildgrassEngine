## Keeps the music and ambience playing, for a `WgEventRestoreSound`.
class_name WgEventMemorizeSound
extends WgEventCommand


func run(running: _Run) -> bool:
	var audio: Object = running.events.get(&"audio")
	if audio != null:
		audio.call(&"memorize")
	return true
