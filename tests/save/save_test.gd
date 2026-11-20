extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")

signal restored_late

var _world: World
var _events: Array[String] = []


func before_test() -> void:
	_world = World.new(self)
	_events = []
	var potion := WgItem.new()
	potion.id = &"potion"
	_world.items.register(potion)
	var save := _world.save
	save.written.connect(func(slot: int) -> void: _events.append("written %d" % slot))
	save.loaded.connect(func(slot: int) -> void: _events.append("loaded %d" % slot))
	save.new_game_started.connect(func(slot: int) -> void: _events.append("new game %d" % slot))
	save.erased.connect(func(slot: int) -> void: _events.append("erased %d" % slot))


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _config(values: Dictionary) -> void:
	_world.sandbox.write_json("Data/configs/save_config.json", values)


func _file(slot: int) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(_world.save.path_of(slot)))


func _play() -> void:
	_world.story.set_flag(&"bell_told")
	_world.story.set_value(&"player", "Ludo")
	_world.bag.add(&"potion", 3)
	_world.bag.add_money(500)
	_world.clock.advance(125.5)


func test_a_game_written_comes_back_whole() -> void:
	_play()
	assert_bool(_world.save.write(1)).is_true()
	assert_str(_world.save.path_of(1)).is_equal(_world.sandbox.root + "saves/Saves/Pokemon_Party-1.json")
	assert_int(_world.save.slot).is_equal(1)
	_world.save.new_game(2)
	assert_bool(_world.story.has(&"bell_told")).is_false()
	assert_int(_world.bag.count(&"potion")).is_equal(0)
	assert_float(_world.clock.seconds).is_equal(0.0)
	assert_bool(await _world.save.load_game(1)).is_true()
	assert_bool(_world.story.has(&"bell_told")).is_true()
	assert_str(_world.story.value(&"player")).is_equal("Ludo")
	assert_int(_world.bag.count(&"potion")).is_equal(3)
	assert_int(_world.bag.money).is_equal(500)
	assert_float(_world.clock.seconds).is_equal(125.5)
	assert_int(_world.save.slot).is_equal(1)
	assert_array(_events).is_equal(["written 1", "new game 2", "loaded 1"])
	var file := _file(1)
	assert_int(int(file["format"])).is_equal(1)
	assert_array(file["parts"].keys()).is_equal(["story", "quests", "bag", "clock"])
	assert_bool(FileAccess.file_exists(_world.save.path_of(1) + ".tmp")).is_false()


func test_with_no_maximum_slots_go_on_after_the_last_used() -> void:
	var save := _world.save
	assert_array(save.slots()).is_equal([1])
	save.write(1)
	save.write(3)
	assert_array(save.slots()).is_equal([1, 2, 3, 4])
	assert_int(save.first_empty()).is_equal(2)


func test_a_maximum_bounds_the_slots_and_a_single_game_has_one_file() -> void:
	_config({"maximumSave": 2})
	var save := _world.save
	assert_array(save.slots()).is_equal([1, 2])
	save.write(1)
	save.write(2)
	assert_int(save.first_empty()).is_equal(0)
	assert_bool(save.write(3)).is_false()
	assert_bool(save.has(3)).is_false()
	_world.config.register(&"save", WgSaveConfig, "save_config")
	_config({"maximumSave": 1, "baseFilename": "game"})
	assert_str(save.path_of(1)).is_equal(_world.sandbox.root + "saves/game.json")
	assert_array(save.slots()).is_equal([1])
	assert_array(_world.logged).is_equal(["ERROR no slot 3 to write in (maximumSave 2)"])


func test_writing_takes_the_game_s_slot_else_the_first_empty_one() -> void:
	var save := _world.save
	save.write(1)
	save.new_game()
	assert_int(save.slot).is_equal(2)
	assert_bool(save.has(2)).is_false()
	save.write()
	assert_bool(save.has(2)).is_true()
	save.new_game(5)
	save.write()
	assert_bool(save.has(5)).is_true()


func test_a_new_game_resets_every_part_then_tells_the_game() -> void:
	var told: Array[int] = []
	_world.hooks.add(&"new_game", &"test", func(slot: int) -> void: told.append(slot))
	_play()
	_world.save.new_game(3)
	assert_bool(_world.story.has(&"bell_told")).is_false()
	assert_int(_world.bag.money).is_equal(0)
	assert_array(told).is_equal([3])
	assert_array(_events).is_equal(["new game 3"])


func test_a_part_no_one_added_is_kept_and_one_the_file_lacks_is_reset() -> void:
	_world.sandbox.write_json("saves/Saves/Pokemon_Party-1.json", {"format": 1, "parts": {"story": {"flags": ["met"]}, "pokedex": {"seen": [25]}}})
	_world.bag.add(&"potion")
	assert_bool(await _world.save.load_game(1)).is_true()
	assert_bool(_world.story.has(&"met")).is_true()
	assert_int(_world.bag.count(&"potion")).is_equal(0)
	_world.save.write()
	assert_that(_file(1)["parts"]["pokedex"]).is_equal({"seen": [25.0]})
	_world.save.new_game(2)
	_world.save.write()
	assert_bool(_file(2)["parts"].has("pokedex")).is_false()


func test_parts_are_restored_in_order_a_coroutine_awaited_before_the_game_is_told() -> void:
	var order: Array[String] = []
	_world.save.add_part(&"late", func() -> Dictionary: return {"x": 1}, func(_state: Dictionary) -> void:
		await restored_late
		order.append("late"), func() -> void: pass)
	_world.hooks.add(&"game_loaded", &"test", func(slot: int) -> void: order.append("loaded %d" % slot))
	_world.save.write(1)
	var done := [false]
	var loading := func() -> void: done[0] = await _world.save.load_game(1)
	loading.call()
	assert_bool(done[0]).is_false()
	assert_array(order).is_empty()
	restored_late.emit()
	assert_bool(done[0]).is_true()
	assert_array(order).is_equal(["late", "loaded 1"])
	assert_bool(_world.save.add_part(&"bag", Callable(), Callable(), Callable())).is_false()
	assert_array(_world.save.part_names()).is_equal([&"story", &"quests", &"bag", &"clock", &"late"])
	assert_array(_world.logged).is_equal(["ERROR a part 'bag' is already added"])


func test_a_check_may_refuse_a_load_before_anything_is_restored() -> void:
	_world.save.add_part(&"guard", func() -> Dictionary: return {"ok": false}, func(_state: Dictionary) -> void: pass, func() -> void: pass,
		func(state: Dictionary) -> bool: return state["ok"])
	_world.story.set_flag(&"saved")
	_world.save.write(1)
	_world.save.new_game(2)
	_world.story.set_flag(&"now")
	assert_bool(await _world.save.load_game(1)).is_false()
	assert_bool(_world.story.has(&"now")).is_true()
	assert_bool(_world.story.has(&"saved")).is_false()
	assert_int(_world.save.slot).is_equal(2)


func test_an_older_game_is_upgraded_and_a_newer_or_broken_one_refused() -> void:
	_world.hooks.add(&"save_upgrade", &"test", func(parts: Dictionary, version: String) -> Dictionary:
		if version == "0.9":
			parts["story"]["flags"] = ["bell_told"]
		return parts)
	_world.sandbox.write_json("saves/Saves/Pokemon_Party-1.json", {"format": 1, "game_version": "0.9", "parts": {"story": {"flags": ["bell"]}}})
	assert_bool(await _world.save.load_game(1)).is_true()
	assert_bool(_world.story.has(&"bell_told")).is_true()
	_world.sandbox.write_json("saves/Saves/Pokemon_Party-2.json", {"format": 2, "parts": {"story": {"flags": ["later"]}}})
	_world.sandbox.write("saves/Saves/Pokemon_Party-3.json", "{ not json")
	assert_bool(await _world.save.load_game(2)).is_false()
	assert_bool(await _world.save.load_game(3)).is_false()
	assert_bool(await _world.save.load_game(4)).is_false()
	assert_bool(_world.story.has(&"later")).is_false()
	assert_int(_world.save.slot).is_equal(1)
	assert_that(_world.save.summary(3)).is_equal({"damaged": true})
	assert_array(_world.logged).is_equal([
		"ERROR Pokemon_Party-2.json: written by a newer engine (format 2, this one reads 1)",
		"ERROR Pokemon_Party-3.json: not a saved game",
		"ERROR slot 4 holds no game",
	])


func test_a_summary_shows_the_play_time_and_what_the_game_adds() -> void:
	_world.hooks.add(&"save_summary", &"test", func(summary: Dictionary, slot: int) -> Dictionary:
		summary["name"] = "Ludo %d" % slot
		return summary)
	_world.clock.advance(60.0)
	_world.save.write(1)
	assert_that(_world.save.summary(1)).is_equal({"seconds": 60.0, "name": "Ludo 1"})
	assert_that(_world.save.summary(2)).is_equal({})


func test_what_json_cannot_hold_refuses_the_write_and_leaves_the_old_file() -> void:
	_world.save.write(1)
	var before := FileAccess.get_file_as_string(_world.save.path_of(1))
	var bad := [{"at": Vector2(1, 2)}]
	_world.save.add_part(&"bad", func() -> Dictionary: return bad[0], func(_state: Dictionary) -> void: pass, func() -> void: pass)
	assert_bool(_world.save.write(1)).is_false()
	bad[0] = {"cells": [{"x": Vector2i.ONE}]}
	assert_bool(_world.save.write(1)).is_false()
	bad[0] = {}
	_world.hooks.add(&"save_summary", &"test", func(summary: Dictionary, _slot: int) -> Dictionary:
		summary[3] = "three"
		return summary)
	assert_bool(_world.save.write(1)).is_false()
	assert_str(FileAccess.get_file_as_string(_world.save.path_of(1))).is_equal(before)
	assert_array(_world.logged).is_equal([
		"ERROR part 'bad' cannot be written: .at is a Vector2",
		"ERROR part 'bad' cannot be written: .cells[0].x is a Vector2i",
		"ERROR the summary cannot be written: it has a key that is not a text: 3",
	])


func test_a_file_that_cannot_be_replaced_stays_as_it_was() -> void:
	var path := _world.save.path_of(1)
	DirAccess.make_dir_recursive_absolute(path + ".tmp")
	assert_bool(_world.save.write(1)).is_false()
	DirAccess.remove_absolute(path + ".tmp")
	DirAccess.make_dir_recursive_absolute(path + "/inside")
	assert_bool(_world.save.write(1)).is_false()
	assert_bool(FileAccess.file_exists(path + ".tmp")).is_false()
	assert_int(_world.save.slot).is_equal(0)
	assert_int(_world.logged.size()).is_equal(2)


func test_erasing_empties_a_slot_and_the_game_played_keeps_its_own() -> void:
	_world.save.write(1)
	assert_bool(_world.save.erase(1)).is_true()
	assert_bool(_world.save.has(1)).is_false()
	assert_bool(_world.save.erase(1)).is_false()
	assert_int(_world.save.slot).is_equal(1)
	assert_array(_events).is_equal(["written 1", "erased 1"])


func test_studio_s_binary_settings_are_logged_and_a_bad_config_corrected() -> void:
	_config({"maximumSave": -1, "baseFilename": "Saves/", "saveKey": 1234, "saveHeader": "PKPRT", "isCanSaveOnAnySave": true, "klass": "Configs::Project::Save"})
	var settings := _world.save.config()
	assert_int(settings.maximum_save).is_equal(0)
	assert_str(settings.base_filename).is_equal("Saves/Pokemon_Party")
	assert_bool(settings.is_can_save_on_any_save).is_true()
	assert_array(_world.logged).is_equal([
		"WARN save_config.json: maximumSave cannot be negative, got -1; using 0",
		"WARN save_config.json: baseFilename needs a file name, got 'Saves/'; using Saves/Pokemon_Party",
		"WARN save_config.json: saveKey is for Studio's binary saves; games are written as JSON, not encrypted",
	])


func test_a_game_launched_for_testing_writes_apart_from_the_player_s() -> void:
	var testing := World.Save.new(World.Paths.new(true), Log.new(), _world.config, _world.hooks)
	assert_str(testing.path_of(2)).is_equal(_world.sandbox.root + "saves/test_Saves/Pokemon_Party-2.json")

