## Shows, moves, turns, tones or erases picture `number` (1 to 50) over the
## map (feature 21, step 2). The list goes on.
class_name WgEventPicture
extends WgEventCommand

enum Action { SHOW, MOVE, ROTATE, TONE, ERASE }
const _Screen := preload("res://addons/wildgrass/screen/screen.gd")

@export var action := Action.SHOW
@export_range(1, 50) var number := 1
## `SHOW`: what it shows.
@export var texture: Texture2D
## `SHOW`, `MOVE`: how it stands and where it goes.
@export var origin := _Screen.Origin.TOP_LEFT
## Game pixels from the screen's top-left.
@export var position := Vector2.ZERO
## True: the position is variables `x_variable` and `y_variable`.
@export var by_variables := false
@export var x_variable := 0
@export var y_variable := 0
## Percent.
@export var zoom := Vector2(100, 100)
@export_range(0, 255) var opacity := 255.0
@export var blend := _Screen.Blend.NORMAL
## `MOVE`, `TONE`: how long it takes.
@export var seconds := 0.0
## `ROTATE`: `speed / 2` degrees a tick, as RPG Maker's.
@export var speed := 0.0
## `TONE`: red, green, blue, gray.
@export var tone := Vector4.ZERO


func run(running: _Run) -> bool:
	var screen: Object = running.events.get(&"screen")
	if screen == null:
		return true
	var at := position
	if by_variables:
		at = Vector2(float(running.story.value(StringName("variable_%d" % x_variable))), float(running.story.value(StringName("variable_%d" % y_variable))))
	var options := {"origin": origin, "position": at, "zoom": zoom, "opacity": opacity, "blend": blend}
	match action:
		Action.SHOW:
			screen.call(&"show_picture", number, texture, options)
		Action.MOVE:
			screen.call(&"move_picture", number, seconds, options)
		Action.ROTATE:
			screen.call(&"rotate_picture", number, speed)
		Action.TONE:
			screen.call(&"tone_picture", number, tone, seconds)
		Action.ERASE:
			screen.call(&"erase_picture", number)
	return true
