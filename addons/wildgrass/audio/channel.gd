## Two players taking turns: a looping sound that crossfades into the next,
## and comes back where it was if asked for again while it fades out.
extends RefCounted

## The sound asked for.
var name: StringName = &""
## The one playing and the one leaving.
var current: AudioStreamPlayer
var leaving: AudioStreamPlayer
## How loud each is, 0 to 1, before their own volume.
var level := 0.0
var leaving_level := 0.0
var leaving_name: StringName = &""

var _volume := 1.0
var _leaving_volume := 1.0


func _init(host: Node, bus: StringName) -> void:
	current = player_on(host, bus)
	leaving = player_on(host, bus)


## Starts `stream` as `sound_name`, the one playing fading out; coming back to
## the one leaving brings it up where it was; a third one cuts the one leaving.
func change(sound_name: StringName, stream: AudioStream, volume := 1.0, pitch := 1.0) -> void:
	if sound_name == name:
		return
	if not sound_name.is_empty() and sound_name == leaving_name and leaving.playing:
		var back := leaving
		leaving = current
		current = back
		var back_level := leaving_level
		leaving_level = level
		level = back_level
		var back_volume := _leaving_volume
		_leaving_volume = _volume
		_volume = back_volume
		leaving_name = name
		name = sound_name
		return
	var old := leaving
	leaving = current
	current = old
	leaving_level = level
	_leaving_volume = _volume
	leaving_name = name
	name = sound_name
	level = 0.0
	_volume = volume
	current.stop()
	current.stream = stream
	current.pitch_scale = pitch
	if stream != null:
		current.play()
	_apply()


## Moves the crossfade on by `delta` seconds over `seconds`.
func advance(delta: float, seconds: float) -> void:
	var step := delta / seconds if seconds > 0.0 else 1.0
	if current.playing:
		level = minf(level + step, 1.0)
	if leaving.playing:
		leaving_level = maxf(leaving_level - step, 0.0)
		if leaving_level <= 0.0:
			leaving.stop()
			leaving_name = &""
	_apply()


## Stops the one leaving at once.
func cut_leaving() -> void:
	leaving.stop()
	leaving_level = 0.0
	leaving_name = &""


func set_paused(paused: bool) -> void:
	current.stream_paused = paused
	leaving.stream_paused = paused


func _apply() -> void:
	current.volume_db = linear_to_db(maxf(level * _volume, 0.0001))
	leaving.volume_db = linear_to_db(maxf(leaving_level * _leaving_volume, 0.0001))


static func player_on(host: Node, bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	host.add_child(player)
	return player
