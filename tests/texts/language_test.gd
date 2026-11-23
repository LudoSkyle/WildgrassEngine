extends GdUnitTestSuite

const TextWorld := preload("res://tests/support/text_world.gd")

var _world: TextWorld


func before_test() -> void:
	_world = TextWorld.new()


func after_test() -> void:
	_world.cleanup()


func _config(values: Dictionary) -> void:
	_world.sandbox.write_json("config/language.json", values)


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
	other.sandbox.write_json("config/language.json", {"default": "es"})
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
	chosen.sandbox.write_json("config/language.json", {"choosable": ["fr", "en"]})
	assert_array(chosen.texts.languages()).is_equal(["fr", "en"])
	chosen.sandbox.cleanup()


func test_a_language_is_named_in_its_own_language_else_by_godot() -> void:
	_config({"choosable": ["fr", "en", "de"], "names": ["Français", ""]})
	assert_str(_world.texts.language_name("fr")).is_equal("Français")
	assert_str(_world.texts.language_name("en")).is_equal("English")
	assert_str(_world.texts.language_name("de")).is_equal("German")
	assert_array(_world.logged).is_equal(["WARN language.json: names has 2 names for 3 languages"])


func test_a_label_reads_in_another_language_and_nothing_is_told() -> void:
	var french := Translation.new()
	french.locale = "fr"
	french.add_message("Hello {name}", "Bonjour {name}")
	TranslationServer.add_translation(french)
	_world.texts.language = "en"
	var changes: Array[String] = []
	_world.texts.language_changed.connect(func(code: String) -> void: changes.append(code))
	var read := _world.texts.label_in("fr", "Hello {name}", {"name": "Alix"})
	var shown := _world.texts.label("Hello {name}", {"name": "Alix"})
	TranslationServer.remove_translation(french)
	assert_str(read).is_equal("Bonjour Alix")
	assert_str(shown).is_equal("Hello Alix")
	assert_str(_world.texts.language).is_equal("en")
	assert_str(_world.texts.reading_language()).is_equal("en")
	assert_array(changes).is_empty()


func test_a_text_is_given_in_a_language_when_it_has_its_own_words_there() -> void:
	var french := Translation.new()
	french.locale = "fr"
	french.add_message("Bag", "Sac")
	TranslationServer.add_translation(french)
	var given := [_world.texts.is_given_in("fr", "Bag"), _world.texts.is_given_in("fr", "Box"), _world.texts.is_given_in("de", "Box"), _world.texts.is_given_in("fr", "  ")]
	_world.texts.add_placeholder("line", func(argument: String) -> String: return argument, func(argument: String, code: String) -> bool: return code == "en" or argument == "1")
	given.append_array([_world.texts.is_given_in("fr", "{line:1}"), _world.texts.is_given_in("fr", "{line:2}"), _world.texts.is_given_in("en", "{line:2}")])
	TranslationServer.remove_translation(french)
	assert_array(given).is_equal([true, false, true, false, true, false, true])


func test_the_language_read_follows_label_in_nested_and_an_override_set_elsewhere() -> void:
	_world.texts.language = "en"
	var read: Array[String] = []
	_world.texts.add_placeholder("lang", func(_argument: String) -> String:
		read.append(_world.texts.reading_language())
		if read.size() == 1:
			_world.texts.label_in("de", "{lang:x}")
		return "")
	_world.texts.label_in("fr", "{lang:x}{lang:y}")
	var main := TranslationServer.get_or_add_domain(&"")
	main.set_locale_override("it")
	read.append(_world.texts.reading_language())
	main.set_locale_override("")
	read.append(_world.texts.reading_language())
	assert_array(read).is_equal(["fr", "de", "fr", "it", "en"])
