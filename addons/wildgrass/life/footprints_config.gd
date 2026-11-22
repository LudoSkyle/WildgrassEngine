## The `footprints` config: how prints look and fade.
class_name WgFootprintsConfig
extends WgConfig

## A picture of eight cells side by side, one per direction (down, left,
## right, up) and foot; empty: a dark oval made in code.
@export var texture := ""
## A cell's size in the picture, in pixels.
@export var cell := 8
## How long a print lasts, in seconds; it fades over its second half.
@export var life_seconds := 1.0
## How much a print darkens the ground, 0 to 1.
@export var darkness := 0.26


func _validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if life_seconds <= 0.0:
		problems.append("life_seconds must be positive, got %s; using 1" % life_seconds)
		life_seconds = 1.0
	if darkness < 0.0 or darkness > 1.0:
		problems.append("darkness must be from 0 to 1, got %s; using 0.26" % darkness)
		darkness = 0.26
	return problems
