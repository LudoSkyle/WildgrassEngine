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


func _thunder_punch(extra := {}) -> void:
	var data := {
		"klass": "Move", "id": 9, "dbSymbol": "thunder_punch", "mapUse": 0, "battleEngineMethod": "s_basic",
		"type": "electric", "power": 75, "accuracy": 100, "pp": 15, "category": "physical",
		"movecriticalRate": 2, "priority": 0,
		"isAuthentic": false, "isBallistics": false, "isBite": false, "isBlocable": true, "isCharge": false,
		"isDance": false, "isDirect": true, "isEffectChance": true, "isGravity": false, "isHeal": false,
		"isKingRockUtility": true, "isMagicCoatAffected": false, "isMental": false, "isMirrorMove": true,
		"isNonSkyBattle": false, "isPowder": false, "isPulse": false, "isPunch": true, "isRecharge": false,
		"isSnatchable": false, "isSoundAttack": false, "isSlicingAttack": false, "isUnfreeze": false, "isWind": false,
		"battleEngineAimedTarget": "adjacent_pokemon",
		"battleStageMod": [{"battleStage": "SPD_STAGE", "modificator": -1}, {"battleStage": "EVA_STAGE", "modificator": 2}],
		"moveStatus": [{"status": "PARALYZED", "luckRate": 10}, {"status": "FLINCH", "luckRate": 20}],
		"effectChance": 10, "condition": "cool", "appeal": 4, "jam": 0,
		"comboMoves": ["charge"], "effectTags": ["bonus_first"],
	}
	data.merge(extra, true)
	_world.sandbox.write_json("Data/Studio/moves/thunder_punch.json", data)


func test_a_studio_move_becomes_the_engine_s() -> void:
	_thunder_punch()
	_studio = StudioProject.install(_world)
	var move := _world.moves.find(&"thunder_punch")
	assert_int(move.number).is_equal(9)
	assert_array([move.name, move.description, move.contest_description]).is_equal(["{text:100006:9}", "{text:100007:9}", "{text:100072:9}"])
	assert_str(move.type).is_equal("electric")
	assert_int(move.category).is_equal(WgMove.Category.PHYSICAL)
	assert_array([move.power, move.accuracy, move.pp, move.priority, move.critical_rate, move.effect_chance, move.map_use]).is_equal([75, 100, 15, 0, 2, 10, 0])
	assert_str(move.target).is_equal("adjacent_pokemon")
	assert_array(move.flags).contains_exactly_in_any_order([&"contact", &"protectable", &"mirrorable", &"punch", &"flinch_item"])
	assert_str(move.effect).is_equal("s_basic")
	assert_that(move.stat_changes).is_equal([{"stat": &"speed", "stages": -1}, {"stat": &"evasion", "stages": 2}])
	assert_that(move.statuses).is_equal([{"status": &"paralysis", "chance": 10}, {"status": &"flinch", "chance": 20}])
	assert_array([move.contest_condition, move.appeal, move.jam]).is_equal([&"cool", 4, 0])
	assert_array(move.combo_moves).is_equal([&"charge"])
	assert_array(move.contest_effects).is_equal([&"bonus_first"])


func test_each_studio_flag_is_read() -> void:
	var extra := {}
	for key: String in StudioProject.Studio._StudioSpecies.MOVE_FLAGS:
		extra[key] = true
	_thunder_punch(extra)
	_studio = StudioProject.install(_world)
	assert_array(_world.moves.find(&"thunder_punch").flags).contains_exactly_in_any_order(WgMove.FLAGS)


func test_a_special_and_a_status_move() -> void:
	_thunder_punch({"category": "special"})
	_world.sandbox.write_json("Data/Studio/moves/growl.json", {"klass": "Move", "id": 45, "dbSymbol": "growl", "category": "status", "battleEngineAimedTarget": "adjacent_all_foe"})
	_studio = StudioProject.install(_world)
	assert_int(_world.moves.find(&"thunder_punch").category).is_equal(WgMove.Category.SPECIAL)
	var growl := _world.moves.find(&"growl")
	assert_int(growl.category).is_equal(WgMove.Category.STATUS)
	assert_str(growl.target).is_equal("adjacent_all_foe")
	assert_array(growl.flags).is_empty()


func test_an_ability_s_texts_follow_its_text_id() -> void:
	_world.sandbox.write_json("Data/Studio/abilities/levitate.json", {"klass": "Ability", "id": 26, "dbSymbol": "levitate", "textId": 30})
	_studio = StudioProject.install(_world)
	var levitate := _world.abilities.find(&"levitate")
	assert_int(levitate.number).is_equal(26)
	assert_array([levitate.name, levitate.description]).is_equal(["{text:100004:30}", "{text:100005:30}"])


func test_a_nature_s_stats_and_flavors() -> void:
	_world.sandbox.write_json("Data/Studio/natures/adamant.json", {"klass": "Nature", "id": 3, "dbSymbol": "adamant",
		"stats": {"atk": 110, "dfe": 100, "spd": 100, "ats": 90, "dfs": 100}, "flavors": {"liked": "spicy", "disliked": "dry"}})
	_world.sandbox.write_json("Data/Studio/natures/hardy.json", {"klass": "Nature", "id": 0, "dbSymbol": "hardy",
		"stats": {"atk": 100, "dfe": 100, "spd": 100, "ats": 100, "dfs": 100}, "flavors": {"liked": "none", "disliked": "none"}})
	_studio = StudioProject.install(_world)
	var adamant := _world.natures.find(&"adamant")
	assert_int(adamant.number).is_equal(3)
	assert_str(adamant.name).is_equal("{text:100008:3}")
	assert_that(adamant.stats).is_equal({&"attack": 110, &"defense": 100, &"speed": 100, &"special_attack": 90, &"special_defense": 100})
	assert_array([adamant.liked_flavor, adamant.disliked_flavor]).is_equal([&"spicy", &"dry"])
	var hardy := _world.natures.find(&"hardy")
	assert_array([hardy.liked_flavor, hardy.disliked_flavor]).is_equal([&"", &""])
	assert_int(_world.natures.count()).is_equal(2)
	assert_str(_world.natures.of_number(3).id).is_equal("adamant")


func test_every_one_is_listed_and_a_game_s_wins() -> void:
	_thunder_punch()
	_world.sandbox.write_json("Data/Studio/abilities/levitate.json", {"klass": "Ability", "id": 26, "dbSymbol": "levitate", "textId": 26})
	_world.sandbox.write_json("Data/Studio/natures/hardy.json", {"klass": "Nature", "id": 0, "dbSymbol": "hardy"})
	_studio = StudioProject.install(_world)
	var own := WgMove.new()
	own.id = &"thunder_punch"
	own.power = 90
	_world.moves.register(own)
	assert_int(_world.moves.find(&"thunder_punch").power).is_equal(90)
	assert_array(_world.moves.ids()).is_equal([&"thunder_punch"])
	assert_array(_world.abilities.ids()).is_equal([&"levitate"])
	assert_array(_world.natures.ids()).is_equal([&"hardy"])


func test_a_file_that_is_not_its_own_is_refused() -> void:
	_world.sandbox.write_json("Data/Studio/moves/tackle.json", {"klass": "Move", "id": 33, "dbSymbol": "pound"})
	_studio = StudioProject.install(_world)
	assert_object(_world.moves.find(&"tackle")).is_null()
	assert_array(_world.logged).contains(["ERROR tackle.json: not a Studio move"])


func test_the_max_level_is_studio_s() -> void:
	_world.sandbox.write_json("Data/configs/settings_config.json", {"pokemonMaxLevel": 120})
	_studio = StudioProject.install(_world)
	assert_int((_world.config.get_config(&"pokemon") as WgPokemonConfig).max_level).is_equal(120)
