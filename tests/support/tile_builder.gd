## A TileSet built in memory for tests, with one tile of each kind.
##
## Physics layers: 0 = level 0 solid (layer 1), 1 = level 0 edges (layer 4),
## 2 = level 1 solid (layer 2), 3 = level 1 edges (layer 5).
## Data layers: sand, water, covers, ramp, ice (bool), floor (int), jump
## (Vector2i).
extends RefCounted

const GROUND := Vector2i(0, 0)
const WALL := Vector2i(1, 0)
const SAND := Vector2i(2, 0)
const WATER := Vector2i(3, 0)
const JETTY := Vector2i(4, 0)
const TOP_EDGE := Vector2i(5, 0)
const HALF := Vector2i(6, 0)
const FLOWER := Vector2i(7, 0)
const DECK := Vector2i(8, 0)
const RAMP := Vector2i(9, 0)
## A ramp with railings on its left and right sides.
const RAILED_RAMP := Vector2i(3, 1)
const ICE := Vector2i(4, 1)
## A solid ledge jumped downward.
const LEDGE := Vector2i(5, 1)
## 3×3, centred on its cell; blocks its two lower rows.
const TREE := Vector2i(0, 1)

const FULL := [Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]


## A TileSet of `size`-pixel tiles (16 by default).
static func tile_set(size := 16) -> TileSet:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(size, size)
	for bit: int in [1, 4, 2, 5]:
		tiles.add_physics_layer()
		tiles.set_physics_layer_collision_layer(tiles.get_physics_layers_count() - 1, 1 << (bit - 1))
	for data: Array in [["sand", TYPE_BOOL], ["water", TYPE_BOOL], ["covers", TYPE_BOOL], ["ramp", TYPE_BOOL], ["floor", TYPE_INT], ["ice", TYPE_BOOL], ["jump", TYPE_VECTOR2I]]:
		tiles.add_custom_data_layer()
		tiles.set_custom_data_layer_name(tiles.get_custom_data_layers_count() - 1, data[0])
		tiles.set_custom_data_layer_type(tiles.get_custom_data_layers_count() - 1, data[1])
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(Image.create(size * 10, size * 4, false, Image.FORMAT_RGBA8))
	source.texture_region_size = Vector2i(size, size)
	for coords: Vector2i in [GROUND, WALL, SAND, WATER, JETTY, TOP_EDGE, HALF, FLOWER, DECK, RAMP, RAILED_RAMP, ICE, LEDGE]:
		source.create_tile(coords)
	source.create_tile(TREE, Vector2i(3, 3))
	tiles.add_source(source, 0)
	var k := size / 16.0
	_polygon(source, WALL, 0, FULL, k)
	_polygon(source, WATER, 0, FULL, k)
	_polygon(source, LEDGE, 0, FULL, k)
	_polygon(source, TOP_EDGE, 1, [Vector2(-8, -8), Vector2(8, -8), Vector2(8, -5), Vector2(-8, -5)], k)
	_polygon(source, HALF, 0, [Vector2(-8, -8), Vector2(0, -8), Vector2(0, 4), Vector2(-8, 4)], k)
	_polygon(source, TREE, 0, [Vector2(-24, -8), Vector2(24, -8), Vector2(24, 24), Vector2(-24, 24)], k)
	_polygon(source, DECK, 3, [Vector2(-8, -8), Vector2(-6, -8), Vector2(-6, 8), Vector2(-8, 8)], k)
	_polygon(source, DECK, 3, [Vector2(6, -8), Vector2(8, -8), Vector2(8, 8), Vector2(6, 8)], k)
	_polygon(source, RAILED_RAMP, 3, [Vector2(-8, -8), Vector2(-6, -8), Vector2(-6, 8), Vector2(-8, 8)], k)
	_polygon(source, RAILED_RAMP, 3, [Vector2(6, -8), Vector2(8, -8), Vector2(8, 8), Vector2(6, 8)], k)
	_data(source, SAND, "sand", true)
	_data(source, WATER, "water", true)
	_data(source, JETTY, "covers", true)
	_data(source, JETTY, "floor", 1)
	_data(source, DECK, "floor", 1)
	_data(source, RAMP, "floor", 1)
	_data(source, RAMP, "ramp", true)
	_data(source, RAILED_RAMP, "floor", 1)
	_data(source, RAILED_RAMP, "ramp", true)
	_data(source, ICE, "ice", true)
	_data(source, LEDGE, "jump", Vector2i.DOWN)
	return tiles


## A tile layer of `tiles` in `parent`, with `cells` (cell → atlas coords, or
## [atlas coords, alternative]).
static func layer(parent: Node, tiles: TileSet, cells: Dictionary, z := 0) -> TileMapLayer:
	var node := TileMapLayer.new()
	node.tile_set = tiles
	node.z_index = z
	for cell: Vector2i in cells:
		var spec: Variant = cells[cell]
		if spec is Array:
			node.set_cell(cell, 0, spec[0], spec[1])
		else:
			node.set_cell(cell, 0, spec)
	parent.add_child(node)
	return node


static func _polygon(source: TileSetAtlasSource, coords: Vector2i, physics: int, points: Array, scale: float) -> void:
	var tile := source.get_tile_data(coords, 0)
	var scaled := PackedVector2Array()
	for point: Vector2 in points:
		scaled.append(point * scale)
	tile.add_collision_polygon(physics)
	tile.set_collision_polygon_points(physics, tile.get_collision_polygons_count(physics) - 1, scaled)


static func _data(source: TileSetAtlasSource, coords: Vector2i, data_name: String, value: Variant) -> void:
	source.get_tile_data(coords, 0).set_custom_data(data_name, value)
