## The `save` config: how many games, and their files.
class_name WgSaveConfig
extends WgConfig

## How many slots; 0: as many as the player wants, 1: a single game.
@export var slots := 0
## The file of slot 2 is `<file>-2.json` in the saves folder; a single
## game's `<file>.json`.
@export var file := "saves/game"
## True: the save screen may write in another slot than the game's.
@export var save_anywhere := false


func _validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if slots < 0:
		problems.append("slots cannot be negative, got %d; using 0" % slots)
		slots = 0
	if file.strip_edges().is_empty() or file.ends_with("/"):
		problems.append("file needs a file name, got '%s'; using saves/game" % file)
		file = "saves/game"
	return problems
