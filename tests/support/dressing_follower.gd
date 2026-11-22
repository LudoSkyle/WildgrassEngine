## A game's follower drawn its own way: it records how it was dressed.
extends WgFollower

var dressed := []


func _dress(species_form: WgSpeciesForm, is_shiny: bool, is_female: bool) -> bool:
	dressed = [species_form.form, is_shiny, is_female]
	return true
