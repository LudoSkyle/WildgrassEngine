## The `language` config: the default language, the languages the player may
## choose and their names.
class_name WgLanguageConfig
extends WgConfig

## Language at start; empty: Godot's choice, the system's.
@export var default := ""
## Languages the player may choose, in order; empty: every locale Godot has
## translations for.
@export var choosable: Array[String] = []
## Name of each choosable language, written in that language.
@export var names: Array[String] = []
## Column of Studio's text files for a Godot locale, where they differ.
@export var studio_columns: Dictionary[String, String] = {}


func _validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if not names.is_empty() and names.size() != choosable.size():
		problems.append("names has %d names for %d languages" % [names.size(), choosable.size()])
	return problems
