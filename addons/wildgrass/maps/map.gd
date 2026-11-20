## Root of every map scene.
class_name WgMap
extends Node2D

## Node the traveller is put in. Y-sorted in most maps.
@export var entities: NodePath = ^"Entities"
## Pokémon Studio zone id: map-wide data shared by several maps.
@export var zone: StringName = &""


## The node the traveller goes in, or the map itself if missing.
func entities_node() -> Node:
	var node := get_node_or_null(entities)
	return node if node != null else self


## The door or spawn point named `point_name`, or null.
func find_point(point_name: StringName) -> Node2D:
	for node: Node in _descendants(self):
		if node.name == point_name and (node is WgSpawnPoint or node is WgDoor):
			return node as Node2D
	return null


## The first spawn point in tree order, or null.
func first_spawn_point() -> WgSpawnPoint:
	for node: Node in _descendants(self):
		if node is WgSpawnPoint:
			return node
	return null


## The first node of the map that is an instance of `type` (a script or a
## native class name), or null. Map-wide settings are such nodes.
func find_part(type: Variant) -> Node:
	for node: Node in _descendants(self):
		if is_instance_of(node, type):
			return node
	return null


static func _descendants(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in root.get_children():
		result.append(child)
		result.append_array(_descendants(child))
	return result
