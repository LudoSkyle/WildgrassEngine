## The `pokedex` config: the Pokédexes of a new game, and the pause menu's
## entry.
class_name WgPokedexConfig
extends WgConfig

## The ids of the Pokédexes a new game has, in order; the first is shown.
@export var dexes: Array[String] = ["national"]
## The menu entry shows while this story condition holds; empty: always.
@export var condition := ""
## The input action showing the next Pokédex on the screen; empty: none.
@export var switch := ""


func _validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if dexes.is_empty():
		problems.append("dexes needs a Pokédex; using national")
		dexes.assign(["national"])
	return problems
