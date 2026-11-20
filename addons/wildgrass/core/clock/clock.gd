## Game time: advances with the game, not the wall clock.
extends RefCounted

const SHADER_GLOBAL := &"game_time"

## Elapsed game time, in seconds.
var seconds: float:
	get:
		return _seconds

## Game speed, shared with every `_process(delta)` (`Engine.time_scale`).
var speed: float:
	get:
		return Engine.time_scale
	set(value):
		Engine.time_scale = maxf(value, 0.0)

## Keeps the `game_time` shader global up to date; set once it is declared.
var updates_shader_global := false

var _seconds := 0.0


func msec() -> int:
	return int(_seconds * 1000.0)


## Called once per frame with the frame's delta. Negative deltas are ignored.
func advance(delta: float) -> void:
	_seconds += maxf(delta, 0.0)
	if updates_shader_global:
		_set_shader_global(_seconds)


func _set_shader_global(value: float) -> void:
	RenderingServer.global_shader_parameter_set(SHADER_GLOBAL, value)


## Declares the `game_time` shader global if the project does not. Project
## globals are loaded at start; the server's own list is for the editor only.
static func declare_shader_global() -> void:
	if not ProjectSettings.has_setting("shader_globals/" + SHADER_GLOBAL):
		RenderingServer.global_shader_parameter_add(SHADER_GLOBAL, RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
