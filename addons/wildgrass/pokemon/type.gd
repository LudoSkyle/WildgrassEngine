## A type of Pokémon: its name, a label shown through
## `Wildgrass.texts.label()`, its colour, and how hard it hits each other
## type.
class_name WgType
extends Resource

@export var id: StringName = &""
@export var name := ""
@export var color := Color.WHITE
## `{defending type id: factor}`; a type it does not name: 1.
@export var damage: Dictionary[StringName, float] = {}


## How hard it hits `defending`.
func factor_against(defending: StringName) -> float:
	return damage.get(defending, 1.0)
