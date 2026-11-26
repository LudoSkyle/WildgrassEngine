## A move a Pokémon knows, and its PP.
class_name WgMoveSlot
extends Resource

@export var move: StringName = &""
@export var pp := 0
@export var max_pp := 0


static func of(move_id: StringName, most: int) -> WgMoveSlot:
	var slot := WgMoveSlot.new()
	slot.move = move_id
	slot.max_pp = most
	slot.pp = most
	return slot
