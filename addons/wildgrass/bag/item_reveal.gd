## Shows an item given, while its message is written and a moment after. The
## engine's scene uses Godot's default theme; a game points
## `wildgrass/screens/item_reveal` to its own. Keys go on to `forward`, the
## message box below.
class_name WgItemReveal
extends WgScreen

## The `TextureRect` of the item's icon.
@export var icon: NodePath = ^"Panel/Icon"

## The item shown.
var item: WgItem
var forward: WgScreen


func _on_open(args: Dictionary) -> void:
	item = args.get("item")
	forward = args.get("forward")
	var shown := get_node_or_null(icon) as TextureRect
	if shown != null and item != null:
		shown.texture = item.icon


func _on_input(event: InputEvent) -> bool:
	return is_instance_valid(forward) and forward._on_input(event)
