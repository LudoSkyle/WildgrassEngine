## Footprints: a walker leaving a cell whose tile keeps prints (tile data
## `footprints`, the topmost tile of the cell deciding) puts a pair there,
## one foot each side of its way, the leading foot changing each step. A
## print darkens the ground for half its life, then fades.
extends RefCounted

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const TileReader := preload("res://addons/wildgrass/life/tile_reader.gd")

## Where the feet are below a cell's centre, how far apart, how far one leads,
## for cells of 16 pixels.
const FEET := 4.0
const SPREAD := 3.0
const STRIDE := 2.0

## Every print on the maps, each a Sprite2D; one gone with its map leaves at
## the next `advance()`.
var prints: Array[Sprite2D] = []

var _paths: Paths
var _config: ConfigRegistry
var _maps: Object
var _tiles: Object
## A walker's instance id -> [cell left, direction] of its step under way.
var _leaving: Dictionary[int, Array] = {}
## A walker's instance id -> true when its next pair leads with the other foot.
var _leading: Dictionary[int, bool] = {}
## The ground layer of each print holder.
var _holders: Dictionary[TileMapLayer, Node2D] = {}
## The age of each print, in the order of `prints`.
var _ages: Array[float] = []
## The picture of prints and the path it was read from.
var _texture: Texture2D
var _texture_path := ""
## Whether the picture is the config's, cut in cells.
var _from_config := false


func _init(paths: Paths, config_registry: ConfigRegistry, maps: Object, walkers: Object, tiles: Object) -> void:
	_paths = paths
	_config = config_registry
	_maps = maps
	_tiles = tiles
	walkers.walker_left.connect(_on_left)
	walkers.walker_entered.connect(_on_entered)


func config() -> WgFootprintsConfig:
	return _config.get_config(&"footprints") as WgFootprintsConfig


## Ages every print by `delta` seconds; an old one goes.
func advance(delta: float) -> void:
	var settings := config()
	for index in range(prints.size() - 1, -1, -1):
		if is_instance_valid(prints[index]):
			_ages[index] += delta
			var left := 1.0 - _ages[index] / settings.life_seconds
			if left > 0.0:
				_shade(prints[index], left)
				continue
			(prints[index] as Sprite2D).queue_free()
		prints.remove_at(index)
		_ages.remove_at(index)


## The topmost layer of the current maps with a tile at `point`, or null.
func ground_at(point: Vector2) -> TileMapLayer:
	var map: WgMap = _maps.map_at(point)
	if map == null:
		return null
	return TileReader.top_at(map, point)


func _on_left(walker: WgWalker, cell: Vector2i, direction: Vector2i, _running: bool) -> void:
	for id: int in _leading.keys() + _leaving.keys():
		if not is_instance_id_valid(id):
			_leading.erase(id)
			_leaving.erase(id)
	_leaving[walker.get_instance_id()] = [cell, direction]


func _on_entered(walker: WgWalker, cell: Vector2i) -> void:
	var id := walker.get_instance_id()
	if not _leaving.has(id):
		return
	var left: Array = _leaving[id]
	_leaving.erase(id)
	var from: Vector2i = left[0]
	var direction: Vector2i = left[1]
	if from + direction != cell:
		return
	var centre: Vector2 = _tiles.center_of(from)
	var ground := ground_at(centre)
	if ground == null or TileReader.read(ground, ground.local_to_map(ground.to_local(centre)), "footprints", false) != true:
		return
	_drop(walker, ground, centre, Vector2(direction))


## A pair of prints around `centre`, along `step`.
func _drop(walker: WgWalker, ground: TileMapLayer, centre: Vector2, step: Vector2) -> void:
	var holder := _holder(ground)
	var scale := ground.tile_set.tile_size.x / 16.0
	var side := Vector2(-step.y, step.x)
	var id := walker.get_instance_id()
	var lead := 1.0 if _leading.get(id, false) else -1.0
	_leading[id] = not _leading.get(id, false)
	var feet := centre + Vector2(0.0, FEET * scale)
	_plant(holder, feet + (side * SPREAD + step * STRIDE * lead) * scale, step, side)
	_plant(holder, feet - (side * SPREAD + step * STRIDE * lead) * scale, step, -side)


func _plant(holder: Node2D, at: Vector2, step: Vector2, side: Vector2) -> void:
	var print_node := Sprite2D.new()
	var settings := config()
	print_node.texture = _picture()
	if _from_config:
		var direction := 0 if step.y > 0.0 else (1 if step.x < 0.0 else (2 if step.x > 0.0 else 3))
		var foot := 0 if (side.x < 0.0 if step.x == 0.0 else side.y < 0.0) else 1
		print_node.region_enabled = true
		print_node.region_rect = Rect2((direction * 2 + foot) * settings.cell, 0, settings.cell, settings.cell)
	holder.add_child(print_node)
	print_node.global_position = at.floor()
	prints.append(print_node)
	_ages.append(0.0)
	_shade(print_node, 1.0)


func _shade(print_node: Sprite2D, left: float) -> void:
	var strength := 1.0 if left > 0.5 else left / 0.5
	print_node.modulate = Color(0, 0, 0, config().darkness * strength)


## The holder of prints just above `ground`, under the rest of the map.
func _holder(ground: TileMapLayer) -> Node2D:
	if _holders.has(ground) and is_instance_valid(_holders[ground]):
		return _holders[ground]
	var holder := Node2D.new()
	holder.z_index = ground.z_index
	ground.add_sibling(holder)
	_holders[ground] = holder
	return holder


## The config's picture, else a dark oval made in code.
func _picture() -> Texture2D:
	var path := config().texture
	if _texture != null and _texture_path == path:
		return _texture
	_texture_path = path
	_texture = null
	if not path.is_empty():
		if ResourceLoader.exists(path):
			_texture = load(path) as Texture2D
		elif FileAccess.file_exists(path):
			var image := Image.load_from_file(path)
			_texture = ImageTexture.create_from_image(image) if image != null else null
		if _texture == null:
			_paths.report_missing(path, "footprints texture")
	_from_config = _texture != null
	if _texture == null:
		var image := Image.create(3, 4, false, Image.FORMAT_RGBA8)
		for y in 4:
			for x in 3:
				if not ((x == 0 or x == 2) and (y == 0 or y == 3)):
					image.set_pixel(x, y, Color.WHITE)
		_texture = ImageTexture.create_from_image(image)
	return _texture
