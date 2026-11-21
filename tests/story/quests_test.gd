extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")

var _world: World
var _events: Array[String] = []


func before_test() -> void:
	_world = World.new(self)
	_events = []
	var quests := _world.quests
	quests.started.connect(func(id: StringName) -> void: _events.append("started %s" % id))
	quests.objective_done.connect(func(id: StringName, index: int) -> void: _events.append("done %s %d" % [id, index]))
	quests.finished.connect(func(id: StringName) -> void: _events.append("finished %s" % id))
	quests.failed.connect(func(id: StringName) -> void: _events.append("failed %s" % id))
	quests.register(_quest(&"bell", [
		_objective(&"speak_to", "0"),
		_objective(&"obtain_item", "potion", 3),
		_objective(&"custom", "1", 1, true),
	], [_earning(&"money", [500]), _earning(&"item", ["poke_ball", 10]), _earning(&"pokemon", ["eevee"])]))


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


static func _quest(id: StringName, objectives: Array[WgQuestObjective], earnings: Array[WgQuestEarning] = []) -> WgQuest:
	var quest := WgQuest.new()
	quest.id = id
	quest.objectives = objectives
	quest.earnings = earnings
	return quest


static func _objective(kind: StringName, target: String, amount := 1, hidden := false) -> WgQuestObjective:
	var objective := WgQuestObjective.new()
	objective.kind = kind
	objective.target = target
	objective.amount = amount
	objective.hidden = hidden
	return objective


static func _earning(kind: StringName, args: Array) -> WgQuestEarning:
	var earning := WgQuestEarning.new()
	earning.kind = kind
	earning.args = args
	return earning


func test_a_quest_finishes_the_moment_its_last_objective_is_done() -> void:
	var quests := _world.quests
	assert_bool(quests.start(&"bell")).is_true()
	quests.complete(&"bell", 0)
	quests.record(&"obtain_item", &"potion", 2)
	quests.record(&"obtain_item", &"ball", 5)
	assert_int(quests.progress(&"bell", 1)).is_equal(2)
	quests.record(&"obtain_item", &"potion", 4)
	quests.record(&"obtain_item", &"potion", 1)
	assert_int(quests.progress(&"bell", 1)).is_equal(3)
	quests.reveal(&"bell", 2)
	assert_bool(quests.is_active(&"bell")).is_true()
	quests.add(&"bell", 2)
	assert_bool(quests.is_finished(&"bell")).is_true()
	assert_array(_events).is_equal(["started bell", "done bell 0", "done bell 1", "done bell 2", "finished bell"])


func test_what_happens_before_start_or_while_hidden_counts_for_nothing() -> void:
	var quests := _world.quests
	quests.record(&"obtain_item", &"potion", 3)
	quests.start(&"bell")
	assert_int(quests.progress(&"bell", 1)).is_equal(0)
	quests.complete(&"bell", 2)
	quests.record(&"custom", "1")
	assert_bool(quests.is_done(&"bell", 2)).is_false()
	assert_array(_world.logged).is_equal(["WARN bell: objective 2 is hidden"])


func test_start_refuses_unknown_active_or_finished_quests_and_restarts_a_failed_one() -> void:
	var quests := _world.quests
	assert_bool(quests.start(&"nope")).is_false()
	quests.start(&"bell")
	assert_bool(quests.start(&"bell")).is_false()
	quests.complete(&"bell", 0)
	assert_bool(quests.fail(&"bell")).is_true()
	assert_bool(quests.fail(&"bell")).is_false()
	assert_bool(quests.is_failed(&"bell")).is_true()
	assert_bool(quests.start(&"bell")).is_true()
	assert_bool(quests.is_done(&"bell", 0)).is_false()
	quests.register(_quest(&"empty", []))
	quests.start(&"empty")
	assert_bool(quests.is_finished(&"empty")).is_true()
	assert_bool(quests.start(&"empty")).is_false()
	assert_array(_world.logged).is_equal(["ERROR unknown quest 'nope'"])


func test_earnings_are_given_once_and_a_kind_nobody_gives_is_logged() -> void:
	var quests := _world.quests
	var given: Array[String] = []
	quests.add_earning(&"money", func(amount: int) -> void: given.append("money %d" % amount))
	quests.add_earning(&"item", func(item: String, count: int) -> void: given.append("%s x%d" % [item, count]))
	quests.start(&"bell")
	assert_bool(quests.claim(&"bell")).is_false()
	quests.complete(&"bell", 0)
	quests.complete(&"bell", 1)
	quests.reveal(&"bell", 2)
	quests.complete(&"bell", 2)
	assert_bool(quests.claim(&"bell")).is_true()
	assert_bool(quests.claim(&"bell")).is_false()
	assert_array(given).is_equal(["money 500", "poke_ball x10"])
	assert_array(_world.logged).is_equal(["ERROR bell: nobody gives the earning 'pokemon'"])


func test_a_target_more_than_a_name_is_matched_by_the_hook_and_an_empty_one_takes_anything() -> void:
	var quests := _world.quests
	quests.register(_quest(&"froslass", [_objective(&"catch_pokemon", "", 1)]))
	quests.register(_quest(&"eggs", [_objective(&"obtain_egg", "", 2)]))
	_world.hooks.add(&"quest_match", &"pokemon", func(matches: bool, objective: WgQuestObjective, target: Variant) -> bool:
		return target is Dictionary and target.get("species") == "froslass" if objective.kind == &"catch_pokemon" else matches)
	quests.start(&"froslass")
	quests.start(&"eggs")
	quests.record(&"catch_pokemon", {"species": "snorunt"})
	assert_bool(quests.is_finished(&"froslass")).is_false()
	quests.record(&"catch_pokemon", {"species": "froslass"})
	assert_bool(quests.is_finished(&"froslass")).is_true()
	quests.record(&"obtain_egg", null, 2)
	assert_bool(quests.is_finished(&"eggs")).is_true()


func test_conditions_read_quests() -> void:
	var story := _world.story
	assert_bool(story.check("!quest_active:bell, !quest:bell, !quest_failed:bell")).is_true()
	_world.quests.start(&"bell")
	assert_bool(story.check("quest_active:bell")).is_true()
	_world.quests.fail(&"bell")
	assert_bool(story.check("quest_failed:bell, !quest:bell")).is_true()
	_world.quests.register(_quest(&"empty", []))
	_world.quests.start(&"empty")
	assert_bool(story.check("quest:empty")).is_true()


func test_progress_goes_through_json_and_back() -> void:
	var quests := _world.quests
	quests.start(&"bell")
	quests.record(&"obtain_item", &"potion", 2)
	quests.reveal(&"bell", 2)
	var saved: Variant = JSON.parse_string(JSON.stringify(quests.state()))
	quests.reset()
	assert_bool(quests.is_active(&"bell")).is_false()
	quests.restore(saved)
	assert_bool(quests.is_active(&"bell")).is_true()
	assert_int(quests.progress(&"bell", 1)).is_equal(2)
	assert_bool(quests.is_revealed(&"bell", 2)).is_true()
	quests.record(&"obtain_item", &"potion", 1)
	assert_bool(quests.is_done(&"bell", 1)).is_true()


func test_wrong_calls_are_logged() -> void:
	var quests := _world.quests
	quests.complete(&"bell", 7)
	quests.register(WgQuest.new())
	assert_array(_world.logged).is_equal(["ERROR bell has no objective 7", "ERROR a quest needs an id"])


func test_quests_are_registered_else_resources_of_the_quests_folder_else_a_source_s() -> void:
	var folder := _world.sandbox.root + "quests/"
	DirAccess.make_dir_recursive_absolute(folder)
	ResourceSaver.save(_quest(&"bell", [_objective(&"speak_to", "9")]), folder + "bell.tres")
	ResourceSaver.save(_quest(&"egg", [_objective(&"hatch_egg", "")]), folder + "egg.tres")
	ResourceSaver.save(WgDisplayConfig.new(), folder + "odd.tres")
	var asked := [0]
	_world.quests.add_source(func() -> Array:
		asked[0] += 1
		return [_quest(&"egg", []), _quest(&"race", [_objective(&"custom", "1")]), "not a quest"])
	assert_str(_world.quests.quest(&"bell").objectives[0].target).is_equal("0")
	assert_str(_world.quests.quest(&"egg").objectives[0].kind).is_equal("hatch_egg")
	assert_object(_world.quests.quest(&"race")).is_not_null()
	_world.quests.quest(&"race")
	assert_int(asked[0]).is_equal(1)
	assert_array(_world.logged).is_equal(["ERROR odd.tres: not a WgQuest"])
