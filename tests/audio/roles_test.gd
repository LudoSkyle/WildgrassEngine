extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const RecordingScreen := preload("res://tests/support/recording_screen.gd")
const MapBuilder := preload("res://tests/support/map_builder.gd")
const T := preload("res://tests/support/tile_builder.gd")

var _world: World
var _paths := {}


func before_test() -> void:
	_world = World.new(self)
	var sounds := {}
	for role: String in ["cursor", "confirm", "cancel", "menu", "bump", "jump", "door", "bell"]:
		_paths[_wav("audio/effects/%s.wav" % role, 0.5)] = role
		sounds[role] = {"kind": "effect", "name": role}
	for role: String in ["save", "item", "key_item", "fanfare"]:
		_paths[_wav("audio/jingles/%s.wav" % role, 0.3)] = role
		sounds[role] = {"kind": "jingle", "name": role}
	sounds.erase("bell")
	sounds.erase("fanfare")
	_world.sandbox.write_json("config/audio.json", {"sounds": sounds})
	_world.audio.setup()


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _wav(relative: String, seconds: float) -> String:
	var stream := AudioStreamWAV.new()
	stream.mix_rate = 8000
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	var data := PackedByteArray()
	data.resize(int(8000 * seconds))
	stream.data = data
	var path := _world.sandbox.root + relative
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	stream.save_to_wav(path)
	return path


## The roles of the effects playing, and of the jingle.
func _played() -> Array[String]:
	var roles: Array[String] = []
	var players: Array[AudioStreamPlayer] = _world.audio.voices.duplicate()
	players.append(_world.audio.jingle_player)
	for player in players:
		if player.playing:
			for path: String in _paths:
				if _world.audio._streams.get(path) == player.stream:
					roles.append(_paths[path])
	return roles


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_world.screens.handle_input(event)


func _stop_all() -> void:
	for player in _world.audio.voices:
		player.stop()


func test_a_screen_s_keys_and_the_menu_opening_sound() -> void:
	_world.screens.register(&"probe", _world.sandbox.scene("probe.tscn", RecordingScreen))
	_world.screens.open(&"probe")
	for spec: Array in [["ui_accept", "confirm"], ["ui_cancel", "cancel"], ["ui_down", "cursor"], ["ui_left", "cursor"]]:
		_stop_all()
		_press(spec[0])
		assert_array(_played()).override_failure_message(spec[0]).is_equal([spec[1]])
	_world.screens.top().close()
	_stop_all()
	_world.menu.open()
	assert_array(_played()).is_equal(["menu"])


func test_a_door_and_a_save_sound() -> void:
	var build := MapBuilder.new(_world.sandbox)
	var town := build.map(&"", Vector2i(4, 4))
	MapBuilder.spawn(town, "Spawn", Vector2(8, 8))
	build.save("town", town)
	_world.maps.traveller = Node2D.new()
	var door := WgDoor.new()
	door.target_map = &"town"
	door.target_door = &"Spawn"
	door.transition = &"none"
	await _world.maps.use(door)
	assert_array(_played()).is_equal(["door"])
	door.free()
	assert_bool(_world.save.write(1)).is_true()
	assert_array(_played()).contains(["save"])


func test_an_item_given_plays_its_jingle_and_the_message_waits_for_it() -> void:
	for spec: Array in [[&"potion", &"items"], [&"bell", &"key_items"]]:
		var item := WgItem.new()
		item.id = spec[0]
		item.pocket = spec[1]
		_world.items.register(item)
	_world.dialogue.say("Here.[give=potion]")
	_world.dialogue.box.set_process(false)
	_world.dialogue.box.advance(10.0)
	assert_array(_played()).is_equal(["item"])
	_press("ui_accept")
	await get_tree().process_frame
	assert_bool(_world.dialogue.is_open()).is_true()
	await _world.audio.jingle_finished
	_press("ui_accept")
	await get_tree().process_frame
	assert_bool(_world.dialogue.is_open()).is_false()
	_world.audio.jingle_player.stop()
	_world.bag.give(&"bell")
	assert_array(_played()).contains(["key_item"])
	assert_array(_played()).not_contains(["item"])


func test_the_jingle_and_sound_tags_of_a_message() -> void:
	_world.dialogue.say("Ding![sound=bell] Fanfare![jingle=fanfare]")
	_world.dialogue.box.set_process(false)
	_world.dialogue.box.advance(10.0)
	assert_array(_played()).contains_exactly_in_any_order(["bell", "fanfare"])
	_press("ui_accept")
	await get_tree().process_frame
	assert_bool(_world.dialogue.is_open()).is_true()
	await _world.audio.jingle_finished
	_press("ui_accept")
	await get_tree().process_frame
	assert_bool(_world.dialogue.is_open()).is_false()


func test_bumping_sounds_again_at_its_pace_while_it_goes_on_and_a_jump_sounds() -> void:
	_world.map({Vector2i(5, 4): T.WALL, Vector2i(5, 6): T.LEDGE}, Vector2i(12, 12))
	var player := _world.walker(Vector2i(5, 5), WgPlayerInput.new())
	player.facing = Vector2i.UP
	_world.maps.traveller = player
	_world.maps.map_changed.emit(_world.maps.current)
	Input.action_press("ui_up")
	for frame in 10:
		player.advance(0.05)
		if not _played().is_empty():
			break
	assert_array(_played()).is_equal(["bump"])
	_stop_all()
	player.advance(0.05)
	_world.audio.advance(0.2)
	assert_array(_played()).is_empty()
	player.advance(0.05)
	_world.audio.advance(0.15)
	assert_array(_played()).is_equal(["bump"])
	Input.action_release("ui_up")
	_stop_all()
	player.advance(0.05)
	player.advance(0.05)
	_world.audio.advance(1.0)
	assert_array(_played()).is_empty()
	player.step(Vector2i.DOWN)
	assert_bool(player.is_jumping).is_true()
	assert_array(_played()).is_equal(["jump"])
