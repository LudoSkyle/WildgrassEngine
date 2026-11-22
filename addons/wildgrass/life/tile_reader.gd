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
