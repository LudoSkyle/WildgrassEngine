extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const MapBuilder := preload("res://tests/support/map_builder.gd")
const RecordingScreen := preload("res://tests/support/recording_screen.gd")

var _world: World


func before_test() -> void:
	_world = World.new(self)
	for sound: String in ["town", "house", "title", "wind"]:
		var stream := AudioStreamWAV.new()
		stream.mix_rate = 8000
		stream.format = AudioStreamWAV.FORMAT_8_BITS
		var data := PackedByteArray()
		data.resize(400)
		stream.data = data
		var path := _world.sandbox.root + "audio/%s/%s.wav" % ["ambience" if sound == "wind" else "music", sound]
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		stream.save_to_wav(path)
	var build := MapBuilder.new(_world.sandbox)
	for spec: Array in [["town", &"town", &"wind"], ["square", &"town", &""], ["house", &"house", &""], ["quiet", &"", &""]]:
		var map := build.map(&"", Vector2i(4, 4))
		map.music = spec[1]
		map.ambience = spec[2]
		MapBuilder.spawn(map, "Spawn", Vector2(8, 8))
		build.save(spec[0], map)
	var west := build.map(&"", Vector2i(4, 4))
	west.music = &"town"
	MapBuilder.spawn(west, "Spawn", Vector2(8, 8))
	MapBuilder.link(west, WgMapLink.Side.EAST, &"east")
	build.save("west", west)
	var east := build.map(&"", Vector2i(4, 4))
	east.music = &"house"
	MapBuilder.link(east, WgMapLink.Side.WEST, &"west")
	build.save("east", east)
	_world.maps.traveller = Node2D.new()


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func test_each_map_plays_its_music_and_ambience_and_two_maps_keep_the_same_one() -> void:
	var audio := _world.audio
	await _world.maps.go_to(&"town", &"Spawn")
	assert_str(audio.music.name).is_equal("town")
	assert_str(audio.ambience.name).is_equal("wind")
	audio.advance(0.5)
	var player := audio.music.current
	await _world.maps.go_to(&"square", &"Spawn")
	assert_object(audio.music.current).is_same(player)
	assert_float(audio.music.level).is_equal(0.5)
	assert_str(audio.ambience.name).is_empty()
	await _world.maps.go_to(&"house", &"Spawn")
	assert_str(audio.music.name).is_equal("house")
	assert_str(audio.music.leaving_name).is_equal("town")
	await _world.maps.go_to(&"quiet", &"Spawn")
	assert_str(audio.music.name).is_empty()


func test_the_title_plays_its_music_crossfaded_into_the_first_map_s() -> void:
	_world.screens.register(&"title", _world.sandbox.scene("title.tscn", RecordingScreen))
	_world.title.config().music = &"title"
	_world.title.show_title()
	assert_str(_world.audio.music.name).is_equal("title")
	await _world.maps.go_to(&"town", &"Spawn")
	assert_str(_world.audio.music.name).is_equal("town")
	assert_str(_world.audio.music.leaving_name).is_equal("title")


func test_crossing_into_a_linked_map_plays_its_music() -> void:
	await _world.maps.go_to(&"west", &"Spawn")
	assert_str(_world.audio.music.name).is_equal("town")
	_world.maps.traveller.global_position = Vector2(72, 8)
	assert_bool(_world.maps.cross()).is_true()
	assert_str(_world.audio.music.name).is_equal("house")
	while _world.maps.is_loading_neighbours:
		await _world.maps.neighbours_loaded
