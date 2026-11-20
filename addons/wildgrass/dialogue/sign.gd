## A sign: says its text in the sign frame, and lets the player walk away.
class_name WgSign
extends WgInteractable

## What it says; `[page]` starts a page.
@export_multiline var text := ""


func _interact(walker: WgWalker) -> void:
	await walker.walkers.dialogue.say(text, {"style": "sign", "walk_away": true})
