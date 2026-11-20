extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const MapBuilder := preload("res://tests/support/map_builder.gd")

var _world: World
var _player: WgWalker


func before_test() -> void:
	_world = World.new(self)


func after_test() -> void:
	Input.action_release("ui_accept")
	TranslationServer.clear()
	_world.root.free()
	_world.cleanup()


func _field() -> void:
	_world.map({}, Vector2i(12, 12))
	_player = _world.walker(Vector2i(5, 5), WgPlayerInput.new())
	_player.facing = Vector2i.UP
	_world.maps.traveller = _player


## A character facing the player, with a WgTalk saying `text`.
func _talker(text: String, states: Array[String] = [], ask := "") -> WgTalk:
	var character := _world.walker(Vector2i(5, 4))
	character.facing = Vector2i.DOWN
	var talk := WgTalk.new()
	talk.text = text
	talk.states = states
	talk.ask = ask
	character.add_child(talk)
	return talk


func _talk() -> void:
	Input.action_press("ui_accept")
	_player.advance(0.0)
	Input.action_release("ui_accept")
	if _world.dialogue.box != null:
		_world.dialogue.box.set_process(false)
		_world.dialogue.box.advance(10.0)


func _shown() -> String:
	return _world.dialogue.box.shown_text() if _world.dialogue.is_open() else ""


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_world.screens.handle_input(event)
	if _world.dialogue.is_open():
		_world.dialogue.box.set_process(false)
		_world.dialogue.box.advance(10.0)


func _close() -> void:
	_press("ui_accept")
	await get_tree().process_frame
	await get_tree().process_frame


func test_the_last_state_that_holds_is_said_chosen_each_time() -> void:
	_field()
	_talker("Welcome.", ["bell_told => Ask Alix.", "badges >= 3 => What badges!", "bell_hung => Closed tonight."])
	_talk()
	assert_str(_shown()).is_equal("Welcome.")
	await _close()
	_world.story.set_flag(&"bell_told")
	_talk()
	assert_str(_shown()).is_equal("Ask Alix.")
	await _close()
	_world.story.set_value(&"badges", 3)
	_talk()
	assert_str(_shown()).is_equal("What badges!")
	await _close()
	_world.story.set_flag(&"bell_hung")
	_talk()
	assert_str(_shown()).is_equal("Closed tonight.")


func test_a_state_without_its_arrow_is_logged_and_skipped() -> void:
	_field()
	var talk := _talker("Welcome.", ["bell_told: Ask Alix."])
	assert_str(talk.current_text(_world.story)).is_equal("Welcome.")
	assert_array(_world.logged).is_equal(["WARN %s: a state is 'condition => text', got \"bell_told: Ask Alix.\"" % talk.name])


func test_a_sign_follows_the_story_and_a_local_flag_of_its_own() -> void:
	_field()
	var sign_node := WgSign.new()
	sign_node.text = "Route 1"
	sign_node.states = ["local:read => Route 1, still."]
	sign_node.position = _world.tiles.center_of(Vector2i(5, 4))
	_world.maps.current.entities_node().add_child(sign_node)
	assert_str(sign_node.current_text(_world.story)).is_equal("Route 1")
	_world.story.set_flag(_world.story.local(sign_node, &"read"))
	_talk()
	assert_str(_shown()).is_equal("Route 1, still.")


func test_a_question_comes_before_its_text_and_no_says_nothing() -> void:
	_field()
	_talker("Healed!", [], "Heal your Pokémon?")
	_talk()
	assert_str(_shown()).is_equal("Heal your Pokémon?")
	_press("ui_accept")
	assert_str(_shown()).is_equal("Healed!")
	await _close()
	_talk()
	_press("ui_cancel")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(_world.dialogue.is_open()).is_false()


func test_a_question_for_one_state_is_asked_only_in_it() -> void:
	_field()
	_talker("A machine.", ["bell_tarnished => It sings."], "bell_tarnished => Put the bell in?")
	_talk()
	assert_str(_shown()).is_equal("A machine.")
	await _close()
	_world.story.set_flag(&"bell_tarnished")
	_talk()
	assert_str(_shown()).is_equal("Put the bell in?")


func test_tags_set_and_clear_flags_where_writing_reaches_them() -> void:
	_field()
	_world.story.set_flag(&"old")
	_world.dialogue.say("Hi[flag=bell_told] there[unflag=old].")
	_world.dialogue.box.set_process(false)
	_world.dialogue.box.advance(0.05)
	assert_bool(_world.story.has(&"bell_told")).is_true()
	assert_bool(_world.story.has(&"old")).is_true()
	_world.dialogue.box.advance(10.0)
	assert_bool(_world.story.has(&"old")).is_false()


func test_reload_comes_once_the_dialogue_is_closed_unless_a_warp_closed_it() -> void:
	var build := MapBuilder.new(_world.sandbox)
	for map_id: String in ["town", "house"]:
		var map := build.map(StringName(map_id))
		MapBuilder.spawn(map, "Spawn", Vector2(8, 8))
		build.save(map_id, map)
	_world.maps.traveller = Node2D.new()
	await _world.maps.go_to(&"town", &"Spawn")
	var shown := _world.maps.current
	var changes := [0]
	_world.maps.map_changed.connect(func(_map: WgMap) -> void: changes[0] += 1)
	_world.dialogue.say("[reload]The bell is hung.")
	_world.dialogue.box.set_process(false)
	_world.dialogue.box.advance(10.0)
	assert_int(changes[0]).is_equal(0)
	_press("ui_accept")
	for frame in 30:
		await get_tree().process_frame
		if changes[0] > 0 and not _world.maps.is_changing:
			break
	assert_int(changes[0]).is_equal(1)
	assert_object(_world.maps.current).is_not_same(shown)
	# A warp on the same map keeps it, and closes the box all the same.
	_world.dialogue.say("[reload]Off you go.")
	_world.dialogue.box.set_process(false)
	_world.dialogue.box.advance(10.0)
	await _world.maps.go_to(&"town", &"Spawn")
	for frame in 30:
		await get_tree().process_frame
	assert_int(changes[0]).is_equal(2)
	assert_bool(_world.dialogue.is_open()).is_false()


func test_a_guarded_passage_says_its_guard_s_current_text() -> void:
	_field()
	var guard := _world.walker(Vector2i(4, 3))
	var talk := WgTalk.new()
	talk.text = "Closed."
	talk.states = ["bell_hung => Still closed, sorry."]
	guard.add_child(talk)
	var block := WgRoadblock.new()
	block.position = _world.tiles.center_of(Vector2i(5, 3))
	_world.maps.current.entities_node().add_child(block)
	block.guard = block.get_path_to(guard)
	_world.story.set_flag(&"bell_hung")
	_player.step(Vector2i.UP)
	_player.advance(0.3)
	_player.step(Vector2i.UP)
	_player.advance(0.3)
	for frame in 60:
		guard.advance(0.05)
		_player.advance(0.05)
		await get_tree().process_frame
		if _world.dialogue.is_open():
			break
	_world.dialogue.box.set_process(false)
	_world.dialogue.box.advance(10.0)
	assert_str(_shown()).is_equal("Still closed, sorry.")


func test_a_translation_that_loses_a_game_tag_is_logged() -> void:
	var french := Translation.new()
	french.locale = TranslationServer.get_locale()
	french.add_message("Take it.[flag=got_it]", "Prends-le.")
	french.add_message("Bye.[flag=left]", "Salut.[flag=left]")
	french.add_message("Twice.[flag=a][flag=a]", "Deux fois.[flag=a]")
	TranslationServer.add_translation(french)
	_field()
	_world.dialogue.say("Take it.[flag=got_it]")
	_world.dialogue.say("Bye.[flag=left]")
	_world.dialogue.say("Twice.[flag=a][flag=a]")
	_world.dialogue.box.set_process(false)
	_world.dialogue.box.advance(10.0)
	_press("ui_accept")
	assert_str(_shown()).is_equal("Salut.")
	_press("ui_accept")
	assert_array(_world.logged).is_equal([
		"ERROR the translation of \"Take it.[flag=got_it]\" loses [flag=got_it]",
		"ERROR the translation of \"Twice.[flag=a][flag=a]\" loses [flag=a]",
	])


func test_the_story_s_tags_keep_no_service_alive() -> void:
	var other := World.new(self)
	var story_ref: WeakRef = weakref(other.story)
	var dialogue_ref: WeakRef = weakref(other.dialogue)
	other.root.free()
	other.cleanup()
	other = null
	assert_object(story_ref.get_ref()).is_null()
	assert_object(dialogue_ref.get_ref()).is_null()
