extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")

var _world: World
var _missing: Array[String] = []


func before_test() -> void:
	_world = World.new(self)
	_missing = []
	_world.paths.asset_missing.connect(func(path: String, _by: String) -> void: _missing.append(path.get_file()))
	for kind: String in ["music", "jingles", "effects", "ambience"]:
		for sound: String in ["a", "b", "c"]:
			_wav("audio/%s/%s.wav" % [kind, sound], 0.05)


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


## A silent WAV of `seconds` at 8 kHz.
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


func _levels() -> String:
	var music := _world.audio.music
	return "%s %.2f / %s %.2f" % [music.name, music.level, music.leaving_name, music.leaving_level]


func test_it_adds_the_buses_a_game_lacks_and_plays_on_them() -> void:
	_world.audio.setup()
	for bus: StringName in [&"Music", &"Effects", &"Cries"]:
		var index := AudioServer.get_bus_index(bus)
		assert_int(index).is_greater(0)
		assert_str(AudioServer.get_bus_send(index)).is_equal("Master")
	assert_str(_world.audio.music.current.bus).is_equal("Music")
	assert_str(_world.audio.jingle_player.bus).is_equal("Effects")
	assert_str(_world.audio.cry_player.bus).is_equal("Cries")


func test_music_crossfades_comes_back_where_it_was_and_a_third_cuts_the_leaving() -> void:
	var audio := _world.audio
	audio.play_music(&"a")
	assert_str(_levels()).is_equal("a 0.00 /  0.00")
	assert_bool(audio.music.current.playing).is_true()
	audio.advance(0.5)
	audio.play_music(&"a")
	assert_str(_levels()).is_equal("a 0.50 /  0.00")
	audio.play_music(&"b")
	audio.advance(0.25)
	assert_str(_levels()).is_equal("b 0.25 / a 0.25")
	audio.play_music(&"a")
	assert_str(_levels()).is_equal("a 0.25 / b 0.25")
	audio.play_music(&"c")
	assert_str(_levels()).is_equal("c 0.00 / a 0.25")
	assert_int([audio.music.current, audio.music.leaving].filter(func(p: AudioStreamPlayer) -> bool: return p.playing).size()).is_equal(2)
	audio.advance(1.0)
	assert_str(_levels()).is_equal("c 1.00 /  0.00")
	assert_bool(audio.music.leaving.playing).is_false()
	audio.stop_music()
	audio.advance(0.5)
	assert_str(_levels()).is_equal(" 0.00 / c 0.50")
	assert_bool((audio.music.leaving.stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED).is_true()


func test_ambience_crossfades_apart_from_the_music() -> void:
	_world.audio.play_music(&"a")
	_world.audio.play_ambience(&"b")
	_world.audio.advance(1.0)
	assert_str(_world.audio.ambience.name).is_equal("b")
	assert_float(_world.audio.ambience.level).is_equal(1.0)
	assert_str(_world.audio.music.name).is_equal("a")


func test_a_sound_is_its_file_s_name_a_path_inside_its_folder_or_a_full_path() -> void:
	var audio := _world.audio
	var root := _world.sandbox.root + "audio/"
	assert_str(audio.path_of(&"effects", &"a")).is_equal(root + "effects/a.wav")
	assert_str(audio.path_of(&"effects", &"sub/b.wav")).is_equal(root + "effects/sub/b.wav")
	assert_str(audio.path_of(&"effects", &"res://sounds/x.ogg")).is_equal("res://sounds/x.ogg")
	audio.config().folders["effects"] = "se"
	assert_str(audio.path_of(&"effects", &"a")).is_equal(root + "se/a.ogg")


func test_a_missing_sound_is_reported_once_and_midi_is_not_played() -> void:
	_wav("audio/music/old.mid", 0.01)
	_world.audio.effect(&"gone")
	_world.audio.effect(&"gone")
	_world.audio.play_music(&"old.mid")
	_world.audio.play_music(&"a")
	_world.audio.play_music(&"old.mid")
	assert_array(_missing).is_equal(["gone.ogg"])
	assert_array(_world.logged).is_equal(["WARN old.mid: Godot does not play MIDI"])


func test_a_jingle_pauses_the_music_which_goes_on_after_it_and_the_music_asked_meanwhile_starts() -> void:
	var audio := _world.audio
	var ended: Array[String] = []
	audio.jingle_finished.connect(func(sound: StringName) -> void: ended.append(String(sound)))
	audio.play_music(&"a")
	var playing := [true]
	var waiting := func() -> void:
		await audio.jingle(&"a")
		playing[0] = false
	waiting.call()
	assert_bool(audio.is_jingle_playing()).is_true()
	assert_bool(audio.music.current.stream_paused).is_true()
	audio.play_music(&"b")
	assert_str(audio.music_name()).is_equal("b")
	assert_str(audio.music.name).is_equal("a")
	for frame in 120:
		if not playing[0]:
			break
		await get_tree().process_frame
	assert_bool(playing[0]).is_false()
	assert_array(ended).is_equal(["a"])
	assert_bool(audio.music.leaving.stream_paused).is_false()
	assert_str(audio.music.name).is_equal("b")


func test_a_jingle_cuts_a_crossfade_short_the_music_leaving_stops() -> void:
	var audio := _world.audio
	audio.play_music(&"a")
	audio.play_music(&"b")
	audio.advance(0.3)
	audio.jingle(&"c")
	assert_bool(audio.music.leaving.playing).is_false()
	assert_str(_levels()).is_equal("b 0.30 /  0.00")
	assert_bool(audio.music.current.stream_paused).is_true()


func test_a_jingle_cut_by_another_says_so() -> void:
	var audio := _world.audio
	var ended: Array[String] = []
	audio.jingle_finished.connect(func(sound: StringName) -> void: ended.append(String(sound)))
	audio.jingle(&"a")
	audio.jingle(&"b")
	assert_array(ended).is_equal(["a"])
	assert_bool(audio.is_jingle_playing()).is_true()


func test_effects_take_a_free_voice_else_the_first() -> void:
	var audio := _world.audio
	for count in 4:
		audio.effect(&"a")
	assert_int(audio.voices.filter(func(v: AudioStreamPlayer) -> bool: return v.playing).size()).is_equal(4)
	audio.effect(&"b", 0.5, 1.5)
	assert_object(audio.voices[0].stream).is_not_same(audio.voices[1].stream)
	assert_float(audio.voices[0].pitch_scale).is_equal(1.5)
	assert_float(audio.voices[0].volume_db).is_equal_approx(linear_to_db(0.5), 0.01)


func test_a_cry_is_its_form_s_one_at_a_time_unless_forced() -> void:
	_wav("cries/pikachu.wav", 0.5)
	var pikachu := WgSpecies.new()
	pikachu.id = &"pikachu"
	pikachu.forms.append(WgSpeciesForm.new())
	pikachu.forms[0].pictures[&"cry"] = _world.sandbox.root + "cries/pikachu.wav"
	_world.species.register(pikachu)
	var mute := WgSpecies.new()
	mute.id = &"mute"
	mute.forms.append(WgSpeciesForm.new())
	_world.species.register(mute)
	assert_bool(_world.audio.cry(&"pikachu")).is_true()
	assert_bool(_world.audio.cry(&"pikachu")).is_false()
	assert_bool(_world.audio.cry(&"pikachu", 0, 1.0, true)).is_true()
	_world.audio.cry_player.stop()
	assert_bool(_world.audio.cry(&"mute")).is_false()


func test_a_named_sound_plays_as_its_kind_with_its_volume_and_pitch() -> void:
	var audio := _world.audio
	audio.config().load_data({"sounds": {"bump": {"kind": "effect", "name": "a", "volume": 50, "pitch": 120}, "theme": {"kind": "music", "name": "b"}}}, "test")
	audio.play(&"bump")
	assert_bool(audio.voices[0].playing).is_true()
	assert_float(audio.voices[0].pitch_scale).is_equal_approx(1.2, 0.001)
	audio.play(&"theme")
	assert_str(audio.music.name).is_equal("b")
	audio.play(&"confirm")
	audio.play(&"nothing")
	assert_int(audio.voices.filter(func(v: AudioStreamPlayer) -> bool: return v.playing).size()).is_equal(1)
	assert_array(_missing).is_empty()


func test_the_config_keeps_the_engine_s_roles_and_refuses_a_wrong_kind() -> void:
	var settings := WgAudioConfig.new()
	var problems := settings.load_data({"fade_seconds": -1, "sounds": {"odd": {"kind": "noise", "name": "x"}, "door": {"kind": "effect", "name": "door"}}}, "audio.json")
	assert_array(Array(problems)).is_equal(["audio.json: fade_seconds cannot be negative, got -1.0; using 0", "audio.json: sounds.odd: kind must be music, ambience, jingle or effect; left out"])
	assert_bool(settings.sounds.has("odd")).is_false()
	assert_str(settings.sounds["door"]["name"]).is_equal("door")
	assert_that(settings.sounds["save"]).is_equal({"kind": "jingle", "name": ""})


func test_three_volumes_each_their_bus_s_and_the_default_order() -> void:
	_world.audio.setup()
	var options := _world.options
	options.add_volume_options(_world.audio.config().buses)
	options.set_value(&"music_volume", 50)
	options.set_value(&"cries_volume", 0)
	assert_float(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music"))).is_equal_approx(linear_to_db(0.5), 0.01)
	assert_bool(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Cries"))).is_true()
	assert_float(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Effects"))).is_equal_approx(0.0, 0.01)
	assert_array(options.config().order).is_equal(["message_speed", "message_frame", "music_volume", "effects_volume", "cries_volume", "language"])
	options.set_value(&"music_volume", 100)
	options.set_value(&"cries_volume", 100)
