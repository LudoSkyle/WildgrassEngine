## Imports a Studio project's maps into this Godot project (feature 10 ter):
##   godot --headless --path <game> -s res://addons/wildgrass/studio/import_maps.gd -- <Studio Data folder> [map dbSymbol…]
## The textures are written first and imported by Godot, then the TileSet
## and the maps.
extends SceneTree

const _StudioMaps := preload("res://addons/wildgrass/studio/studio_maps.gd")
const _Studio := preload("res://addons/wildgrass/studio/studio.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Usage: -- <Studio Data folder> [map dbSymbol…]")
		quit(1)
		return
	var importer := _StudioMaps.new(args[0])
	importer.scripts_folder = "res://studio/scripts"
	var wanted: Array[String] = []
	wanted.assign(args.slice(1))
	if wanted.is_empty():
		wanted = importer.map_symbols()
	var written := importer.write_textures(wanted)
	written.append_array(importer.write_sounds(wanted))
	written.append_array(importer.write_sheets(wanted))
	written.append_array(importer.write_effects(wanted))
	written.append_array(importer.write_media(wanted))
	if not written.is_empty():
		print("%d textures and sounds written; Godot imports them" % written.size())
		var output: Array = []
		OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--import"], output, true)
	var imported := 0
	for symbol in wanted:
		if importer.import_map(symbol):
			imported += 1
			print("%s: imported" % symbol)
	importer.save_tile_set()
	print("%d common events written" % importer.write_common_events())
	var numbers := importer.write_map_numbers()
	if not numbers.is_empty():
		print("map numbers, for transfers: %s" % numbers)
	var translations := importer.write_translations()
	if not translations.is_empty():
		print("the words of messages and choices: %s; list its translations in Project Settings > Localization" % translations)
	var counts := importer.write_event_report(wanted)
	print("%d events, %d commands, %d not run yet (maps/events.txt)" % [counts["events"], counts["commands"], counts["raw"]])
	print("%d scripts to translate in %s/to_translate/" % [counts["to_translate"], importer.scripts_folder])
	if str(ProjectSettings.get_setting(WgScriptContext.SETTING, "")).is_empty():
		print("scripts are written with Studio's words: name %s in Project Settings > %s" % [_Studio.SCRIPT_CONTEXT, WgScriptContext.SETTING])
	for problem in importer.problems:
		printerr(problem)
	print("%d of %d maps imported" % [imported, wanted.size()])
	quit(0 if imported == wanted.size() else 1)
