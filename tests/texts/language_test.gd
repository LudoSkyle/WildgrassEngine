extends GdUnitTestSuite

const TextWorld := preload("res://tests/support/text_world.gd")

var _world: TextWorld


func before_test() -> void:
	_world = TextWorld.new()


func after_test() -> void:
	_world.cleanup()


func _config(values: Dictionary) -> void:
	_world.sandbox.write_json("Data/configs/language_config.json", values)


func test_setting_the_language_sets_godot_locale_and_announces_it_once() -> void:
	var changes: Array[String] = []
	_world.texts.language_changed.connect(func(code: String) -> void: changes.append(code))
	_world.texts.language = "de"
	_world.texts.language = "de"
	assert_str(TranslationServer.get_locale()).is_equal("de")
	assert_str(_world.texts.language).is_equal("de")
	assert_array(changes).is_equal(["de"])


func test_the_default_language_applies_only_when_set() -> void:
	TranslationServer.set_locale("it")
	_world.texts.apply_default()
	assert_str(_world.texts.language).is_equal("it")
	var other := TextWorld.new()
	other.sandbox.write_json("Data/configs/language_config.json", {"defaultLanguage": "es"})
	other.texts.apply_default()
	assert_str(TranslationServer.get_locale()).is_equal("es")
	other.sandbox.cleanup()


func test_the_choosable_languages_keep_their_order_else_godot_gives_its_own() -> void:
	var italian := Translation.new()
	italian.locale = "it"
	TranslationServer.add_translation(italian)
	assert_array(_world.texts.languages()).contains(["it"])
	TranslationServer.remove_translation(italian)
	var chosen := TextWorld.new()
	chosen.sandbox.write_json("Data/configs/language_config.json", {"choosableLanguageCode": ["fr", "en"]})
	assert_array(chosen.texts.languages()).is_equal(["fr", "en"])
	chosen.sandbox.cleanup()


func test_a_language_is_named_in_its_own_language_else_by_godot() -> void:
	_config({"choosableLanguageCode": ["fr", "en", "de"], "choosableLanguageTexts": ["Français", ""]})
	assert_str(_world.texts.language_name("fr")).is_equal("Français")
	assert_str(_world.texts.language_name("en")).is_equal("English")
	assert_str(_world.texts.language_name("de")).is_equal("German")
	assert_array(_world.logged).is_equal(["WARN language_config.json: choosableLanguageTexts has 2 names for 3 codes"])
