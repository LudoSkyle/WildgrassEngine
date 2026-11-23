## Follows its walker, its parent. Free on linked maps; held within a map
## without links, and centred on it where the map is narrower than the screen.
class_name WgCamera
extends Camera2D

const FAR := 10000000

var _walker: WgWalker


func _ready() -> void:
	_walker = get_parent() as WgWalker
	if _walker == null:
		push_error("%s: a WgCamera goes in a WgWalker" % name)
		return
	if _walker.is_node_ready():
		_listen()
	else:
		_walker.ready.connect(_listen, CONNECT_ONE_SHOT)


func _listen() -> void:
	if _walker.walkers == null:
		return
	_walker.walkers.maps.map_changed.connect(_on_map_changed)
	# On arrival, under the transition, not once it is gone: the view would
	# show the old map's limits for a moment, then jump.
	_walker.walkers.maps.traveller_arrived.connect(_on_traveller_arrived)
	apply_limits()


## Sets the limits for the current map.
func apply_limits() -> void:
	var maps := _walker.walkers.maps
	var map := maps.current
	if map == null or map.size == Vector2i.ZERO or not map.links.is_empty():
		_set_limits(Rect2(-FAR, -FAR, 2 * FAR, 2 * FAR))
		return
	var area := maps.rect(map)
	var view := get_viewport_rect().size / zoom
	for axis in 2:
		if area.size[axis] < view[axis]:
			area.position[axis] = area.get_center()[axis] - view[axis] / 2.0
			area.size[axis] = view[axis]
	_set_limits(area)


func _set_limits(area: Rect2) -> void:
	limit_left = floori(area.position.x)
	limit_top = floori(area.position.y)
	limit_right = ceili(area.end.x)
	limit_bottom = ceili(area.end.y)
	if is_inside_tree():
		reset_smoothing()
		force_update_scroll()


func _on_map_changed(_map: WgMap) -> void:
	apply_limits()


func _on_traveller_arrived(_direction: Vector2i, _point: Node2D) -> void:
	apply_limits()
