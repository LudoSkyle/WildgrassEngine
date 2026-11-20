extends GdUnitTestSuite

const TextWorld := preload("res://tests/support/text_world.gd")
const StudioImport := preload("res://addons/wildgrass/texts/studio_import.gd")

## Species: a header, then one line per text.
const SPECIES := "en,fr,kana\nEgg,Œuf,タマゴ\nBulbasaur,Bulbizarre,フシギダネ\n\"Seed, Pokémon\\nlof grass\",,\n"

var _world: TextWorld


func before_test() -> void:
	_world = TextWorld.new()
	_world.sandbox.write("Data/Text/Dialogs/100000.csv", SPECIES)


func after_test() -> void:
	_world.cleanup()


func _studio(line: int) -> String:
	return _world.texts.studio(100000, line)


func test_a_line_is_read_in_the_current_language() -> void:
	_world.texts.language = "fr"
	assert_str(_studio(1)).is_equal("Bulbizarre")
	_world.texts.language = "en"
	assert_str(_studio(1)).is_equal("Bulbasaur")


func test_a_regional_locale_reads_its_language_and_a_mapped_one_its_column() -> void:
	_world.sandbox.write_json("Data/configs/language_config.json", {"studioColumns": {"ja": "kana"}})
	_world.texts.language = "fr_FR"
	assert_str(_studio(0)).is_equal("Œuf")
	_world.texts.language = "ja"
	assert_str(_studio(0)).is_equal("タマゴ")


func test_an_empty_cell_falls_back_to_the_fallback_locale_then_the_first_column() -> void:
	_world.texts.language = "fr"
	assert_str(_studio(2)).is_equal("Seed, Pokémon\nof grass")
	_world.sandbox.write("Data/Text/Dialogs/9001.csv", "de,en,fr\nBälle,Balls,\nNur,,\n")
	assert_str(_world.texts.studio(9001, 0)).is_equal("Balls")
	assert_str(_world.texts.studio(9001, 1)).is_equal("Nur")


func test_a_cell_studio_left_untranslated_falls_back_as_an_empty_one() -> void:
	_world.sandbox.write("Data/Text/Dialogs/100045.csv", "en,fr,it\nThe Tower,La Tour,[~ 0]\n[~ 1],Les étages,[~ 1]\n[~ 2],[~ 2],[~ 2]\n")
	_world.texts.language = "it"
	assert_str(_world.texts.studio(100045, 0)).is_equal("The Tower")
	assert_str(_world.texts.studio(100045, 1)).is_equal("Les étages")
	assert_str(_world.texts.studio(100045, 2)).is_empty()


func test_a_whole_file_is_given_in_the_current_language() -> void:
	_world.texts.language = "fr"
	assert_array(Array(_world.texts.studio_file(100000))).is_equal(["Œuf", "Bulbizarre", "Seed, Pokémon\nof grass"])


func test_a_file_is_read_once_and_serves_every_language() -> void:
	_world.texts.language = "fr"
	assert_str(_studio(1)).is_equal("Bulbizarre")
	_world.sandbox.write("Data/Text/Dialogs/100000.csv", "en,fr\nX,Y\nX,Y\n")
	_world.texts.language = "en"
	assert_str(_studio(1)).is_equal("Bulbasaur")


func test_a_missing_file_or_line_gives_nothing_logged_once() -> void:
	assert_str(_world.texts.studio(100099, 0)).is_empty()
	assert_str(_world.texts.studio(100099, 1)).is_empty()
	assert_array(Array(_world.texts.studio_file(100099))).is_empty()
	assert_str(_studio(3)).is_empty()
	assert_str(_studio(3)).is_empty()
	assert_str(_studio(-1)).is_empty()
	assert_array(_world.logged).is_equal([
		"WARN no Studio text file %sData/Text/Dialogs/100099.csv" % _world.sandbox.root,
		"WARN no line 3 in Studio text file 100000",
		"WARN no line -1 in Studio text file 100000",
	])


func test_studio_text_files_are_set_to_keep_file() -> void:
	var folder := _world.sandbox.root + "Data/Text/Dialogs/"
	var made := _world.sandbox.write("Data/Text/Dialogs/100000.fr.translation", "")
	_world.sandbox.write("Data/Text/Dialogs/100000.csv.import", "[remap]\nimporter=\"csv_translation\"\n[deps]\ndest_files=[\"%s\"]\n" % made)
	_world.sandbox.write("Data/Text/Dialogs/9001.csv", "en\nBalls\n")
	_world.sandbox.write("Data/Text/Dialogs/9002.csv", "en\nKept\n")
	_world.sandbox.write("Data/Text/Dialogs/9002.csv.import", "[remap]\nimporter=\"keep\"\n")
	_world.sandbox.write("Data/Text/Dialogs/notes.txt", "")
	var to_remove: Array[String] = []
	assert_array(Array(StudioImport.keep_files(folder, to_remove))).contains_exactly_in_any_order([folder + "100000.csv", folder + "9001.csv"])
	assert_array(to_remove).is_equal([made])
	for file: String in ["100000.csv.import", "9001.csv.import"]:
		var settings := ConfigFile.new()
		settings.load(folder + file)
		assert_str(settings.get_value("remap", "importer", "")).is_equal("keep")
	assert_array(Array(StudioImport.keep_files(folder))).is_empty()
	assert_array(Array(StudioImport.keep_files(folder + "none/"))).is_empty()
