extends GdUnitTestSuite


## A game's global class wins over a script's constant of the same name in
## types: the engine's preloaded scripts are named apart, from `_`.
func test_no_preloaded_script_of_the_engine_can_meet_a_game_s_class_name() -> void:
	var found: Array[String] = []
	var pattern := RegEx.create_from_string("(?m)^const ([A-Za-z][A-Za-z0-9]*) := preload\\(")
	for path: String in _scripts("res://addons/wildgrass/"):
		for match in pattern.search_all(FileAccess.get_file_as_string(path)):
			found.append("%s: %s" % [path.get_file(), match.get_string(1)])
	assert_array(found).is_empty()


static func _scripts(folder: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			found.append(folder + file)
	for sub in DirAccess.get_directories_at(folder):
		found.append_array(_scripts(folder + sub + "/"))
	return found
