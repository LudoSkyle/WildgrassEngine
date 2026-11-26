extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const StudioData := preload("res://addons/wildgrass/studio/studio_data.gd")

var _world: World
var _importer: StudioData


func before_test() -> void:
	_world = World.new(self)
	_importer = StudioData.new(_world.sandbox.root + "Data")
	_importer.texts_file = _world.sandbox.root + "locale/data.csv"


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _texts(file: int, lines: Dictionary) -> void:
	var rows := PackedStringArray(["en,fr"])
	for at in (lines.keys().max() as int) + 1:
		rows.append(lines.get(at, "[~ 0],[~ 0]"))
	_world.sandbox.write("Data/Text/Dialogs/%d.csv" % file, "\n".join(rows) + "\n")


func test_moves_become_the_game_s_resources_their_texts_keys() -> void:
	_world.sandbox.write_json("Data/Studio/moves/pound.json", {"klass": "Move", "id": 1, "dbSymbol": "pound", "type": "normal", "power": 40, "category": "physical", "isDirect": true})
	_texts(100006, {1: "Pound,Écras'Face"})
	_texts(100007, {1: "\"Pounds, hard.\",Écrase."})
	assert_int(_importer.write_moves()).is_equal(1)
	var pound := load(_world.sandbox.root + "moves/pound.tres") as WgMove
	assert_array([pound.id, pound.number, pound.power, pound.type]).is_equal([&"pound", 1, 40, &"normal"])
	assert_array(pound.flags).is_equal([&"contact"])
	assert_array([pound.name, pound.description, pound.contest_description]).is_equal(["move.pound.name", "move.pound.description", ""])
	assert_str(_importer.write_translations()).is_equal(_world.sandbox.root + "locale/data.csv")
	var written := FileAccess.get_file_as_string(_world.sandbox.root + "locale/data.csv").split("\n")
	assert_array(Array(written.slice(0, 3))).is_equal(["keys,en,fr", "move.pound.description,\"Pounds, hard.\",Écrase.", "move.pound.name,Pound,Écras'Face"])
	assert_array(_importer.problems).is_empty()


func test_abilities_and_natures_and_their_texts() -> void:
	_world.sandbox.write_json("Data/Studio/abilities/levitate.json", {"klass": "Ability", "id": 26, "dbSymbol": "levitate", "textId": 2})
	_world.sandbox.write_json("Data/Studio/natures/adamant.json", {"klass": "Nature", "id": 1, "dbSymbol": "adamant", "stats": {"atk": 110, "ats": 90}, "flavors": {"liked": "spicy", "disliked": "dry"}})
	_texts(100004, {2: "Levitate,Lévitation"})
	_texts(100005, {2: "Floats.,Flotte."})
	_texts(100008, {1: "Adamant,Rigide"})
	assert_int(_importer.write_abilities()).is_equal(1)
	assert_int(_importer.write_natures()).is_equal(1)
	var levitate := load(_world.sandbox.root + "abilities/levitate.tres") as WgAbility
	assert_array([levitate.number, levitate.name, levitate.description]).is_equal([26, "ability.levitate.name", "ability.levitate.description"])
	var adamant := load(_world.sandbox.root + "natures/adamant.tres") as WgNature
	assert_array([adamant.name, adamant.factor(&"attack"), adamant.factor(&"special_attack"), adamant.liked_flavor]).is_equal(["nature.adamant.name", 110, 90, &"spicy"])
	_importer.write_translations()
	assert_str(FileAccess.get_file_as_string(_world.sandbox.root + "locale/data.csv")).contains("nature.adamant.name,Adamant,Rigide")


func test_the_game_reads_them_with_no_studio_file() -> void:
	_world.sandbox.write_json("Data/Studio/moves/pound.json", {"klass": "Move", "id": 1, "dbSymbol": "pound", "power": 40})
	_texts(100006, {1: "Pound,Écras'Face"})
	_importer.write_moves()
	DirAccess.remove_absolute(_world.sandbox.root + "Data/Studio/moves/pound.json")
	assert_int(_world.moves.find(&"pound").power).is_equal(40)
	assert_str(_world.moves.find(&"pound").name).is_equal("move.pound.name")


func test_the_highest_level_unless_the_game_has_its_own() -> void:
	_world.sandbox.write_json("Data/configs/settings_config.json", {"pokemonMaxLevel": 120})
	assert_str(_importer.write_config()).is_equal(_world.sandbox.root + "config/pokemon.json")
	assert_that(JSON.parse_string(FileAccess.get_file_as_string(_world.sandbox.root + "config/pokemon.json"))).is_equal({"max_level": 120.0})
	_world.sandbox.write_json("Data/configs/settings_config.json", {"pokemonMaxLevel": 90})
	assert_str(_importer.write_config()).is_empty()
	assert_that(JSON.parse_string(FileAccess.get_file_as_string(_world.sandbox.root + "config/pokemon.json"))).is_equal({"max_level": 120.0})


func test_a_broken_file_is_a_problem() -> void:
	_world.sandbox.write_json("Data/Studio/moves/pound.json", {"klass": "Move", "id": 1, "dbSymbol": "tackle"})
	assert_int(_importer.write_moves()).is_equal(0)
	assert_array(_importer.problems).is_equal(["pound.json: not a Studio move"])
