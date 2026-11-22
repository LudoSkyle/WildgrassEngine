## Reflections: a walker over water one sees oneself in (tile data
## `reflects`, the topmost tile deciding) shows its current picture flipped
## below its ground line, cut to the water it falls in.
extends RefCounted

const ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const TileReader := preload("res://addons/wildgrass/life/tile_reader.gd")

## The sway of a reflection, in pixels, one value each quarter of a second.
const SWAY: Array[float] = [0.0, 1.0, 0.0, -1.0]
const SWAYS_PER_SECOND := 4.0

var _config: ConfigRegistry
var _walkers: Object
var _tiles: Object
var _clock := 0.0
## Each walker's reflection, by the walker's instance id.
var _glasses: Dictionary[int, Sprite2D] = {}
## The water layer of each holder of reflections.
var _holders: Dictionary[TileMapLayer, Node2D] = {}
## The tile layers of each map, by its instance id, gathered once a frame.
var _layers: Dictionary[int, Array] = {}


func _init(config_registry: ConfigRegistry, walkers: Object, tiles: Object) -> void:
	_config = config_registry
	_walkers = walkers
	_tiles = tiles


func config() -> WgReflectionsConfig:
	return _config.get_config(&"reflections") as WgReflectionsConfig


## Moves the water on by `delta` seconds.
func advance(delta: float) -> void:
	_clock += delta


## The reflection of `walker`, or null if it has none yet.
func of(walker: WgWalker) -> Sprite2D:
	var glass: Variant = _glasses.get(walker.get_instance_id())
	return glass as Sprite2D if is_instance_valid(glass) else null


## Draws every walker's reflection as it stands now: after the walkers moved,
## before the frame is drawn.
func show_all() -> void:
	for id: int in _glasses.keys():
		if not is_instance_id_valid(id):
			if is_instance_valid(_glasses[id]):
				_glasses[id].queue_free()
			_glasses.erase(id)
	_layers.clear()
	for walker: WgWalker in _walkers.all():
		_show(walker)
	_layers.clear()


func _show(walker: WgWalker) -> void:
	var glass := of(walker)
	var picture := _picture(walker)
	var map := _map_of(walker)
	if not walker.reflects or picture.is_empty() or map == null:
		if glass != null:
			glass.hide()
		return
	var sprite: Node2D = picture["sprite"]
	var frame: Rect2 = picture["frame"]
	var scale := sprite.global_scale
	var size := frame.size * scale.abs()
	var centre := _centre(sprite, frame.size)
	var tick := int(floor(_clock * SWAYS_PER_SECOND))
	var axis := centre.x + SWAY[tick % SWAY.size()]
	# Mirrored about the ground line: a point at y goes to 2 * ground - y.
	var middle := 2.0 * (walker.global_position.y + walker.ground_offset) - centre.y - config().lift
	var top := middle - size.y / 2.0
	var left := axis - size.x / 2.0
	if not _layers.has(map.get_instance_id()):
		_layers[map.get_instance_id()] = TileReader.layers_under(map)
	var layers: Array[TileMapLayer] = []
	layers.assign(_layers[map.get_instance_id()])
	var pool := _pool(layers, left, left + size.x, top, top + size.y)
	if pool.is_empty() or pool["rect"].size.x <= 1.0 or pool["rect"].size.y <= 1.0:
		if glass != null:
			glass.hide()
		return
	var rect: Rect2 = pool["rect"]
	var holder := _holder(pool["layer"])
	if glass == null or glass.get_parent() != holder:
		if glass != null:
			glass.queue_free()
		glass = Sprite2D.new()
		holder.add_child(glass)
		_glasses[walker.get_instance_id()] = glass
	glass.show()
	glass.texture = picture["texture"]
	glass.modulate = config().tint
	glass.flip_v = true
	glass.flip_h = picture["flip_h"]
	glass.scale = scale.abs()
	glass.region_enabled = true
	# Flipped: the slice shown at the top of the reflection is the bottom of
	# the picture.
	var near := (rect.position.y - top) / scale.y
	var far := (rect.end.y - top) / scale.y
	var from_left := (rect.position.x - left) / absf(scale.x)
	var width := rect.size.x / absf(scale.x)
	if glass.flip_h:
		from_left = frame.size.x - from_left - width
	glass.region_rect = Rect2(frame.position.x + from_left, frame.end.y - far, width, far - near)
	glass.global_position = rect.get_center()


## The picture `walker` shows now: {sprite, texture, frame, flip_h}, or {}.
func _picture(walker: WgWalker) -> Dictionary:
	var sprite := walker.get_node_or_null(walker.sprite)
	if sprite is AnimatedSprite2D:
		var animated := sprite as AnimatedSprite2D
		if animated.sprite_frames == null or not animated.sprite_frames.has_animation(animated.animation):
			return {}
		var texture := animated.sprite_frames.get_frame_texture(animated.animation, animated.frame)
		if texture == null or not animated.is_visible_in_tree():
			return {}
		return {"sprite": animated, "texture": texture, "frame": Rect2(Vector2.ZERO, texture.get_size()), "flip_h": animated.flip_h}
	if sprite is Sprite2D:
		var still := sprite as Sprite2D
		if still.texture == null or not still.is_visible_in_tree():
			return {}
		var frame := still.get_rect()
		frame.position = still.region_rect.position if still.region_enabled else Vector2.ZERO
		if not still.region_enabled and (still.hframes > 1 or still.vframes > 1):
			frame.position = Vector2(still.frame_coords) * frame.size
		return {"sprite": still, "texture": still.texture, "frame": frame, "flip_h": still.flip_h}
	return {}


## Where the middle of a picture of `size` is drawn.
func _centre(sprite: Node2D, size: Vector2) -> Vector2:
	var local: Vector2 = sprite.get(&"offset")
	if not sprite.get(&"centered"):
		local += size / 2.0
	return sprite.to_global(local)


func _map_of(walker: WgWalker) -> WgMap:
	var node: Node = walker.get_parent()
	while node != null and not node is WgMap:
		node = node.get_parent()
	return node as WgMap


## The water under a picture spanning `left` to `right` and `top` to
## `bottom`: the widest run of columns of cells where water starts below,
## sharing some height, and the height they share. {rect, layer}, or {}.
func _pool(layers: Array[TileMapLayer], left: float, right: float, top: float, bottom: float) -> Dictionary:
	var cell_size: float = _tiles.tile_size()
	var best := {}
	var run := {}
	var x := left
	while x < right:
		var column := floorf((x + 0.01) / cell_size)
		var edge := minf(right, (column + 1.0) * cell_size)
		var span := _span(layers, (column + 0.5) * cell_size, top, bottom, cell_size)
		if span.is_empty():
			run = {}
		elif run.is_empty() or maxf(run["top"], span["top"]) >= minf(run["bottom"], span["bottom"]):
			# A column whose water shares no height with the run starts its own.
			run = {"left": x, "right": edge, "top": span["top"], "bottom": span["bottom"], "layer": span["layer"]}
		else:
			run = {"left": run["left"], "right": edge, "top": maxf(run["top"], span["top"]), "bottom": minf(run["bottom"], span["bottom"]), "layer": run["layer"]}
		if not run.is_empty() and (best.is_empty() or run["right"] - run["left"] > best["right"] - best["left"]):
			best = run
		x = edge
	if best.is_empty():
		return {}
	return {"rect": Rect2(best["left"], best["top"], best["right"] - best["left"], best["bottom"] - best["top"]), "layer": best["layer"]}


## The first stretch of water going down at `x` from `top` to `bottom`, cell
## by cell: {top, bottom, layer}, or {}. A dry cell after water ends it: a
## bank cuts a reflection, never takes it up again lower.
func _span(layers: Array[TileMapLayer], x: float, top: float, bottom: float, cell_size: float) -> Dictionary:
	var found := {}
	var y := top + 0.5
	while y < bottom:
		var row := floorf(y / cell_size)
		var point := Vector2(x, y)
		var layer := TileReader.top_in(layers, point)
		if layer != null and TileReader.read(layer, layer.local_to_map(layer.to_local(point)), "reflects", false) == true:
			if found.is_empty():
				found = {"top": maxf(top, row * cell_size), "layer": layer}
			found["bottom"] = minf(bottom, (row + 1.0) * cell_size)
		elif not found.is_empty():
			break
		y = (row + 1.0) * cell_size + 0.5
	return found


## The holder of reflections just above `water`, under the rest of the map.
func _holder(water: TileMapLayer) -> Node2D:
	if _holders.has(water) and is_instance_valid(_holders[water]):
		return _holders[water]
	var holder := Node2D.new()
	holder.z_index = water.z_index
	water.add_sibling(holder)
	_holders[water] = holder
	return holder
