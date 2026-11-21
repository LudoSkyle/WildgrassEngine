## The `dialogue` config: how fast text is written, how it goes on, the
## input actions of the message box.
class_name WgDialogueConfig
extends WgConfig

## What happens when a message does not fit the box.
enum Advance {
	## The box clears and writes the next lines.
	PAGE,
	## The lines slide up one by one, the next one written below.
	SCROLL,
}

const DEFAULT_ACTIONS: Dictionary[String, String] = {
	"confirm": "ui_accept", "cancel": "ui_cancel", "up": "ui_up", "down": "ui_down",
	"left": "ui_left", "right": "ui_right",
}

## Letters written per second; 0 writes each page at once.
@export var letters_per_second := 50.0
@export var advance := Advance.PAGE
## Speed of the lines sliding up, in game pixels per second.
@export var scroll_speed := 60.0
## Choices shown at once; a longer list scrolls.
@export var max_choices := 6
## Input map action of each key of the box. Unset keys keep theirs.
@export var actions: Dictionary[String, String] = DEFAULT_ACTIONS.duplicate()
## The frames the player may pick in the options, each `{"style", "name"}`:
## the box's `style` (feature 4), and its name, a text.
@export var frames: Array[Dictionary] = []


func _validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if letters_per_second < 0.0:
		problems.append("letters_per_second cannot be negative, got %s; using 50" % letters_per_second)
		letters_per_second = 50.0
	if scroll_speed <= 0.0:
		problems.append("scroll_speed must be positive, got %s; using 60" % scroll_speed)
		scroll_speed = 60.0
	if max_choices <= 0:
		problems.append("max_choices must be positive, got %s; using 6" % max_choices)
		max_choices = 6
	for key: String in actions.keys():
		if not DEFAULT_ACTIONS.has(key):
			problems.append("actions: unknown key '%s'" % key)
			actions.erase(key)
	for key: String in DEFAULT_ACTIONS:
		if not actions.has(key):
			actions[key] = DEFAULT_ACTIONS[key]
	var kept: Array[Dictionary] = []
	for frame: Dictionary in frames:
		if not frame.get("style") is String:
			problems.append("frames: a frame needs a style, got %s" % JSON.stringify(frame))
			continue
		kept.append(frame)
	frames = kept
	return problems
