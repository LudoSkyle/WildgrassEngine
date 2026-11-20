## `movement_config.json`: paces, jumps, the tap that turns, input actions.
class_name WgMovementConfig
extends WgConfig

const DEFAULT_LENGTHS: Dictionary[String, float] = {
	"walk_pace": 4.0, "run_pace": 8.0, "jump_pace": 5.0, "jump_height": 8.0,
}
const DEFAULT_ACTIONS: Dictionary[String, String] = {
	"up": "ui_up", "down": "ui_down", "left": "ui_left", "right": "ui_right", "run": "run",
	"interact": "ui_accept",
}

## Walking pace, in cells per second.
@export var walk_pace := 4.0
## Running pace, in cells per second.
@export var run_pace := 8.0
## Pace of a ledge jump, two cells long, in cells per second.
@export var jump_pace := 5.0
## Height of a jump's arc, in game pixels.
@export var jump_height := 8.0
## How long a direction must be held, from a standstill, before walking.
@export var hold_seconds := 0.12
## Characters do not move by themselves while a screen is open, a warp runs,
## or the player is held by an interaction.
@export var still_during_dialogue := true
## Seconds a scripted walk waits for a cell before giving up.
@export var patience := 2.0
## Cells a path search visits at most.
@export var path_cells := 400
## Input map action of each direction, of running and of interacting. Unset
## keys keep theirs.
@export var actions: Dictionary[String, String] = DEFAULT_ACTIONS.duplicate()


func _validate() -> PackedStringArray:
	var problems := PackedStringArray()
	for field: String in DEFAULT_LENGTHS:
		var value: float = get(field)
		if value <= 0.0:
			problems.append("%s must be positive, got %s; using %s" % [field.to_camel_case(), value, DEFAULT_LENGTHS[field]])
			set(field, DEFAULT_LENGTHS[field])
	if patience < 0.0:
		problems.append("patience cannot be negative, got %s; using 2" % patience)
		patience = 2.0
	if path_cells <= 0:
		problems.append("pathCells must be positive, got %s; using 400" % path_cells)
		path_cells = 400
	if hold_seconds < 0.0:
		problems.append("holdSeconds cannot be negative, got %s; using 0.12" % hold_seconds)
		hold_seconds = 0.12
	for key: String in actions.keys():
		if not DEFAULT_ACTIONS.has(key):
			problems.append("actions: unknown key '%s'" % key)
			actions.erase(key)
	for key: String in DEFAULT_ACTIONS:
		if not actions.has(key):
			actions[key] = DEFAULT_ACTIONS[key]
	return problems
