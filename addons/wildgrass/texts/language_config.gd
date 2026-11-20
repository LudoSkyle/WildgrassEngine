## `language_config.json`, as Pokémon Studio projects have it: the default
## language, the languages the player may choose and their names.
class_name WgLanguageConfig
extends WgConfig

## Language at start; empty: Godot's choice, the system's.
@export var default_language := ""
## Languages the player may choose, in order; empty: every locale Godot has
## translations for.
@export var choosable_language_code: Array[String] = []
## Name of each choosable language, written in that language.
@export var choosable_language_texts: Array[String] = []
## Column of Studio's text files for a Godot locale, where they differ.
@export var studio_columns: Dictionary[String, String] = {}


func _validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if not choosable_language_texts.is_empty() and choosable_language_texts.size() != choosable_language_code.size():
		problems.append("choosableLanguageTexts has %d names for %d codes" % [choosable_language_texts.size(), choosable_language_code.size()])
	return problems
