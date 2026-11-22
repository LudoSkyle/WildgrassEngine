## A species' `character` sheet, one frame at a time, turning a quarter a
## second (down, left, up, right), drawn at `scale_by` screen pixels a
## picture pixel on a checkerboard of picture pixels, with the axes of its
## cell: whether it is centred shows.
extends Control

## The rows of a sheet, top first, and the order they turn in.
const ROWS: Array[String] = ["down", "left", "right", "up"]
const TURN: Array[String] = ["down", "left", "up", "right"]
const COLUMNS := 4
const QUARTERS_PER_SECOND := 1.0
const LIGHT := Color(0.85, 0.85, 0.85)
const DARK := Color(0.7, 0.7, 0.7)
const AXIS := Color(0.9, 0.2, 0.2, 0.8)

## Screen pixels a picture pixel.
var scale_by := 2.0
var sheet: Texture2D:
	set(value):
		sheet = value
		custom_minimum_size = frame().size * scale_by
		queue_redraw()

var _clock := 0.0


## The direction shown now.
func facing() -> String:
	return TURN[int(floor(_clock * QUARTERS_PER_SECOND)) % TURN.size()]


## The frame shown now, in the sheet.
func frame() -> Rect2:
	if sheet == null:
		return Rect2()
	var size := Vector2(sheet.get_width() / float(COLUMNS), sheet.get_height() / float(ROWS.size()))
	return Rect2(Vector2(0, ROWS.find(facing()) * size.y), size)


func advance(delta: float) -> void:
	var before := facing()
	_clock += delta
	if facing() != before:
		queue_redraw()


## Back to facing down.
func restart() -> void:
	_clock = 0.0
	queue_redraw()


func _draw() -> void:
	if sheet == null:
		return
	var cut := frame()
	var drawn := cut.size * scale_by
	for y in int(cut.size.y):
		for x in int(cut.size.x):
			draw_rect(Rect2(Vector2(x, y) * scale_by, Vector2.ONE * scale_by), LIGHT if (x + y) % 2 == 0 else DARK)
	draw_texture_rect_region(sheet, Rect2(Vector2.ZERO, drawn), cut)
	draw_line(Vector2(drawn.x / 2.0, 0.0), Vector2(drawn.x / 2.0, drawn.y), AXIS)
	draw_line(Vector2(0.0, drawn.y / 2.0), Vector2(drawn.x, drawn.y / 2.0), AXIS)
