## Something the player talks to or examines by facing it and pressing the
## interact action. Placed on a map, on its cell; one inside a walker is that
## walker. It blocks nothing: what is drawn blocks through the TileSet.
class_name WgInteractable
extends Node2D

## Every interactable is in this group.
const GROUP := &"wildgrass_interactables"
## `sides` flags, by the direction the player faces.
const SIDES: Dictionary[Vector2i, int] = {
	Vector2i.UP: 1, Vector2i.DOWN: 2, Vector2i.LEFT: 4, Vector2i.RIGHT: 8,
}

## Emitted when a walker interacts with it, before `_interact()` runs.
signal interacted(walker: WgWalker)

## Cells covered, from its own to the right and down.
@export var size := Vector2i.ONE
## Its level; inside a walker, the walker's.
@export var level := 0
## The directions the player may face it from.
@export_flags("Up", "Down", "Left", "Right") var sides := 15


func _enter_tree() -> void:
	add_to_group(GROUP)


## True if `cell` on `on_level` is covered, faced in `direction`. `origin` is
## its own cell.
func covers(origin: Vector2i, cell: Vector2i, on_level: int, direction: Vector2i) -> bool:
	var parent := get_parent() as WgWalker
	var own_level := parent.level if parent != null else level
	if own_level != on_level or sides & SIDES.get(direction, 0) == 0:
		return false
	return Rect2i(origin, size).has_point(cell)


## Runs the interaction: `interacted`, then `_interact()`.
func interact(walker: WgWalker) -> void:
	interacted.emit(walker)
	await _interact(walker)


## What happens; the player reads no input until it returns.
func _interact(_walker: WgWalker) -> void:
	pass
