## Builds map scenes for tests, in code.
extends RefCounted

const Sandbox := preload("res://tests/support/sandbox.gd")

var _sandbox: Sandbox


func _init(sandbox: Sandbox) -> void:
	_sandbox = sandbox
	sandbox.use_maps_folder()


## A WgMap with an Entities node. Add points with the other methods, then save().
func map(zone := &"") -> WgMap:
	var root := WgMap.new()
	root.zone = zone
	var entities := Node2D.new()
	entities.name = "Entities"
	root.add_child(entities)
	return root


static func spawn(map_node: Node, point_name: String, position: Vector2, direction := Vector2i.DOWN) -> WgSpawnPoint:
	var point := WgSpawnPoint.new()
	point.name = point_name
	point.position = position
	point.direction = direction
	map_node.add_child(point)
	return point


static func door(map_node: Node, door_name: String, position: Vector2, target_map: StringName, target_door: StringName, kind := WgDoor.Kind.CONTACT, direction := Vector2i.DOWN, transition := &"none") -> WgDoor:
	var node := WgDoor.new()
	node.name = door_name
	node.position = position
	node.target_map = target_map
	node.target_door = target_door
	node.kind = kind
	node.direction = direction
	node.transition = transition
	map_node.add_child(node)
	return node


func save(map_id: String, map_node: WgMap) -> void:
	_sandbox.save_map(map_id, map_node)
