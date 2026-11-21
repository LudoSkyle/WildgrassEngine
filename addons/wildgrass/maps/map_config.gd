## The `map` config: tile size, default fade, and the physics layers of each
## level.
class_name WgMapConfig
extends WgConfig

## Size of a tile, in game pixels.
@export var tile_size := 16
## Length of the fade transition, in seconds.
@export var fade_seconds := 0.25
## Physics layer number (1 to 32) whose polygons make a cell solid, per level.
@export var solid_layers: Array[int] = [1]
## Physics layer number (1 to 32) whose polygons are edges, per level.
@export var edge_layers: Array[int] = [4]


func _validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if tile_size < 1:
		problems.append("tile_size must be at least 1, got %d; using 16" % tile_size)
		tile_size = 16
	if fade_seconds < 0.0:
		problems.append("fade_seconds cannot be negative, got %s; using 0" % fade_seconds)
		fade_seconds = 0.0
	if not _valid_layers():
		problems.append("solid_layers and edge_layers need one layer from 1 to 32 per level, as many of each, got %s and %s; using [1] and [4]" % [solid_layers, edge_layers])
		solid_layers = [1]
		edge_layers = [4]
	return problems


func _valid_layers() -> bool:
	if solid_layers.is_empty() or solid_layers.size() != edge_layers.size():
		return false
	for layer: int in solid_layers + edge_layers:
		if layer < 1 or layer > 32:
			return false
	return true
