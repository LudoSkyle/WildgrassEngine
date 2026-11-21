extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const StudioProject := preload("res://tests/support/studio_project.gd")

var _world: World
var _studio: StudioProject.Studio


func before_test() -> void:
	_world = World.new(self)


func after_test() -> void:
	if _studio != null:
		_studio.uninstall()
	TranslationServer.set_locale("en")
	_world.root.free()
	_world.cleanup()


func _write_configs() -> void:
	var configs := {
		"display_config": {"klass": "Configs::Project::Display", "gameResolution": {"x": 256, "y": 192}, "windowScale": 3, "isFullscreen": true, "tilemapSettings": {}},
		"language_config": {"klass": "Configs::Project::Language", "defaultLanguage": "fr", "choosableLanguageCode": ["fr", "en"], "choosableLanguageTexts": ["Français", "English"]},
		"save_config": {"klass": "Configs::Project::Save", "maximumSave": 3, "saveKey": 0, "saveHeader": "PKPRT", "baseFilename": "Saves/Pokemon_Party", "isCanSaveOnAnySave": true},
		"game_options_config": {"klass": "Configs::Project::GameOptions", "order": ["message_speed", "volume", "battle_style"]},
		"settings_config": {"klass": "Configs::Project::Settings", "maxBagItemCount": 999, "pokemonMaxLevel": 100},
	}
	for file: String in configs:
		_world.sandbox.write_json("Data/configs/%s.json" % file, configs[file])


func test_a_studio_project_is_recognised_by_its_file_unless_the_setting_says_otherwise() -> void:
	var studio := StudioProject.Studio.new(_world.paths, _world.logger, _world.config, _world.hooks)
	_world.sandbox.set_setting("wildgrass/paths/studio", _world.sandbox.root)
	assert_bool(studio.is_project()).is_false()
	_world.sandbox.write("project.studio", "{}")
	assert_bool(studio.is_project()).is_true()
	_world.sandbox.set_setting(StudioProject.Studio.SETTING, "off")
	assert_bool(studio.is_project()).is_false()
	DirAccess.remove_absolute(_world.sandbox.root + "project.studio")
	_world.sandbox.set_setting(StudioProject.Studio.SETTING, "on")
	assert_bool(studio.is_project()).is_true()


func test_studio_s_configs_become_the_engine_s() -> void:
	_write_configs()
	_studio = StudioProject.install(_world)
	var display := _world.config.get_config(&"display") as WgDisplayConfig
	assert_that(display.resolution).is_equal(Vector2i(256, 192))
	assert_int(display.window_scale).is_equal(3)
	assert_bool(display.fullscreen).is_true()
	var language := _world.config.get_config(&"language") as WgLanguageConfig
	assert_str(language.default).is_equal("fr")
	assert_array(language.choosable).is_equal(["fr", "en"])
	assert_array(language.names).is_equal(["Français", "English"])
	var save := _world.save.config()
	assert_int(save.slots).is_equal(3)
	assert_str(save.file).is_equal("Saves/Pokemon_Party")
	assert_bool(save.save_anywhere).is_true()
	assert_array(_world.options.config().order).is_equal(["message_speed", "volume", "battle_style"])
	assert_int(_world.items.bag_config().max_count).is_equal(999)
	assert_array(_world.logged).is_empty()


func test_the_project_s_own_config_wins_field_by_field() -> void:
	_write_configs()
	_world.sandbox.write_json("config/save.json", {"slots": 1})
	_studio = StudioProject.install(_world)
	assert_int(_world.save.config().slots).is_equal(1)
	assert_str(_world.save.config().file).is_equal("Saves/Pokemon_Party")


func test_a_save_key_is_logged_and_a_broken_config_too() -> void:
	_world.sandbox.write_json("Data/configs/save_config.json", {"saveKey": 1234})
	_world.sandbox.write("Data/configs/display_config.json", "nope")
	_studio = StudioProject.install(_world)
	_world.save.config()
	_world.config.get_config(&"display")
	assert_array(_world.logged).is_equal([
		"WARN save_config.json: saveKey is for Studio's binary saves; games are written as JSON, not encrypted",
		"ERROR display_config.json: not a JSON object",
	])


func test_studio_s_title_becomes_the_engine_s_the_project_s_own_winning() -> void:
	_world.sandbox.set_setting("wildgrass/paths/graphics", _world.sandbox.root + "graphics/")
	_world.sandbox.write_json("Data/configs/scene_title_config.json", {"klass": "Configs::Project::SceneTitle", "introMovieMapId": 1, "bgmName": "audio/bgm/title.ogg", "isLanguageSelectionEnabled": true, "additionalSplashes": ["workshop", "studio"], "controlWaitTime": 0.5})
	_world.sandbox.write_json("Data/configs/infos_config.json", {"klass": "Configs::Project::Infos", "gameTitle": "Mirage", "gameVersion": 256})
	_world.sandbox.write("graphics/titles/title.png", "")
	_world.sandbox.write_json("config/title.json", {"controls_delay": 1.0})
	_studio = StudioProject.install(_world)
	var title := _world.title.config()
	var titles := _world.sandbox.root + "graphics/titles/"
	assert_array(title.splashes).is_equal([titles + "workshop.png", titles + "studio.png"])
	assert_bool(title.choose_language).is_true()
	assert_float(title.controls_delay).is_equal(1.0)
	assert_str(title.name).is_equal("Mirage")
	assert_bool(title.show_prompt).is_false()
	assert_str(title.logo).is_equal(titles + "title.png")
	assert_str(title.background).is_empty()
	assert_array(_world.logged).is_empty()


func test_the_title_s_words_are_studio_s() -> void:
	var lines := PackedStringArray(["en,fr"])
	for row in 127:
		lines.append("x,x")
	lines[1] = "New game,Nouvelle partie"
	lines[23] = "Erase,Effacer"
	lines[27] = "Exit,Quitter"
	lines[127] = "Play,Jouer"
	_world.sandbox.write("Data/Text/Dialogs/9000.csv", "\n".join(lines) + "\n")
	_world.sandbox.write("Data/Text/Dialogs/100025.csv", "en,fr\nCONTINUE,Continuer\n")
	_studio = StudioProject.install(_world)
	_world.texts.language = "fr"
	var words: Array[String] = []
	for label: String in ["Play", "Quit", "New game", "Continue", "Erase"]:
		words.append(_world.texts.label(label))
	assert_array(words).is_equal(["Jouer", "Quitter", "Nouvelle partie", "Continuer", "Effacer"])


func test_studio_s_pockets_come_in_studio_s_order_with_its_names() -> void:
	_world.sandbox.write("Data/Text/Dialogs/100015.csv", "en,fr\nMedicine,Soins\nPoké Balls,Poké Balls\nBattle Items,Objets de combat\nBerries,Baies\nOther Items,Objets\nTMs,CT\nTreasures,Trésors\nIngredients,Ingrédients\nKey Items,Objets rares\n")
	_studio = StudioProject.install(_world)
	_world.texts.language = "fr"
	var names: Array[String] = []
	for pocket: Dictionary in _world.items.bag_config().pockets:
		names.append(_world.texts.label(pocket["name"]))
	assert_array(names).is_equal(["Objets", "Poké Balls", "Soins", "CT", "Objets rares", "Baies"])
	assert_bool(_world.items.bag_config().pocket(&"key_items")["reveal"]).is_true()


func test_the_engine_s_labels_say_studio_s_words_until_uninstalled() -> void:
	_world.sandbox.write("Data/Text/Dialogs/100014.csv", "en,fr,kana\nPOKÉMON,Pokémon,x\nPOKÉDEX,Pokédex,x\nBAG,Sac,バッグ\n")
	_world.sandbox.write_json("config/studio.json", {"columns": {"ja": "kana"}})
	_studio = StudioProject.install(_world)
	assert_str(_world.texts.label("Bag")).is_equal("BAG")
	_world.texts.language = "fr"
	assert_str(_world.texts.label("Bag")).is_equal("Sac")
	_world.texts.language = "ja"
	assert_str(_world.texts.label("Bag")).is_equal("バッグ")
	assert_str(_world.texts.label("Volume")).is_equal("Volume")
	_studio.uninstall()
	assert_str(_world.texts.label("Bag")).is_equal("Bag")


func test_installed_once_only() -> void:
	_world.sandbox.write_json("Data/configs/save_config.json", {"saveKey": 1234})
	_studio = StudioProject.install(_world)
	_studio.install(_world.texts, _world.items, _world.quests, _world.species, _world.types, _world.pokedex)
	_world.save.config()
	assert_bool(_studio.installed).is_true()
	assert_int(_world.logged.size()).is_equal(1)


func test_a_godot_project_never_meets_the_layer() -> void:
	var engine := get_tree().root.get_node("Wildgrass")
	assert_object(engine.studio).is_not_null()
	assert_bool(engine.studio.installed).is_false()
	assert_str(engine.texts.label("Bag")).is_equal("Bag")
