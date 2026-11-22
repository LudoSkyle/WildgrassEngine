extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const MapBuilder := preload("res://tests/support/map_builder.gd")
const T := preload("res://tests/support/tile_builder.gd")

var _world: World
var _tools: Object
var _player: WgWalker


func before_test() -> void:
	_world = World.new(self)
	_world.screens.register(&"transition_fade", "res://addons/wildgrass/maps/transitions/fade.tscn")
	_tools = _world.debug_tools
	var build := MapBuilder.new(_world.sandbox)
	var town := build.map(&"", Vector2i(12, 12))
	MapBuilder.spawn(town, "Spawn", Vector2(40, 40))
	T.layer(town, T.tile_set(), {Vector2i(3, 2): T.WALL}, -1)
	MapBuilder.door(town, "ToCave", Vector2(72, 40), &"cave", &"Entrance", WgDoor.Kind.CONTACT, Vector2i.DOWN)
	build.save("town", town)
	var cave := build.map(&"", Vector2i(8, 8))
	MapBuilder.spawn(cave, "Entrance", Vector2(24, 24))
	build.save("cave", cave)
	FileAccess.open(_world.sandbox.root + "maps/notes.txt", FileAccess.WRITE).store_string("not a map")
	_player = WgWalker.new()
	_player.walkers = _world.walkers
	_world.maps.traveller = _player


func after_test() -> void:
	if _player.get_parent() == null:
		_player.free()
	_world.clock.speed = 1.0
	_world.daytime.forced_hour = -1.0
	_world.encounters.forced = -1
	_world.root.free()
	_world.cleanup()


func _item(id: StringName, pocket: StringName) -> void:
	var item := WgItem.new()
	item.id = id
	item.pocket = pocket
	_world.items.register(item)


## Waits for a warp or a reload to end, a few seconds at most.
func _changed() -> void:
	var done := [false]
	var mark := func(_map: WgMap) -> void: done[0] = true
	_world.maps.map_changed.connect(mark)
	for frame in 300:
		if done[0]:
			break
		await get_tree().process_frame
	_world.maps.map_changed.disconnect(mark)
	assert_bool(done[0]).override_failure_message("no warp or reload").is_true()


## Runs what the tools asked once closed; the message said, written out.
func _said() -> String:
	_world.debug._run_pending()
	if _world.dialogue.box == null:
		return ""
	var box := _world.dialogue.box
	box.set_process(false)
	box.advance(10.0)
	var text := box.shown_text()
	var event := InputEventAction.new()
	event.action = "ui_accept"
	event.pressed = true
	_world.screens.handle_input(event)
	return text


func _labels() -> Array[String]:
	var found: Array[String] = []
	for line in _world.debug.lines(&"engine"):
		found.append(_world.debug.label_of(line, _world.texts))
	return found


func test_the_engine_page_lists_mirage_s_tools_then_the_others() -> void:
	await _world.maps.go_to(&"town", &"Spawn")
	assert_array(_labels()).is_equal(["Fill the bag", "Hour: real", "Weather: Clear", "Fill the Pokédex", "Speed: x1",
		"Empty the bag", "Empty the Pokédex", "Warp", "Reload the map", "Through walls: off", "Encounters: chance", "Followers: on", "Save here"])
	var quest := WgQuest.new()
	quest.id = &"bell"
	_world.quests.register(quest)
	var mew := WgSpecies.new()
	mew.id = &"mew"
	mew.forms.append(WgSpeciesForm.new())
	_world.species.register(mew)
	assert_array(_labels().slice(0, 6)).is_equal(["Fill the bag", "Quests", "Hour: real", "Weather: Clear", "Species", "Fill the Pokédex"])


func test_fill_the_bag_gives_every_item_but_key_ones_more_each_time_up_to_the_limit() -> void:
	_world.sandbox.write_json("config/bag.json", {"max_count": 4})
	_item(&"potion", &"medicine")
	_item(&"bike", &"key_items")
	_item(&"antidote", &"medicine")
	_item(&"repel", &"items")
	assert_bool(_tools.fill_bag()).is_false()
	assert_array([_world.bag.count(&"potion"), _world.bag.count(&"bike"), _world.bag.count(&"antidote"), _world.bag.count(&"repel")]).is_equal([3, 0, 4, 4])
	assert_str(_said()).is_equal("Test items were added to the bag.")
	assert_bool(_tools.empty_bag()).is_false()
	assert_array([_world.bag.count(&"potion"), _world.bag.count(&"antidote")]).is_equal([0, 0])


func test_the_hour_cycles_the_config_s_then_the_real_one_and_stays_open() -> void:
	assert_str(_tools.hour_label()).is_equal("Hour: real")
	var seen: Array[String] = []
	for step in 5:
		assert_bool(_tools.next_hour()).is_true()
		seen.append("%s %s" % [_tools.hour_label(), _world.daytime.forced_hour])
	assert_array(seen).is_equal(["Hour: dawn 6.5", "Hour: day 12.0", "Hour: dusk 19.0", "Hour: night 23.0", "Hour: real -1.0"])
	_world.daytime.forced_hour = 12.0
	assert_str(_tools.hour_label()).is_equal("Hour: day")
	_world.daytime.forced_hour = 3.0
	assert_str(_tools.hour_label()).is_equal("Hour: real")


func test_the_weather_cycles_and_stays_open() -> void:
	var rain := WgWeather.new()
	rain.id = &"rain"
	rain.name = "Rain"
	_world.weather.register(rain)
	assert_bool(_tools.next_weather()).is_true()
	assert_str(_tools.weather_label()).is_equal("Weather: Rain")
	_tools.next_weather()
	assert_str(_tools.weather_label()).is_equal("Weather: Clear")
	await _world.maps.go_to(&"town", &"Spawn")
	_world.maps.current.weather = &"rain"
	assert_str(_tools.weather_label()).is_equal("Weather: Clear (this map: Rain)")


func test_fill_the_pokedex_catches_one_in_three_sees_the_next_and_empty_forgets_them() -> void:
	for spec: Array in [[&"bulbasaur", 1], [&"ivysaur", 2], [&"venusaur", 3], [&"charmander", 4]]:
		var species := WgSpecies.new()
		species.id = spec[0]
		species.number = spec[1]
		species.forms.append(WgSpeciesForm.new())
		_world.species.register(species)
	assert_bool(_tools.fill_pokedex()).is_false()
	var pokedex := _world.pokedex
	assert_array([pokedex.is_caught(&"bulbasaur"), pokedex.is_seen(&"ivysaur"), pokedex.is_caught(&"ivysaur"), pokedex.is_seen(&"venusaur"), pokedex.is_caught(&"charmander")]).is_equal([true, true, false, false, true])
	assert_str(_said()).is_equal("The Pokédex was filled.")
	_tools.empty_pokedex()
	assert_int(pokedex.seen_count()).is_equal(0)


func test_the_speed_cycles_the_config_s_speeds() -> void:
	var seen: Array[String] = []
	for step in 4:
		assert_bool(_tools.next_speed()).is_true()
		seen.append(_tools.speed_label())
	assert_array(seen).is_equal(["Speed: x2", "Speed: x4", "Speed: x8", "Speed: x1"])
	_world.clock.speed = 3.0
	_tools.next_speed()
	assert_float(_world.clock.speed).is_equal(1.0)


func test_a_quest_moves_on_finishes_and_starts_over_each_said_then_the_map_reloaded() -> void:
	await _world.maps.go_to(&"town", &"Spawn")
	var quest := WgQuest.new()
	quest.id = &"bell"
	quest.name = "Bell quest"
	for hidden: bool in [false, true, false]:
		var objective := WgQuestObjective.new()
		objective.kind = &"custom"
		objective.hidden = hidden
		quest.objectives.append(objective)
	_world.quests.register(quest)
	var lines: Array = _tools.quest_lines()
	assert_str(lines[0]["label"]).is_equal("Bell quest")
	var actions: Array = (lines[0]["lines"] as Callable).call()
	assert_array(actions.map(func(line: Dictionary) -> String: return line["label"])).is_equal(["Start over", "Next objective", "Finish"])
	assert_bool(await (actions[1]["action"] as Callable).call()).is_false()
	assert_bool(_world.quests.is_done(&"bell", 0)).is_true()
	assert_bool(_world.quests.is_done(&"bell", 1)).is_false()
	assert_str(_said()).is_equal("Bell quest: one objective more.")
	await _changed()
	(actions[1]["action"] as Callable).call()
	assert_bool(_world.quests.is_done(&"bell", 1)).is_true()
	_said()
	await _changed()
	(actions[2]["action"] as Callable).call()
	assert_bool(_world.quests.is_finished(&"bell")).is_true()
	assert_str(_said()).is_equal("Bell quest is finished.")
	await _changed()
	(actions[2]["action"] as Callable).call()
	assert_str(_said()).is_equal("Bell quest is already done.")
	(actions[0]["action"] as Callable).call()
	assert_bool(_world.quests.is_finished(&"bell")).is_false()
	assert_str(_said()).is_equal("Bell quest: started over.")
	await _changed()
	(actions[0]["action"] as Callable).call()
	assert_str(_said()).is_equal("Bell quest has not started.")


func test_warp_lists_the_maps_and_goes_to_the_first_spawn_point() -> void:
	await _world.maps.go_to(&"town", &"Spawn")
	var lines: Array = _tools.map_lines()
	assert_array(lines.map(func(line: Dictionary) -> String: return line["label"])).is_equal(["cave", "town"])
	assert_bool((lines[0]["action"] as Callable).call()).is_false()
	_world.debug._run_pending()
	await _changed()
	assert_that(_world.maps.current_id).is_equal(&"cave")
	assert_that(_player.cell).is_equal(Vector2i(1, 1))


func test_reload_and_save_here_show_on_a_map_only() -> void:
	var shown := func(id: StringName) -> bool: return _world.debug.lines(&"engine").any(func(line: Dictionary) -> bool: return line["id"] == id)
	assert_bool(shown.call(&"reload")).is_false()
	assert_bool(shown.call(&"save_here")).is_false()
	await _world.maps.go_to(&"town", &"Spawn")
	assert_bool(shown.call(&"reload")).is_true()
	assert_bool(shown.call(&"save_here")).is_true()
	_player.place_at(Vector2i(5, 5))
	assert_bool(_tools.reload_map()).is_false()
	_world.debug._run_pending()
	await _changed()
	assert_that(_player.cell).is_equal(Vector2i(5, 5))


func test_through_walls_the_traveller_alone_walks_anywhere() -> void:
	await _world.maps.go_to(&"town", &"Spawn")
	_player.set_process(false)
	_player.place_at(Vector2i(2, 2))
	var other := WgWalker.new()
	other.walkers = _world.walkers
	other.position = _world.tiles.center_of(Vector2i(3, 3))
	_world.maps.current.entities_node().add_child(other)
	other.set_process(false)
	assert_bool(_player.can_step(Vector2i.RIGHT)).is_false()
	assert_bool(_tools.toggle_walls()).is_true()
	assert_str(_tools.walls_label()).is_equal("Through walls: on")
	assert_bool(_player.can_step(Vector2i.RIGHT)).is_true()
	other.place_at(Vector2i(2, 3))
	assert_bool(_player.can_step(Vector2i.DOWN)).is_true()
	other.place_at(Vector2i(4, 2))
	assert_bool(other.can_step(Vector2i.LEFT)).is_false()
	_world.hooks.add(&"can_step", &"game_rule", func(_allowed: bool, _cell: Vector2i, _direction: Vector2i, _level: int, _walker: Node) -> bool: return false)
	assert_bool(_player.can_step(Vector2i.RIGHT)).is_true()
	_tools.toggle_walls()
	assert_str(_tools.walls_label()).is_equal("Through walls: off")
	assert_bool(_player.can_step(Vector2i.RIGHT)).is_false()


func test_through_walls_doors_still_work() -> void:
	await _world.maps.go_to(&"town", &"Spawn")
	_player.set_process(false)
	_player.place_at(Vector2i(2, 2))
	_tools.toggle_walls()
	_player.step(Vector2i.RIGHT)
	_player.advance(1.0)
	_player.step(Vector2i.RIGHT)
	_player.advance(1.0)
	for frame in 30:
		if _world.maps.current_id == &"cave":
			break
		await get_tree().process_frame
	assert_that(_world.maps.current_id).is_equal(&"cave")


func test_encounters_and_followers_cycle_in_place() -> void:
	var seen: Array[String] = []
	for step in 3:
		assert_bool(_tools.next_encounters()).is_true()
		seen.append("%s %d" % [_tools.encounters_label(), _world.encounters.forced])
	assert_array(seen).is_equal(["Encounters: always 1", "Encounters: never 0", "Encounters: chance -1"])
	assert_bool(_tools.toggle_followers()).is_true()
	assert_str(_tools.followers_label()).is_equal("Followers: off")
	assert_bool(_world.followers.enabled).is_false()
	_tools.toggle_followers()
	assert_str(_tools.followers_label()).is_equal("Followers: on")


func test_save_here_writes_even_where_saving_is_off_and_nothing_forced_is_saved() -> void:
	await _world.maps.go_to(&"town", &"Spawn")
	_world.story.set_flag(&"save_disabled")
	_tools.next_hour()
	_tools.next_weather()
	_tools.next_speed()
	_tools.toggle_walls()
	_tools.next_encounters()
	assert_bool(_tools.save_here()).is_false()
	assert_str(_said()).is_equal("The game was saved.")
	assert_bool(_world.save.has(1)).is_true()
	var text := FileAccess.get_file_as_string(_world.save.path_of(1))
	for word: String in ["forced", "speed", "walls", "weather"]:
		assert_bool(text.contains(word)).override_failure_message(word).is_false()
