## A Pokédex: the species of a region, in its order. A species' number is
## `start` plus its place in `creatures`.
class_name WgDex
extends Resource

@export var id: StringName = &""
## A label, shown through `Wildgrass.texts.label()`.
@export var name := ""
## The number of the first species.
@export var start := 1
## `[{species, form}]`, in order.
@export var creatures: Array[Dictionary] = []


## The number of `species` in this Pokédex; 0 if it is not listed.
func number_of(species: StringName) -> int:
	for index in creatures.size():
		if StringName(str(creatures[index].get("species", ""))) == species:
			return start + index
	return 0


## True if it lists `species`.
func has(species: StringName) -> bool:
	return number_of(species) > 0
