## What a character says, inside it: it ends its step, turns toward the
## player, speaks, then turns back, unless a script moved or turned it
## meanwhile. Its controller waits while it talks. What it says may follow the
## story.
class_name WgTalk
extends WgInteractable

const StoryLines := preload("res://addons/wildgrass/story/story_lines.gd")

## What it says; `[page]` starts a page.
@export_multiline var text := ""
## `condition => text`: the last whose condition holds is said instead.
@export var states: Array[String] = []
## A question before: `Question?`, or `condition => Question?` for one state.
@export var ask := ""
## Its name, shown beside the box.
@export var speaker := ""
## The colour of its name; transparent: the label's.
@export var speaker_color := Color.TRANSPARENT
## Turns toward the player, then back.
@export var turns := true


## What it says now.
func current_text(story: RefCounted) -> String:
	return StoryLines.choose(story, self, text, states, ask)["text"]


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
	var chosen := StoryLines.choose(walkers.story, self, text, states, ask)
	if chosen["question"].is_empty() or await walkers.dialogue.confirm(chosen["question"], options):
		await walkers.dialogue.say(chosen["text"], options)
	if character == null or not is_instance_valid(character):
		return
	walkers.set_still(character, false)
	if turns and character.facing == turned_to and character.cell == standing and not walkers.is_scripted(character):
		character.turn(before)
