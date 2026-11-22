## Tall grass: the front strip of each tuft drawn over whoever stands in it,
## and the tuft rustling when a walker enters its cell. A tile of tall grass
## says so in its data: `front_source`, the source of its front strip (same
## atlas coordinates; 0: none), and `rustle`, the coordinates it goes
## through.
extends RefCounted

const _Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")
const _TileReader := preload("res://addons/wildgrass/life/tile_reader.gd")

## How long each state of a rustle lasts, in seconds.
var rustle_seconds := 0.07

var _tiles: Object
## Each grass layer's instance id -> [the layer, its front layer]: a map
## gone leaves freed layers, never read typed.
var _fronts: Dictionary[int, Array] = {}
## Each rustling cell: {layer, cell, frames, standing, elapsed}.
var _rustles: Array[Dictionary] = []


func _init(hooks: _Hooks, walkers: Object, tiles: Object) -> void:
	_tiles = tiles
	hooks.add(&"map_loaded", &"wildgrass_tall_grass", _on_map_loaded)
	walkers.walker_entered.connect(_on_entered)


## The front layer built for `layer`, or null.
func front_of(layer: TileMapLayer) -> TileMapLayer:
	var pair: Array = _fronts.get(layer.get_instance_id(), [])
	return pair[1] as TileMapLayer if not pair.is_empty() and is_instance_valid(pair[1]) else null


## Moves every rustle on by `delta` seconds; a rustle over puts the tuft back.
func advance(delta: float) -> void:
	var over: Array[Dictionary] = []
	for rustle in _rustles:
		if not is_instance_valid(rustle["layer"]):
			over.append(rustle)
			continue
		var layer := rustle["layer"] as TileMapLayer
		rustle["elapsed"] += delta
		var step := int(rustle["elapsed"] / rustle_seconds)
		var frames: Array = rustle["frames"]
		if step >= frames.size():
			_show(layer, rustle["cell"], rustle["standing"])
			over.append(rustle)
		else:
			_show(layer, rustle["cell"], frames[step])
	for rustle in over:
		_rustles.erase(rustle)


## Builds the front layer of each layer of `map` that has tall grass, among
## the map's y-sorted entities.
func _on_map_loaded(map: WgMap) -> void:
	var fronts: Dictionary[int, bool] = {}
	for id: int in _fronts.keys():
		if not is_instance_id_valid(id):
			_fronts.erase(id)
		elif is_instance_valid(_fronts[id][1]):
			fronts[(_fronts[id][1] as Object).get_instance_id()] = true
	for layer in _TileReader.layers_under(map):
		if _fronts.has(layer.get_instance_id()) or fronts.has(layer.get_instance_id()):
			continue
		var cells: Array[Vector2i] = []
		for cell in layer.get_used_cells():
			if int(_TileReader.read(layer, cell, "front_source", 0)) > 0:
				cells.append(cell)
		if cells.is_empty():
			continue
		var front := TileMapLayer.new()
		front.tile_set = layer.tile_set
		front.y_sort_enabled = true
		# Sorted a little below the cell's centre: a walker standing there is behind it.
		front.y_sort_origin = maxi(1, roundi(layer.tile_set.tile_size.y / 8.0))
		map.entities_node().add_child(front)
		front.global_position = layer.global_position
		for cell in cells:
			front.set_cell(cell, int(_TileReader.read(layer, cell, "front_source", 0)), layer.get_cell_atlas_coords(cell))
		_fronts[layer.get_instance_id()] = [layer, front]


## A walker in a cell of tall grass makes it rustle, unless it rustles already.
func _on_entered(walker: WgWalker, cell: Vector2i) -> void:
	if not walker.rustles or not walker.is_visible_in_tree():
		return
	var at: Vector2 = _tiles.center_of(cell)
	for pair: Array in _fronts.values():
		if not is_instance_valid(pair[0]) or not (pair[0] as Node).is_inside_tree():
			continue
		var layer := pair[0] as TileMapLayer
		var local := layer.local_to_map(layer.to_local(at))
		var frames: Variant = _TileReader.read(layer, local, "rustle", [])
		if not frames is Array or (frames as Array).is_empty():
			continue
		if _rustles.any(func(rustle: Dictionary) -> bool: return rustle["layer"] == layer and rustle["cell"] == local):
			continue
		_rustles.append({"layer": layer, "cell": local, "frames": frames, "standing": layer.get_cell_atlas_coords(local), "elapsed": 0.0})
		_show(layer, local, frames[0])


## Shows atlas coordinates `coords` on the tuft and its front strip.
func _show(layer: TileMapLayer, cell: Vector2i, coords: Vector2i) -> void:
	var source := layer.get_cell_source_id(cell)
	if source == -1:
		return
	layer.set_cell(cell, source, coords, layer.get_cell_alternative_tile(cell))
	var front := front_of(layer)
	if front != null and front.get_cell_source_id(cell) != -1:
		front.set_cell(cell, front.get_cell_source_id(cell), coords)
