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


func _pichu() -> void:
	_world.sandbox.set_setting("wildgrass/paths/graphics", _world.sandbox.root + "game/graphics/")
	_world.sandbox.set_setting("wildgrass/paths/audio", _world.sandbox.root + "game/audio/")
	_world.sandbox.write_json("Data/Studio/pokemon/pichu.json", {"klass": "Specie", "id": 172, "dbSymbol": "pichu", "forms": [
		{"form": 0, "formTextId": {"name": 0, "description": 0}, "type1": "electric", "type2": "__undef__", "baseHp": 20,
			"resources": {"front": "0172", "frontShiny": "0172s", "icon": "0172", "cry": "0172.ogg"}},
		{"form": 1, "formTextId": {"name": 3, "description": 0}, "type1": "electric", "type2": "__undef__"},
	]})
	_world.sandbox.write("graphics/pokedex/pokefront/0172.png", "front")
	_world.sandbox.write("graphics/pokedex/pokefrontshiny/0172s.png", "shiny")
	_world.sandbox.write("audio/se/cries/0172.ogg", "cry")
	_texts(100000, {172: "Pichu,Pichu"})
	_texts(100001, {172: "Tiny Mouse,Minisouris"})
	_texts(100002, {172: "Small.,Petit."})
	_texts(100067, {3: "Spiky,Pointu"})


func test_species_become_the_game_s_their_pictures_and_cry_copied() -> void:
	_pichu()
	assert_int(_importer.write_species()).is_equal(1)
	var pichu := load(_world.sandbox.root + "pokemon/pichu.tres") as WgSpecies
	assert_array([pichu.number, pichu.name, pichu.genus, pichu.description]).is_equal([172, "species.pichu.name", "species.pichu.genus", "species.pichu.description"])
	var form := pichu.forms[0]
	assert_array([form.name, form.description, form.base_stats[&"hp"]]).is_equal(["", "", 20])
	var game := _world.sandbox.root + "game/"
	assert_that(form.pictures).is_equal({
		&"front": game + "graphics/pokedex/pokefront/0172.png", &"front_shiny": game + "graphics/pokedex/pokefrontshiny/0172s.png",
		&"cry": game + "audio/cries/0172.ogg",
	})
	assert_str(FileAccess.get_file_as_string(game + "graphics/pokedex/pokefrontshiny/0172s.png")).is_equal("shiny")
	assert_str(FileAccess.get_file_as_string(game + "audio/cries/0172.ogg")).is_equal("cry")
	assert_int(_importer.copied).is_equal(3)
	assert_str(pichu.forms[1].name).is_equal("species.pichu.form_1.name")
	_importer.write_translations()
	var words := FileAccess.get_file_as_string(_world.sandbox.root + "locale/data.csv")
	for line: String in ["species.pichu.genus,Tiny Mouse,Minisouris", "species.pichu.form_1.name,Spiky,Pointu"]:
		assert_str(words).contains(line)
	assert_array(_importer.problems).is_empty()


func test_a_file_copied_already_the_same_is_not_copied_again() -> void:
	_pichu()
	_importer.write_species()
	_importer.copied = 0
	_world.sandbox.write("audio/se/cries/0172.ogg", "another cry")
	_importer.write_species()
	assert_int(_importer.copied).is_equal(1)
	assert_str(FileAccess.get_file_as_string(_world.sandbox.root + "game/audio/cries/0172.ogg")).is_equal("another cry")


func test_types_and_their_names() -> void:
	_world.sandbox.write_json("Data/Studio/types/fire.json", {"klass": "Type", "id": 2, "dbSymbol": "fire", "textId": 2, "color": "#ff0000", "damageTo": [{"defensiveType": "grass", "factor": 2}]})
	_texts(100003, {2: "Fire,Feu"})
	assert_int(_importer.write_types()).is_equal(1)
	var fire := load(_world.sandbox.root + "types/fire.tres") as WgType
	assert_array([fire.name, fire.factor_against(&"grass")]).is_equal(["type.fire.name", 2.0])
