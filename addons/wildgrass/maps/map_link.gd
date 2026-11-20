## A map shown against one side of another, walked into with no transition.
class_name WgMapLink
extends Resource

enum Side { NORTH, EAST, SOUTH, WEST }

## The side of this map the linked map touches.
@export var side := Side.NORTH
## Id of the linked map.
@export var map: StringName = &""
## Tiles the linked map is shifted right (north, south) or down (east, west).
@export var offset := 0
