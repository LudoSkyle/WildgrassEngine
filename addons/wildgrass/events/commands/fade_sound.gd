## Fades the music or the ambience out over `seconds` (0: at once). The list
## goes on.
class_name WgEventFadeSound
extends WgEventCommand

enum Kind { MUSIC, AMBIENCE }

@export var kind := Kind.MUSIC
@export var seconds := 0.0


func run(running: _Run) -> bool:
	var audio: Object = running.events.get(&"audio")
	if audio != null:
		audio.call(&"fade_music" if kind == Kind.MUSIC else &"fade_ambience", seconds)
	return true
