## The engine's words in English (`engine_words.en.po`, the project's
## translation): a test that empties Godot's translations puts them back.
extends RefCounted


## Empties Godot's translations, then loads the project's again.
static func reset() -> void:
	TranslationServer.clear()
	for path: String in ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray()):
		TranslationServer.add_translation(load(path) as Translation)
