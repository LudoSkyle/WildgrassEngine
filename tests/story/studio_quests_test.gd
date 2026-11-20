extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")

var _world: World


func before_test() -> void:
	_world = World.new(self)
	_world.sandbox.write_json("Data/Studio/quests/quest_0.json", {
		"klass": "Quest", "id": 0, "dbSymbol": "quest_0", "isPrimary": true, "resolution": "default",
		"objectives": [{"objectiveMethodName": "objective_speak_to", "objectiveMethodArgs": [0, "Malo"], "textFormatMethodName": "text_speak_to", "hiddenByDefault": false}],
		"earnings": [
			{"earningMethodName": "earning_money", "earningArgs": [5000], "textFormatMethodName": "text_earn_money"},
			{"earningMethodName": "earning_item", "earningArgs": ["poke_ball", 10], "textFormatMethodName": "text_earn_item"},
		],
	})
	_world.sandbox.write_json("Data/Studio/quests/quest_2.json", {
		"klass": "Quest", "id": 2, "dbSymbol": "quest_2", "isPrimary": false, "resolution": "default",
		"objectives": [
			{"objectiveMethodName": "objective_beat_npc", "objectiveMethodArgs": [1, "Jules", 2], "textFormatMethodName": "text_beat_npc", "hiddenByDefault": false},
			{"objectiveMethodName": "objective_catch_pokemon", "objectiveMethodArgs": [[{"type": "pokemon", "value": "froslass"}], 1], "textFormatMethodName": "text_catch_pokemon", "hiddenByDefault": true},
			{"objectiveMethodName": "objective_obtain_item", "objectiveMethodArgs": ["potion", 3], "textFormatMethodName": "text_obtain_item", "hiddenByDefault": false},
			{"objectiveMethodName": "objective_hatch_egg", "objectiveMethodArgs": [null, 2], "textFormatMethodName": "text_hatch_egg", "hiddenByDefault": false},
		],
		"earnings": [],
	})
	_world.sandbox.write("Data/Text/Dialogs/100045.csv", "en,fr\nTo the Tower!,Direction la Tour !\n[~ 1],[~ 1]\nA ghost's regrets,Les regrets d'un fantôme\n")


func after_test() -> void:
	TranslationServer.set_locale("en")
	_world.root.free()
	_world.cleanup()


func test_studio_quests_are_read_as_they_are() -> void:
	var first := _world.quests.quest(&"quest_0")
	assert_bool(first.primary).is_true()
	assert_str(first.objectives[0].kind).is_equal("speak_to")
	assert_str(first.objectives[0].target).is_equal("0")
	assert_int(first.objectives[0].amount).is_equal(1)
	assert_array(first.objectives[0].args).is_equal([0.0, "Malo"])
	assert_str(first.earnings[1].kind).is_equal("item")
	assert_array(first.earnings[1].args).is_equal(["poke_ball", 10.0])
	var second := _world.quests.quest(&"quest_2")
	assert_bool(second.primary).is_false()
	var read: Array[String] = []
	for objective in second.objectives:
		read.append("%s %s x%d%s" % [objective.kind, objective.target, objective.amount, " hidden" if objective.hidden else ""])
	assert_array(read).is_equal(["beat_npc 1 x2", "catch_pokemon  x1 hidden", "obtain_item potion x3", "hatch_egg  x2"])


func test_a_studio_quest_name_follows_the_language() -> void:
	var second := _world.quests.quest(&"quest_2")
	_world.texts.language = "fr"
	assert_str(_world.texts.format(second.name)).is_equal("Les regrets d'un fantôme")
	_world.texts.language = "en"
	assert_str(_world.texts.format(second.name)).is_equal("A ghost's regrets")


func test_a_studio_quest_plays_like_any_other() -> void:
	var given: Array[String] = []
	_world.quests.add_earning(&"money", func(amount: float) -> void: given.append("money %d" % amount))
	_world.quests.add_earning(&"item", func(item: String, count: float) -> void: given.append("%s x%d" % [item, count]))
	assert_bool(_world.quests.start(&"quest_0")).is_true()
	_world.quests.complete(&"quest_0", 0)
	_world.quests.claim(&"quest_0")
	assert_array(given).is_equal(["money 5000", "poke_ball x10"])


func test_a_quest_the_game_registers_wins_and_bad_files_are_logged() -> void:
	var own := WgQuest.new()
	own.id = &"quest_0"
	own.name = "My own"
	_world.quests.register(own)
	_world.sandbox.write("Data/Studio/quests/broken.json", "{ not json")
	_world.sandbox.write_json("Data/Studio/quests/odd.json", {"klass": "Quest", "id": 9, "dbSymbol": "odd", "objectives": [{"objectiveMethodName": "objective_dance", "objectiveMethodArgs": ["salsa"]}]})
	assert_str(_world.quests.quest(&"quest_0").name).is_equal("My own")
	assert_str(_world.quests.quest(&"odd").objectives[0].target).is_equal("salsa")
	assert_array(_world.logged).is_equal([
		"ERROR %sData/Studio/quests/broken.json: not a Studio quest" % _world.sandbox.root,
		"WARN odd: unknown objective kind 'dance'",
	])
