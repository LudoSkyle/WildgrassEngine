## The `party` config: how many Pokémon the player carries.
class_name WgPartyConfig
extends WgConfig

## The most Pokémon in the party: the reference's 6.
@export var size := 6


func _validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if size < 1:
		problems.append("size %d is below 1; using 6" % size)
		size = 6
	return problems
