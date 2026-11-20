## A sign: says its text in the sign frame, and lets the player walk away.
## What it says may follow the story.
class_name WgSign
extends WgInteractable

const StoryLines := preload("res://addons/wildgrass/story/story_lines.gd")

## What it says; `[page]` starts a page.
@export_multiline var text := ""
## `condition => text`: the last whose condition holds is said instead.
@export var states: Array[String] = []
## A question before: `Question?`, or `condition => Question?` for one state.
@export var ask := ""


## What it says now.
func current_text(story: RefCounted) -> String:
	return StoryLines.choose(story, self, text, states, ask)["text"]


func _interact(walker: WgWalker) -> void:
	var options := {"style": "sign", "walk_away": true}
	var chosen := StoryLines.choose(walker.walkers.story, self, text, states, ask)
	if not chosen["question"].is_empty() and not await walker.walkers.dialogue.confirm(chosen["question"], {"style": "sign"}):
		return
	await walker.walkers.dialogue.say(chosen["text"], options)
