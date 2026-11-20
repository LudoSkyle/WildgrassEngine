## What a character says, inside it: it ends its step, turns toward the
## player, speaks, then turns back, unless a script moved or turned it
## meanwhile. Its controller waits while it talks.
class_name WgTalk
extends WgInteractable

## What it says; `[page]` starts a page.
@export_multiline var text := ""
## Its name, shown beside the box.
@export var speaker := ""
## The colour of its name; transparent: the label's.
@export var speaker_color := Color.TRANSPARENT
## Turns toward the player, then back.
@export var turns := true


func _interact(walker: WgWalker) -> void:
	var character := get_parent() as WgWalker
	var walkers := walker.walkers
	var before := Vector2i.ZERO
	var turned_to := Vector2i.ZERO
	var standing := Vector2i.ZERO
	if character != null:
		walkers.set_still(character, true)
		while character.is_moving:
			await character.step_finished
		before = character.facing
		if turns:
			character.turn_toward(walker)
		turned_to = character.facing
		standing = character.cell
	var options := {}
	if not speaker.is_empty():
		options["speaker"] = speaker
	if speaker_color.a > 0.0:
		options["speaker_color"] = speaker_color
	await walkers.dialogue.say(text, options)
	if character == null or not is_instance_valid(character):
		return
	walkers.set_still(character, false)
	if turns and character.facing == turned_to and character.cell == standing and not walkers.is_scripted(character):
		character.turn(before)
