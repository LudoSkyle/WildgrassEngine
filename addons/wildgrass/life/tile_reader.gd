## Reads the tile data of one layer's cell, the way life on the maps needs:
## the tile itself, not the first that sets the data.
extends RefCounted


## The data `data_name` of the tile at `cell` of `layer`; `fallback` if the
## cell is empty or the TileSet has no such data.
static func read(layer: TileMapLayer, cell: Vector2i, data_name: String, fallback: Variant = null) -> Variant:
	if layer.tile_set == null or not layer.tile_set.has_custom_data_layer_by_name(data_name):
		return fallback
	var data := layer.get_cell_tile_data(cell)
	return data.get_custom_data(data_name) if data != null else fallback


## Every tile layer under `node`, itself included.
static func layers_under(node: Node) -> Array[TileMapLayer]:
	var found: Array[TileMapLayer] = []
	if node is TileMapLayer:
		found.append(node)
	for child in node.get_children():
		found.append_array(layers_under(child))
	return found


## The layer under `node` drawn on top at `point` (global) among those with a
## tile there: the highest `z_index`, the last in the tree between equals;
## null if none.
static func top_at(node: Node, point: Vector2) -> TileMapLayer:
	return top_in(layers_under(node), point)


## The layer of `layers` drawn on top at `point`, as `top_at()`.
static func top_in(layers: Array[TileMapLayer], point: Vector2) -> TileMapLayer:
	var top: TileMapLayer = null
	for layer in layers:
		if layer.get_cell_source_id(layer.local_to_map(layer.to_local(point))) != -1 and (top == null or layer.z_index >= top.z_index):
			top = layer
	return top


## The data `data_name` of the tile drawn on top at `point` under `node`.
static func top_data(node: Node, point: Vector2, data_name: String, fallback: Variant = null) -> Variant:
	var layer := top_at(node, point)
	return read(layer, layer.local_to_map(layer.to_local(point)), data_name, fallback) if layer != null else fallback
