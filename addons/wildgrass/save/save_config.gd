## `save_config.json` (Studio's): how many games, and their files.
class_name WgSaveConfig
extends WgConfig

## How many slots; 0: as many as the player wants, 1: a single game.
@export var maximum_save := 0
## The file of slot 2 is `<baseFilename>-2.json` in the saves folder; a
## single game's `<baseFilename>.json`.
@export var base_filename := "Saves/Pokemon_Party"
## True: the save screen may write in another slot than the game's.
@export var is_can_save_on_any_save := false
## Studio's binary format: not used.
@export var save_key := 0
## Studio's binary format: not used.
@export var save_header := "PKPRT"


func _validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if maximum_save < 0:
		problems.append("maximumSave cannot be negative, got %d; using 0" % maximum_save)
		maximum_save = 0
	if base_filename.strip_edges().is_empty() or base_filename.ends_with("/"):
		problems.append("baseFilename needs a file name, got '%s'; using Saves/Pokemon_Party" % base_filename)
		base_filename = "Saves/Pokemon_Party"
	if save_key != 0:
		problems.append("saveKey is for Studio's binary saves; games are written as JSON, not encrypted")
	return problems
