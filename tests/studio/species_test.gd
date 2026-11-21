extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const StudioProject := preload("res://tests/support/studio_project.gd")

var _world: World
var _studio: StudioProject.Studio


func before_test() -> void:
	_world = World.new(self)
	_world.sandbox.set_setting("wildgrass/paths/graphics", _world.sandbox.root + "graphics/")
	_world.sandbox.set_setting("wildgrass/paths/audio", _world.sandbox.root + "audio/")


func after_test() -> void:
	if _studio != null:
		_studio.uninstall()
	TranslationServer.set_locale("en")
	_world.root.free()
	_world.cleanup()


func _form(form: int, extra := {}) -> Dictionary:
	var data := {
		"form": form, "formTextId": {"name": 24 + form, "description": 7 * form},
		"height": 0.3, "weight": 3.5, "type1": "normal", "type2": "__undef__",
		"baseHp": 30, "baseAtk": 56, "baseDfe": 35, "baseSpd": 72, "baseAts": 25, "baseDfs": 35,
		"evHp": 0, "evAtk": 0, "evDfe": 0, "evSpd": 1, "evAts": 0, "evDfs": 0,
		"evolutions": [{"dbSymbol": "raticate", "form": form, "conditions": [{"type": "minLevel", "value": 20}]}],
		"experienceType": 1, "baseExperience": 51, "baseLoyalty": 70, "catchRate": 255, "femaleRate": 50,
		"breedGroups": [5, 5], "hatchSteps": 3840, "babyDbSymbol": "rattata", "babyForm": form,
		"itemHeld": [{"dbSymbol": "chilan_berry", "chance": 5}, {"dbSymbol": "none", "chance": 0}],
		"abilities": ["run_away", "guts", "hustle"], "frontOffsetY": 2,
		"resources": {"icon": "0019", "iconShiny": "0019s", "front": "0019", "frontShiny": "0019s", "back": "0019", "backShiny": "0019s",
			"footprint": "0019", "character": "0019", "characterShiny": "0019s", "cry": "0019.ogg", "hasFemale": false},
		"moveSet": [
			{"move": "tackle", "klass": "LevelLearnableMove", "level": 1},
			{"move": "toxic", "klass": "TechLearnableMove"},
			{"move": "covet", "klass": "TutorLearnableMove"},
			{"move": "counter", "klass": "BreedLearnableMove"},
			{"move": "scary_face", "klass": "EvolutionLearnableMove"},
		],
	}
	data.merge(extra, true)
	return data


func _rattata() -> void:
	_world.sandbox.write_json("Data/Studio/pokemon/rattata.json", {"klass": "Specie", "id": 19, "dbSymbol": "rattata", "forms": [
		_form(0), _form(1, {"type1": "dark", "type2": "normal", "resources": {"front": "0019_01", "frontF": "0019_01f", "frontShinyF": "0019_01sf", "cry": ""}}),
	]})


func test_studio_s_species_become_the_engine_s() -> void:
	_rattata()
	_studio = StudioProject.install(_world)
	var rattata := _world.species.find(&"rattata")
	assert_int(rattata.number).is_equal(19)
	assert_int(rattata.generation).is_equal(1)
	assert_str(rattata.name).is_equal("{text:100000:19}")
	assert_str(rattata.genus).is_equal("{text:100001:19}")
	assert_str(rattata.description).is_equal("{text:100002:19}")
	var form := rattata.forms[0]
	assert_str(form.name).is_empty()
	assert_str(form.description).is_empty()
	assert_float(form.height).is_equal(0.3)
	assert_float(form.weight).is_equal(3.5)
	assert_array(form.types).is_equal([&"normal"])
	assert_that(form.base_stats).is_equal({&"hp": 30, &"attack": 56, &"defense": 35, &"special_attack": 25, &"special_defense": 35, &"speed": 72})
	assert_that(form.effort[&"speed"]).is_equal(1)
	assert_array([form.catch_rate, form.base_experience, form.growth_rate, form.base_friendship, form.hatch_steps, form.front_offset_y]).is_equal([255, 51, 1, 70, 3840, 2])
	assert_float(form.female_rate).is_equal(50.0)
	assert_array(form.egg_groups).is_equal([5, 5])
	assert_str(form.baby).is_equal("rattata")
	assert_that(form.held_items).is_equal([{"item": &"chilan_berry", "chance": 5.0}])
	assert_array(form.abilities).is_equal([&"run_away", &"guts", &"hustle"])
	assert_that(form.evolutions).is_equal([{"species": &"raticate", "form": 0, "conditions": [{"type": &"minLevel", "value": 20.0}]}])
	assert_array(form.moves.map(func(move: Dictionary) -> String: return "%s %s %d" % [move["move"], move["how"], move["level"]])).is_equal(["tackle level 1", "toxic tm 0", "covet tutor 0", "counter egg 0", "scary_face evolution 0"])
	var graphics := _world.sandbox.root + "graphics/"
	assert_that(form.pictures).is_equal({
		&"icon": graphics + "pokedex/pokeicon/0019.png", &"icon_shiny": graphics + "pokedex/pokeiconshiny/0019s.png",
		&"front": graphics + "pokedex/pokefront/0019.png", &"front_shiny": graphics + "pokedex/pokefrontshiny/0019s.png",
		&"back": graphics + "pokedex/pokeback/0019.png", &"back_shiny": graphics + "pokedex/pokebackshiny/0019s.png",
		&"footprint": graphics + "pokedex/footprints/0019.png",
		&"character": graphics + "characters/0019.png", &"character_shiny": graphics + "characters/0019s.png",
		&"cry": _world.sandbox.root + "audio/se/cries/0019.ogg",
	})


func test_another_form_has_its_own_texts_types_and_pictures() -> void:
	_rattata()
	_studio = StudioProject.install(_world)
	var alolan := _world.species.form(&"rattata", 1)
	assert_str(alolan.name).is_equal("{text:100067:25}")
	assert_str(alolan.description).is_equal("{text:100068:7}")
	assert_array(alolan.types).is_equal([&"dark", &"normal"])
	var graphics := _world.sandbox.root + "graphics/pokedex/"
	assert_that(alolan.pictures).is_equal({
		&"front": graphics + "pokefront/0019_01.png", &"front_female": graphics + "pokefront/0019_01f.png",
		&"front_shiny_female": graphics + "pokefrontshiny/0019_01sf.png",
	})


func test_the_names_say_studio_s_words_in_the_language() -> void:
	var lines := PackedStringArray(["en,fr"])
	for row in 20:
		lines.append("x,x")
	lines[20] = "Rattata,Rattata"
	_world.sandbox.write("Data/Text/Dialogs/100000.csv", "\n".join(lines) + "\n")
	lines[20] = "Mouse Pokémon,Pokémon Souris"
	_world.sandbox.write("Data/Text/Dialogs/100001.csv", "\n".join(lines) + "\n")
	_rattata()
	_studio = StudioProject.install(_world)
	_world.texts.language = "fr"
	assert_str(_world.texts.label(_world.species.find(&"rattata").genus)).is_equal("Pokémon Souris")


func test_every_species_is_listed_unread_and_a_game_s_wins() -> void:
	_rattata()
	_world.sandbox.write_json("Data/Studio/pokemon/pikachu.json", {"klass": "Specie", "id": 25, "dbSymbol": "pikachu", "forms": [_form(0)]})
	_world.sandbox.write("Data/Studio/pokemon/broken.json", "{")
	var mine := WgSpecies.new()
	mine.id = &"pikachu"
	mine.number = 25
	_world.species.register(mine)
	_studio = StudioProject.install(_world)
	assert_array(_world.species.ids()).contains_exactly_in_any_order([&"pikachu", &"rattata", &"broken"])
	assert_object(_world.species.find(&"pikachu")).is_same(mine)
	assert_object(_world.species.find(&"broken")).is_null()
	assert_array(_world.species.all().map(func(species: WgSpecies) -> StringName: return species.id)).is_equal([&"rattata", &"pikachu"])
	assert_array(_world.logged).is_equal(["ERROR broken.json: not a Studio species", "ERROR unknown species 'broken'"])


func test_the_generation_follows_the_national_number() -> void:
	var seen: Array[int] = []
	for number: int in [0, 1, 151, 152, 386, 387, 905, 906, 1025, 1026]:
		seen.append(StudioProject.Studio.StudioSpecies.generation_of(number))
	assert_array(seen).is_equal([0, 1, 1, 2, 3, 4, 8, 9, 9, 0])


func test_studio_s_types_become_the_engine_s() -> void:
	_world.sandbox.write_json("Data/Studio/types/fire.json", {"textId": 9, "klass": "Type", "id": 2, "dbSymbol": "fire", "color": "#ff5733",
		"damageTo": [{"defensiveType": "grass", "factor": 2}, {"defensiveType": "water", "factor": 0.5}]})
	_world.sandbox.write_json("Data/Studio/types/grass.json", {"textId": 11, "klass": "Type", "id": 5, "dbSymbol": "grass", "color": "#28bc75", "damageTo": []})
	_world.sandbox.write_json("Data/Studio/types/water.json", {"textId": 10, "klass": "Type", "id": 3, "dbSymbol": "water", "color": "#3399ff", "damageTo": []})
	var mine := WgType.new()
	mine.id = &"water"
	_world.types.register(mine)
	_studio = StudioProject.install(_world)
	assert_object(_world.types.find(&"water")).is_same(mine)
	var fire := _world.types.find(&"fire")
	assert_str(fire.name).is_equal("{text:100003:9}")
	assert_str(fire.color.to_html(false)).is_equal("ff5733")
	assert_that(fire.damage).is_equal({&"grass": 2.0, &"water": 0.5})
	assert_float(_world.types.factor(&"fire", [&"grass", &"water"])).is_equal(1.0)
	assert_array(_world.types.ids()).contains_exactly_in_any_order([&"fire", &"grass", &"water"])


func test_studio_s_pokedexes_become_the_engine_s_the_regional_one_shown_first() -> void:
	_rattata()
	_world.sandbox.write_json("Data/Studio/dex/regional.json", {"klass": "Dex", "dbSymbol": "regional", "id": 1, "csv": {"csvFileId": 100063, "csvTextIndex": 7}, "startId": 0,
		"creatures": [{"dbSymbol": "rattata", "form": 1}, {"dbSymbol": "pikachu", "form": 0}]})
	_world.sandbox.write("Data/Studio/dex/broken.json", "[]")
	var mine := WgDex.new()
	mine.id = &"mine"
	_world.pokedex.register(mine)
	_studio = StudioProject.install(_world)
	var regional := _world.pokedex.find(&"regional")
	assert_str(regional.name).is_equal("{text:100063:7}")
	assert_int(regional.start).is_equal(0)
	assert_that(regional.creatures).is_equal([{"species": &"rattata", "form": 1}, {"species": &"pikachu", "form": 0}])
	assert_array(_world.pokedex.dexes).is_equal([&"regional"])
	assert_object(_world.pokedex.find(&"broken")).is_null()
	assert_object(_world.pokedex.find(&"mine")).is_same(mine)
	assert_str(_world.logged[0]).is_equal("ERROR broken.json: not a Studio Pokédex")


func test_without_a_regional_pokedex_the_national_one_is_shown() -> void:
	_studio = StudioProject.install(_world)
	assert_array(_world.pokedex.dexes).is_equal([&"national"])
