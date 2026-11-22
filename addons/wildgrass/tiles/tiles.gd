## What a cell is made of: what blocks it on each level, the edges between
## cells, and named tile data. Read straight from the TileSets of the maps
## shown.
extends RefCounted

const _Log := preload("res://addons/wildgrass/core/log/log.gd")
const _ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const _Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")
const _Maps := preload("res://addons/wildgrass/maps/maps.gd")

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
## Edges are looked for this far on each side of a border, in pixels.
const EDGE_PROBE := 2.0
## Tile data that hides the data of the tiles below.
const COVERS := &"covers"

var _log: _Log
var _config: _ConfigRegistry
var _hooks: _Hooks
var _maps: _Maps
## TileSet -> how many cells away a tile's polygons can reach. Emptied when a
## map leaves, so TileSets are not kept alive.
var _reach: Dictionary[TileSet, int] = {}


func _init(logger: _Log, config: _ConfigRegistry, hooks: _Hooks, maps: _Maps) -> void:
	_log = logger
	_config = config
	_hooks = hooks
	_maps = maps
	_hooks.add(&"map_leaving", &"wildgrass_tiles", _forget_reach)


## The side of a cell, in pixels.
func tile_size() -> int:
	return _tile_size()


## The world cell holding `global_position`.
func cell_of(global_position: Vector2) -> Vector2i:
	return Vector2i((global_position / _tile_size()).floor())


## The global position of the centre of `cell`.
func center_of(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * _tile_size()


## True if a tile's solid polygon covers the centre of `cell` on `level`, or
## if no map is shown there.
func is_solid(cell: Vector2i, level := 0) -> bool:
	if not _has_level(level):
		return true
	var point := center_of(cell)
	var map := _maps.map_at(point)
	return map == null or _covered(map, point, _config_of().solid_layers[level])


## True if an edge stands on `level` between `cell` and the next cell in
## `direction`.
func has_edge(cell: Vector2i, direction: Vector2i, level := 0) -> bool:
	if not _valid_direction(direction) or not _has_level(level):
		return false
	var layer: int = _config_of().edge_layers[level]
	var border := center_of(cell) + Vector2(direction) * _tile_size() * 0.5
	for point: Vector2 in [border - Vector2(direction) * EDGE_PROBE, border + Vector2(direction) * EDGE_PROBE]:
		var map := _maps.map_at(point)
		if map != null and _covered(map, point, layer):
			return true
	return false


## True if a walker on `level` can step from `cell` into the next cell in
## `direction`: a map is shown there, with a floor on the level the walker
## ends on, nothing solid, no edge between on either level; then the
## `can_step` filter hook has its say.
func can_step(cell: Vector2i, direction: Vector2i, level := 0, walker: Node = null) -> bool:
	if not _valid_direction(direction) or not _has_level(level):
		return false
	var target := cell + direction
	var next := level_after(cell, direction, level)
	var allowed: bool = _maps.map_at(center_of(target)) != null \
		and _has_level(next) \
		and (next == 0 or data(target, &"floor") == next) \
		and not is_solid(target, next) \
		and not has_edge(cell, direction, level) \
		and (next == level or not has_edge(cell, direction, next))
	return bool(_hooks.filter(&"can_step", allowed, [cell, direction, level, walker]))


## The level of a walker on `level` once it steps from `cell` in `direction`.
## Stepping onto a ramp takes it to the ramp's floor; stepping off a ramp onto
## a cell without that floor takes it back to the ground.
func level_after(cell: Vector2i, direction: Vector2i, level := 0) -> int:
	var target := cell + direction
	if data(target, &"ramp") == true:
		var up: Variant = data(target, &"floor")
		return up if up is int and up > 0 else level
	if level > 0 and data(cell, &"ramp") == true and data(target, &"floor") != level:
		return 0
	return level


## The tile data `data_name` of `cell`: the first tile from the top that sets
## it (a value other than its type's default) decides; a tile that sets
## `covers` hides the tiles below. Unset: the type's default, or null if no
## TileSet of the cell has that data.
func data(cell: Vector2i, data_name: StringName) -> Variant:
	var point := center_of(cell)
	var map := _maps.map_at(point)
	if map == null:
		return null
	var fallback: Variant = null
	var known := false
	for layer: TileMapLayer in _layers_from_top(map):
		var tile := layer.get_cell_tile_data(layer.local_to_map(layer.to_local(point)))
		if tile == null:
			continue
		var index := layer.tile_set.get_custom_data_layer_by_name(data_name)
		if index != -1:
			var default: Variant = type_convert(null, layer.tile_set.get_custom_data_layer_type(index))
			if not known:
				known = true
				fallback = default
			var value: Variant = tile.get_custom_data_by_layer_id(index)
			if value != default:
				return value
		if layer.tile_set.get_custom_data_layer_by_name(COVERS) != -1:
			var covers: Variant = tile.get_custom_data(COVERS)
			if covers is bool and covers:
				break
	return fallback


func _covered(map: WgMap, point: Vector2, layer_number: int) -> bool:
	var bit := 1 << (layer_number - 1)
	for layer: TileMapLayer in _layers_from_top(map):
		if layer.collision_enabled and _layer_covers(layer, point, bit):
			return true
	return false


## True if a polygon of `layer`, on a physics layer with `bit`, covers `point`.
func _layer_covers(layer: TileMapLayer, point: Vector2, bit: int) -> bool:
	var tile_set := layer.tile_set
	var physics: Array[int] = []
	for index in tile_set.get_physics_layers_count():
		if tile_set.get_physics_layer_collision_layer(index) & bit:
			physics.append(index)
	if physics.is_empty():
		return false
	var local := layer.to_local(point)
	var center := layer.local_to_map(local)
	var reach := _reach_of(tile_set)
	for x in range(center.x - reach, center.x + reach + 1):
		for y in range(center.y - reach, center.y + reach + 1):
			var anchor := Vector2i(x, y)
			var tile := layer.get_cell_tile_data(anchor)
			if tile == null:
				continue
			var at := _untransform(local - layer.map_to_local(anchor), layer.get_cell_alternative_tile(anchor))
			for index: int in physics:
				for polygon in tile.get_collision_polygons_count(index):
					if Geometry2D.is_point_in_polygon(at, tile.get_collision_polygon_points(index, polygon)):
						return true
	return false


## `offset` seen from the untransformed tile of a flipped or turned cell.
static func _untransform(offset: Vector2, alternative: int) -> Vector2:
	var result := offset
	if alternative & TileSetAtlasSource.TRANSFORM_FLIP_V:
		result.y = -result.y
	if alternative & TileSetAtlasSource.TRANSFORM_FLIP_H:
		result.x = -result.x
	if alternative & TileSetAtlasSource.TRANSFORM_TRANSPOSE:
		result = Vector2(result.y, result.x)
	return result


func _forget_reach(_map: WgMap) -> void:
	_reach.clear()


## How many cells away from its own the polygons of a tile of `tile_set` can
## reach: tiles of several cells reach their neighbours.
func _reach_of(tile_set: TileSet) -> int:
	if _reach.has(tile_set):
		return _reach[tile_set]
	var extent := 0.0
	for source_index in tile_set.get_source_count():
		var source := tile_set.get_source(tile_set.get_source_id(source_index)) as TileSetAtlasSource
		if source == null:
			continue
		for tile_index in source.get_tiles_count():
			var coords := source.get_tile_id(tile_index)
			for alternative_index in source.get_alternative_tiles_count(coords):
				var tile := source.get_tile_data(coords, source.get_alternative_tile_id(coords, alternative_index))
				for physics in tile_set.get_physics_layers_count():
					for polygon in tile.get_collision_polygons_count(physics):
						for vertex: Vector2 in tile.get_collision_polygon_points(physics, polygon):
							extent = maxf(extent, maxf(absf(vertex.x), absf(vertex.y)))
	var cell := float(mini(tile_set.tile_size.x, tile_set.tile_size.y))
	var reach := maxi(0, ceili(extent / cell - 0.5))
	_reach[tile_set] = reach
	return reach


## The tile layers of `map`, top first: highest effective z_index, then last in
## the tree.
static func _layers_from_top(map: WgMap) -> Array[TileMapLayer]:
	var found: Array[TileMapLayer] = []
	_collect_layers(map, found)
	var order: Dictionary[TileMapLayer, int] = {}
	for index in found.size():
		order[found[index]] = index
	found.sort_custom(func(a: TileMapLayer, b: TileMapLayer) -> bool:
		var za := _effective_z(a)
		var zb := _effective_z(b)
		return za > zb if za != zb else order[a] > order[b])
	return found


static func _collect_layers(node: Node, found: Array[TileMapLayer]) -> void:
	for child: Node in node.get_children():
		if child is TileMapLayer and (child as TileMapLayer).enabled and (child as TileMapLayer).tile_set != null:
			found.append(child)
		_collect_layers(child, found)


static func _effective_z(item: CanvasItem) -> int:
	var z := item.z_index
	var node := item
	while node.z_as_relative and node.get_parent() is CanvasItem:
		node = node.get_parent()
		z += node.z_index
	return z


func _valid_direction(direction: Vector2i) -> bool:
	if direction in DIRECTIONS:
		return true
	_log.error(&"tiles", "%s is not up, down, left or right" % direction)
	return false


func _has_level(level: int) -> bool:
	if level >= 0 and level < _config_of().solid_layers.size():
		return true
	_log.error(&"tiles", "no level %d in the map config" % level)
	return false


func _config_of() -> WgMapConfig:
	return _config.get_config(&"map") as WgMapConfig


func _tile_size() -> int:
	return _config_of().tile_size
