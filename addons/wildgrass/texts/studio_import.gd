## Godot imports every `.csv` as translations, Studio's text files included:
## they are set to *Keep File* instead, read by the engine as they are and
## exported with the game.
extends RefCounted


## Sets every `.csv` of `folder` to *Keep File*. Returns the files changed, to
## reimport, and fills `made` with what Godot had made of them, to remove once
## reimported.
static func keep_files(folder: String, made: Array[String] = []) -> PackedStringArray:
	var changed := PackedStringArray()
	var dir := DirAccess.open(folder)
	if dir == null:
		return changed
	for file: String in dir.get_files():
		if file.get_extension().to_lower() != "csv":
			continue
		var path := folder.path_join(file)
		var settings := ConfigFile.new()
		if settings.load(path + ".import") == OK:
			if settings.get_value("remap", "importer", "") == "keep":
				continue
			made.append_array(settings.get_value("deps", "dest_files", []))
		var keep := ConfigFile.new()
		keep.set_value("remap", "importer", "keep")
		keep.save(path + ".import")
		changed.append(path)
	return changed
