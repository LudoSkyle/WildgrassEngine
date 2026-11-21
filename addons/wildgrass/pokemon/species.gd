## A species of Pokémon: its national number and texts, and its forms, the
## first being form 0. Its texts are labels, shown through
## `Wildgrass.texts.label()`.
class_name WgSpecies
extends Resource

@export var id: StringName = &""
## Its national number.
@export var number := 0
## 0: unknown.
@export var generation := 0
@export var name := ""
## "Seed Pokémon".
@export var genus := ""
@export_multiline var description := ""
## One at least; the first is form 0.
@export var forms: Array[WgSpeciesForm] = []


## Its form `number`, or null.
func find_form(form_number: int) -> WgSpeciesForm:
	for found in forms:
		if found.form == form_number:
			return found
	return null
