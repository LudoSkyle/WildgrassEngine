## Builds a character's animations from a character sheet, as Studio and RPG
## Maker draw them: columns of steps, one row per direction. `idle_<dir>` is the
## first column, `walk_<dir>` every column.
@tool
class_name WgCharacterSprite
extends AnimatedSprite2D

## The character sheet.
@export var sheet: Texture2D:
	set(value):
		sheet = value
		_build()
## Steps per row.
@export var columns := 4:
	set(value):
		columns = maxi(value, 1)
		_build()
## The direction of each row, top first.
@export var rows_order: Array[String] = ["down", "left", "right", "up"]:
	set(value):
		rows_order = value
		_build()
## Frames per second of the walk, at the walk pace.
@export var fps := 8.0:
	set(value):
		fps = value
		_build()
## Pixels below the walker's origin where the feet stand: the bottom of its
## cell, 8 for 16-pixel cells.
@export var foot_line := 8.0:
	set(value):
		foot_line = value
		_build()


func _build() -> void:
	if sheet == null or rows_order.is_empty():
		sprite_frames = null
		return
	var size := Vector2(sheet.get_width() / float(columns), sheet.get_height() / float(rows_order.size()))
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for row in rows_order.size():
		var direction := rows_order[row]
		frames.add_animation("idle_" + direction)
		frames.add_frame("idle_" + direction, _cut(Vector2(0, row) * size, size))
		frames.add_animation("walk_" + direction)
		frames.set_animation_speed("walk_" + direction, fps)
		for column in columns:
			frames.add_frame("walk_" + direction, _cut(Vector2(column, row) * size, size))
	sprite_frames = frames
	centered = true
	offset = Vector2(0.0, foot_line - size.y / 2.0)
	animation = "idle_" + rows_order[0]


func _cut(from: Vector2, size: Vector2) -> AtlasTexture:
	var frame := AtlasTexture.new()
	frame.atlas = sheet
	frame.region = Rect2(from, size)
	return frame
