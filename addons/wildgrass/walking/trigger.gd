## Cells that react when a step of the traveller ends on them. The player is
## held until `_triggered()` returns.
class_name WgTrigger
extends Node2D

## Every trigger is in this group.
const GROUP := &"wildgrass_triggers"

## Emitted when the traveller steps on it, before `_triggered()` runs.
signal triggered(walker: WgWalker)

## Cells covered, from its own to the right and down.
@export var size := Vector2i.ONE
## Its level.
@export var level := 0
## Off: steps on it do nothing.
@export var enabled := true


func _enter_tree() -> void:
	add_to_group(GROUP)


## True if `cell` on `on_level` is covered; `origin` is its own cell.
func covers(origin: Vector2i, cell: Vector2i, on_level: int) -> bool:
	return on_level == level and Rect2i(origin, size).has_point(cell)


## Runs the trigger: `triggered`, then `_triggered()`.
func trigger(walker: WgWalker) -> void:
	triggered.emit(walker)
	await _triggered(walker)


## What happens; the player reads no input until it returns.
func _triggered(_walker: WgWalker) -> void:
	pass
