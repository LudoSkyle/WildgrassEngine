extends GdUnitTestSuite

const EngineWords := preload("res://tests/support/engine_words.gd")
const World := preload("res://tests/support/walking_world.gd")
const StudioProject := preload("res://tests/support/studio_project.gd")

var _world: World
var _studio: StudioProject.Studio


func before_test() -> void:
	_world = World.new(self)


func after_test() -> void:
	if _studio != null:
		_studio.uninstall()
	EngineWords.reset()
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
	_world.sandbox.write("Data/Text/Dialogs/9000.csv", "\n".join(lines) + "\n")
	_world.sandbox.write("Data/Text/Dialogs/100025.csv", "en,fr\nCONTINUE,Continuer\n")
	var title_lines := PackedStringArray(["en,fr"])
	for row in 114:
		title_lines.append("x,x")
	title_lines[78] = "PLAY,JOUER"
	title_lines[114] = "PRESS START,APPUYEZ SUR START"
	_world.sandbox.write("Data/Text/Dialogs/100032.csv", "\n".join(title_lines) + "\n")
	_studio = StudioProject.install(_world)
	_world.texts.language = "fr"
	var words: Array[String] = []
	for key: String in ["wg.title.play", "wg.title.prompt", "wg.title.quit", "wg.slots.new_game", "wg.slots.continue", "wg.slots.erase"]:
		words.append(_world.texts.label(key))
	assert_array(words).is_equal(["JOUER", "APPUYEZ SUR START", "Quitter", "Nouvelle partie", "Continuer", "Effacer"])


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
	# A game's own text for a key wins over Studio's line: none here.
	TranslationServer.clear()
	_studio = StudioProject.install(_world)
	assert_str(_world.texts.label("wg.menu.bag")).is_equal("BAG")
	_world.texts.language = "fr"
	assert_str(_world.texts.label("wg.menu.bag")).is_equal("Sac")
	assert_str(_world.texts.label("wg.menu.pokedex")).is_equal("Pokédex")
	_world.texts.language = "ja"
	assert_str(_world.texts.label("wg.menu.bag")).is_equal("バッグ")
	# No line in the project, no text in the game: the key.
	assert_str(_world.texts.label("wg.options.volume")).is_equal("wg.options.volume")
	_studio.uninstall()
	assert_str(_world.texts.label("wg.menu.bag")).is_equal("wg.menu.bag")


func test_installed_once_only() -> void:
	_world.sandbox.write_json("Data/configs/save_config.json", {"saveKey": 1234})
	_studio = StudioProject.install(_world)
	_studio.install(_world.texts, _world.items, _world.quests, _world.species, _world.types, _world.moves, _world.abilities, _world.natures, _world.pokedex, _world.encounters, _world.zones)
	_world.save.config()
	assert_bool(_studio.installed).is_true()
	assert_int(_world.logged.size()).is_equal(1)


func test_a_godot_project_never_meets_the_layer() -> void:
	var engine := get_tree().root.get_node("Wildgrass")
	assert_object(engine.studio).is_not_null()
	assert_bool(engine.studio.installed).is_false()
	assert_str(engine.texts.label("wg.menu.bag")).is_equal("Bag")


func test_studio_s_sound_design_becomes_the_engine_s_named_sounds() -> void:
	_world.sandbox.write_json("Data/configs/sound_design_config.json", {"klass": "Configs::Project::SoundDesign",
		"soundEffects": {"decision": {"name": "audio/se/select.wav", "pitch": 100, "volume": 80}, "buzzer": {"name": "audio/se/buzzer.ogg", "pitch": 90, "volume": 100}},
		"musicEffects": {"receiveKeyItem": {"name": "audio/me/key.ogg", "volume": 100, "pitch": 100}, "gameOver": {"name": "", "pitch": 100, "volume": 100}},
		"backgroundMusic": {"acroBike": {"name": "audio/bgm/bicycle.ogg", "volume": 100, "pitch": 100}}, "backgroundSound": {}})
	_world.sandbox.write_json("Data/configs/scene_title_config.json", {"bgmName": "audio/bgm/title.ogg"})
	_studio = StudioProject.install(_world)
	var audio := _world.audio.config()
	var root := _world.sandbox.root
	assert_that(audio.folders).is_equal({"music": "bgm", "ambience": "bgs", "jingles": "me", "effects": "se"})
	assert_that(audio.sounds["confirm"]).is_equal({"kind": "effect", "name": root + "audio/se/select.wav", "volume": 80.0, "pitch": 100.0})
	assert_str(audio.sounds["buzzer"]["name"]).is_equal(root + "audio/se/buzzer.ogg")
	assert_that(audio.sounds["key_item"]).is_equal({"kind": "jingle", "name": root + "audio/me/key.ogg", "volume": 100.0, "pitch": 100.0})
	assert_str(audio.sounds["acro_bike"]["kind"]).is_equal("music")
	assert_bool(audio.sounds.has("game_over")).is_false()
	assert_that(audio.sounds["menu"]).is_equal({"kind": "effect", "name": ""})
	assert_str(_world.title.config().music).is_equal(root + "audio/bgm/title.ogg")
	assert_str(_world.audio.path_of(&"effects", StringName(audio.sounds["confirm"]["name"]))).is_equal(root + "audio/se/select.wav")


func test_a_label_in_another_language_reads_studio_s_texts_in_it() -> void:
	_world.sandbox.write("Data/Text/Dialogs/100014.csv", "en,fr\nPOKÉMON,Pokémon\nPOKÉDEX,Pokédex\nBAG,Sac\n")
	_world.sandbox.write("Data/Text/Dialogs/100000.csv", "en,fr\nEgg,Œuf\nBulbasaur,Bulbizarre\n")
	_studio = StudioProject.install(_world)
	_world.texts.language = "en"
	assert_str(_world.texts.label_in("fr", "{text:100000:1}")).is_equal("Bulbizarre")
	assert_str(_world.texts.label_in("fr", "wg.menu.bag")).is_equal("Sac")
	assert_str(_world.texts.label("{text:100000:1}")).is_equal("Bulbasaur")


func test_a_studio_text_is_given_in_a_language_when_its_cell_is_not_empty() -> void:
	_world.sandbox.write("Data/Text/Dialogs/100000.csv", "en,fr\nEgg,Œuf\nBulbasaur,\n")
	_studio = StudioProject.install(_world)
	assert_bool(_world.texts.is_given_in("fr", "{text:100000:0}")).is_true()
	assert_bool(_world.texts.is_given_in("fr", "{text:100000:1}")).is_false()
	assert_bool(_world.texts.is_given_in("en", "{text:100000:1}")).is_true()
	assert_bool(_world.texts.is_given_in("en", "{text:100000:9}")).is_false()
