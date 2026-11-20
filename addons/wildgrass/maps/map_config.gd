## `map_config.json`: tile size and default fade.
class_name WgMapConfig
extends WgConfig

## Size of a tile, in game pixels.
@export var tile_size := 16
## Length of the fade transition, in seconds.
@export var fade_seconds := 0.25


func _validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if tile_size < 1:
		problems.append("tileSize must be at least 1, got %d; using 16" % tile_size)
		tile_size = 16
	if fade_seconds < 0.0:
		problems.append("fadeSeconds cannot be negative, got %s; using 0" % fade_seconds)
		fade_seconds = 0.0
	return problems
