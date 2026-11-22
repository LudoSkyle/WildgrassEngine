## The `encounters` config.
class_name WgEncountersConfig
extends WgConfig

## A wild Pokémon is shiny once in this many, unless its entry says otherwise.
@export var shiny_rate := 4096


func _validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if shiny_rate < 1:
		problems.append("shiny_rate must be 1 or more, got %d; using 4096" % shiny_rate)
		shiny_rate = 4096
	return problems
