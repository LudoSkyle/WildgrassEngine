## Writes a Studio project's species, types, moves, abilities and natures
## into this Godot project, as its own resources and translations, with the
## species' pictures and cries (feature 23):
##   godot --headless --path <game> -s res://addons/wildgrass/studio/import_data.gd -- <Studio Data folder>
## A resource already there is written over.
extends SceneTree

const _StudioData := preload("res://addons/wildgrass/studio/studio_data.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Usage: -- <Studio Data folder>")
		quit(1)
		return
	var importer := _StudioData.new(args[0])
	print("%d species, %d types written" % [importer.write_species(), importer.write_types()])
	print("%d moves, %d abilities, %d natures written" % [importer.write_moves(), importer.write_abilities(), importer.write_natures()])
	var translations := importer.write_translations()
	if not translations.is_empty():
		print("their words: %s; list its translations in Project Settings > Localization" % translations)
	print("%d pictures and cries copied; Godot imports them and the words" % importer.copied)
	var output: Array = []
	OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--import"], output, true)
	var config := importer.write_config()
	if not config.is_empty():
		print("the highest level: %s" % config)
	for problem in importer.problems:
		printerr(problem)
	quit(0 if importer.problems.is_empty() else 1)
