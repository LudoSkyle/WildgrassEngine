## The `pokemon` config: how far Pokémon grow.
class_name WgPokemonConfig
extends WgConfig

## The highest level.
@export var max_level := 100


func _validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if max_level < 1:
		problems.append("max_level %d is below 1; using 100" % max_level)
		max_level = 100
	return problems
