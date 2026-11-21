@tool
extends EditorPlugin

const AUTOLOAD_NAME := "Wildgrass"
const AUTOLOAD_PATH := "res://addons/wildgrass/wildgrass.gd"
const SHADER_GLOBAL := "shader_globals/game_time"
const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const StudioTexts := preload("res://addons/wildgrass/studio/studio_texts.gd")
const StudioImport := preload("res://addons/wildgrass/studio/studio_import.gd")


func _enable_plugin() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	if not ProjectSettings.has_setting(SHADER_GLOBAL):
		ProjectSettings.set_setting(SHADER_GLOBAL, {"type": "float", "value": 0.0})
		ProjectSettings.save()


func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)


## Shows the path settings in Project Settings, with their defaults. They are
## saved only once changed.
func _enter_tree() -> void:
	for kind: StringName in Paths.DEFAULTS:
		var key := Paths.SETTING_PREFIX + kind
		if not ProjectSettings.has_setting(key):
			ProjectSettings.set_setting(key, Paths.DEFAULTS[kind])
		ProjectSettings.set_initial_value(key, Paths.DEFAULTS[kind])
		ProjectSettings.add_property_info({"name": key, "type": TYPE_STRING, "hint": PROPERTY_HINT_DIR})
		ProjectSettings.set_as_basic(key, true)
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(_keep_studio_texts)


func _exit_tree() -> void:
	EditorInterface.get_resource_filesystem().filesystem_changed.disconnect(_keep_studio_texts)


## Studio's text files stay as they are, not turned into translations.
func _keep_studio_texts() -> void:
	var made: Array[String] = []
	var changed := StudioImport.keep_files(Paths.new(false).resolve(&"data", StudioTexts.FOLDER), made)
	if changed.is_empty():
		return
	EditorInterface.get_resource_filesystem().reimport_files(changed)
	for path in made:
		DirAccess.remove_absolute(path)
	EditorInterface.get_resource_filesystem().scan()
