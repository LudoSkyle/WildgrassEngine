## `display_config.json`: window size and fullscreen.
class_name WgDisplayConfig
extends WgConfig

## Game resolution, in game pixels.
@export var resolution := Vector2i(320, 240)
## Window size at launch, as a multiple of the resolution.
@export var window_scale := 2
@export var fullscreen := false


func _validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if resolution.x < 1 or resolution.y < 1:
		problems.append("resolution must be positive, got %s; using 320 x 240" % resolution)
		resolution = Vector2i(320, 240)
	if window_scale < 1:
		problems.append("windowScale must be at least 1, got %d; using 1" % window_scale)
		window_scale = 1
	return problems
