## Temporary files and project settings for a test, undone by `cleanup()`.
extends RefCounted

var root: String

var _saved_settings: Dictionary[String, Variant] = {}
static var _count := 0


func _init() -> void:
	_count += 1
	root = "user://wildgrass_tests/%d_%d/" % [Time.get_ticks_usec(), _count]
	DirAccess.make_dir_recursive_absolute(root)


## Sets a project setting for the test only.
func set_setting(key: String, value: Variant) -> void:
	if not _saved_settings.has(key):
		_saved_settings[key] = ProjectSettings.get_setting(key) if ProjectSettings.has_setting(key) else null
	ProjectSettings.set_setting(key, value)


## Points the engine's data and config folders at this sandbox.
func use_data_folder() -> String:
	set_setting("wildgrass/paths/data", root + "Data/")
	set_setting("wildgrass/paths/config", root + "config/")
	set_setting("wildgrass/paths/items", root + "items/")
	set_setting("wildgrass/paths/quests", root + "quests/")
	set_setting("wildgrass/paths/pokemon", root + "pokemon/")
	set_setting("wildgrass/paths/types", root + "types/")
	set_setting("wildgrass/paths/dex", root + "dex/")
	set_setting("wildgrass/paths/encounters", root + "encounters/")
	set_setting("wildgrass/paths/audio", root + "audio/")
	return root + "Data/"


func write(relative: String, text: String) -> String:
	var path := root + relative
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return path


func write_json(relative: String, data: Variant) -> String:
	return write(relative, JSON.stringify(data))


## Saves a scene whose root is a Control with `script` (none: a plain Control).
func scene(relative: String, script: Script = null) -> String:
	var node := Control.new()
	if script != null:
		node.set_script(script)
	var packed := PackedScene.new()
	packed.pack(node)
	node.free()
	var path := root + relative
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	ResourceSaver.save(packed, path)
	return path


## Points the maps folder at this sandbox.
func use_maps_folder() -> String:
	set_setting("wildgrass/paths/maps", root + "maps/")
	return root + "maps/"


## Saves `map` as maps/<id>.tscn, every descendant owned by it, then frees it.
func save_map(map_id: String, map: Node) -> String:
	_own(map, map)
	var packed := PackedScene.new()
	packed.pack(map)
	map.free()
	var path := root + "maps/%s.tscn" % map_id
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	ResourceSaver.save(packed, path)
	return path


static func _own(node: Node, owner_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner_node
		_own(child, owner_node)


func cleanup() -> void:
	for key: String in _saved_settings:
		ProjectSettings.set_setting(key, _saved_settings[key])
	_saved_settings.clear()
	_remove(root)


static func _remove(folder: String) -> void:
	for file: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder + file)
	for sub: String in DirAccess.get_directories_at(folder):
		_remove(folder + sub + "/")
	DirAccess.remove_absolute(folder)
