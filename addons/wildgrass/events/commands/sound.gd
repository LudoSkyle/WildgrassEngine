## Plays a sound (feature 15): music and ambience crossfaded, a jingle that
## pauses the music (the list does not wait for it), an effect over
## everything. The list goes on.
class_name WgEventSound
extends WgEventCommand

enum Kind { MUSIC, AMBIENCE, JINGLE, EFFECT }

@export var kind := Kind.EFFECT
## Its name in its kind's folder; empty: the music or ambience stops, a
## jingle or an effect plays nothing.
@export var sound: StringName = &""
@export var volume := 1.0
@export var pitch := 1.0


func run(running: _Run) -> bool:
	var audio: Object = running.events.get(&"audio")
	if audio == null:
		return true
	match kind:
		Kind.MUSIC:
			audio.call(&"play_music", sound, volume, pitch)
		Kind.AMBIENCE:
			audio.call(&"play_ambience", sound, volume, pitch)
		Kind.JINGLE:
			if not sound.is_empty():
				audio.call(&"jingle", sound, volume, pitch)
		Kind.EFFECT:
			if not sound.is_empty():
				audio.call(&"effect", sound, volume, pitch)
	return true
