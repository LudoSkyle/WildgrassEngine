extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const T := preload("res://tests/support/tile_builder.gd")

var _world: World
var _map: WgMap
var _sheet: Texture2D


func before_test() -> void:
	_world = World.new(self)
	_map = _world.map({Vector2i(2, 2): T.GROUND, Vector2i(3, 2): T.WATER}, Vector2i(20, 20))
	_sheet = ImageTexture.create_from_image(Image.create(128, 128, false, Image.FORMAT_RGBA8))
	var wingull := WgSpecies.new()
	wingull.id = &"wingull"
	wingull.forms.append(WgSpeciesForm.new())
	wingull.forms[0].pictures[&"character"] = _sheet
	wingull.forms[0].pictures[&"cry"] = _wav("wingull.wav")
	_world.species.register(wingull)


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _wav(relative: String) -> String:
	var stream := AudioStreamWAV.new()
	stream.mix_rate = 8000
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	var data := PackedByteArray()
	data.resize(4000)
	stream.data = data
	var path := _world.sandbox.root + relative
	stream.save_to_wav(path)
	return path


## A wingull at the centre of `cell`, silent unless told otherwise.
func _flyer(cell: Vector2i, settings := {}) -> WgFlyer:
	var flyer := WgFlyer.new()
	flyer.wildgrass = _world
	flyer.species = &"wingull"
	flyer.cry_every = Vector2.ZERO
	flyer.seed = 7
	for key: String in settings:
		flyer.set(key, settings[key])
	flyer.position = _world.tiles.center_of(cell)
	_map.entities_node().add_child(flyer)
	flyer.set_process(false)
	return flyer


func test_its_picture_beats_its_wings_in_the_row_of_its_way_above_its_shadow() -> void:
	var flyer := _flyer(Vector2i(2, 2))
	assert_object(flyer.sprite.texture).is_same(_sheet)
	assert_that(flyer.sprite.position).is_equal(Vector2(0, -14))
	assert_that(flyer.shadow.position).is_equal(Vector2(0, 6))
	assert_int(flyer.shadow.get_index()).is_less(flyer.sprite.get_index())
	assert_int(flyer.shadow.polygon.size()).is_equal(8)
	var columns: Array[float] = []
	flyer.rest = Vector2(100, 100)
	flyer.advance(0.0)
	var start := int(flyer.sprite.region_rect.position.x) / 64
	for tick in 4:
		columns.append(flyer.sprite.region_rect.position.x)
		assert_float(flyer.sprite.region_rect.position.y).is_equal(0.0)
		assert_that(flyer.sprite.region_rect.size).is_equal(Vector2(32, 32))
		flyer.advance(0.2)
	var other := 64.0 - start * 64.0
	assert_array(columns).is_equal([start * 64.0, other, start * 64.0, other])
	for way: Array in [[Vector2i.LEFT, 32.0], [Vector2i.RIGHT, 64.0], [Vector2i.UP, 96.0], [Vector2i.DOWN, 0.0]]:
		flyer.heading = way[0]
		flyer.advance(0.0)
		assert_float(flyer.sprite.region_rect.position.y).is_equal(way[1])


func test_it_flies_straight_legs_within_its_zone_never_turning_back_and_hovers_between() -> void:
	var flyer := _flyer(Vector2i(4, 4), {"zone": Rect2i(2, 2, 5, 5), "pace": 4.0, "rest": Vector2(0.3, 0.6)})
	var legs := 0
	var last := Vector2i.ZERO
	var hover := 0.0
	for tick in 4000:
		var was_gliding := flyer.gliding
		var before := flyer.position
		flyer.advance(0.01)
		if not flyer.gliding:
			hover += 0.01
		if flyer.gliding and not was_gliding:
			legs += 1
			assert_bool(flyer.heading == -last).is_false()
			assert_int(flyer.stride).is_between(1, 3)
			# The first wait is shorter: each flyer starts at its own time.
			if legs > 1:
				assert_float(hover).is_between(0.29, 0.62)
			last = flyer.heading
			hover = 0.0
		var moved := flyer.position - before
		assert_float(absf(moved.x) * absf(moved.y)).is_equal(0.0)
		assert_bool(Rect2i(2, 2, 5, 5).has_point(_world.tiles.cell_of(flyer.position))).is_true()
		assert_float(moved.length()).is_less_equal(16.0 * 4.0 * 0.01 + 0.001)
	assert_int(legs).is_greater(40)


func test_cornered_in_a_corridor_it_turns_back_and_a_single_cell_keeps_it_hovering() -> void:
	var flyer := _flyer(Vector2i(2, 2), {"zone": Rect2i(2, 2, 3, 1), "pace": 8.0, "rest": Vector2(0.1, 0.1)})
	var ways: Array[Vector2i] = []
	for tick in 600:
		var was_gliding := flyer.gliding
		flyer.advance(0.01)
		if flyer.gliding and not was_gliding:
			ways.append(flyer.heading)
	assert_array(ways).contains([Vector2i.LEFT, Vector2i.RIGHT])
	assert_array(ways.filter(func(way: Vector2i) -> bool: return way.y != 0)).is_empty()
	var still := _flyer(Vector2i(5, 5), {"zone": Rect2i(5, 5, 1, 1)})
	for tick in 300:
		still.advance(0.01)
	assert_that(still.position).is_equal(Vector2(88, 88))
	assert_bool(still.gliding).is_false()


func test_carried_by_the_wind_it_crosses_its_zone_and_comes_back_from_the_other_side() -> void:
	var flyer := _flyer(Vector2i(2, 5), {"zone": Rect2i(2, 2, 6, 6), "drift": 1, "pace": 2.0})
	assert_that(flyer.heading).is_equal(Vector2i.RIGHT)
	var lowest := INF
	var highest := -INF
	var wrapped := false
	var slowest := INF
	var fastest := -INF
	for tick in 3000:
		var before := flyer.position.x
		flyer.advance(0.01)
		if flyer.position.x < before:
			wrapped = true
			# Out a cell and a half past the edge, back in a cell and a half before the other.
			assert_float(before).is_greater((8 + 1.5) * 16.0 - 1.0)
			assert_float(flyer.position.x).is_less((2 - 1.5) * 16.0 + 1.0)
		else:
			# Never stopping, at three quarters to five quarters of its pace.
			assert_float(flyer.position.x - before).is_between(2.0 * 16.0 * 0.01 * 0.74, 2.0 * 16.0 * 0.01 * 1.26)
			slowest = minf(slowest, flyer.position.x - before)
			fastest = maxf(fastest, flyer.position.x - before)
		lowest = minf(lowest, flyer.position.y)
		highest = maxf(highest, flyer.position.y)
		assert_float(absf(flyer.sprite.position.y + 14.0)).is_less_equal(2.0)
	assert_bool(wrapped).is_true()
	assert_float(slowest).is_less(2.0 * 16.0 * 0.01 * 0.85)
	assert_float(fastest).is_greater(2.0 * 16.0 * 0.01 * 1.15)
	assert_float(lowest).is_greater_equal(88.0 - 16.0)
	assert_float(highest).is_less_equal(88.0 + 16.0)
	assert_float(highest - lowest).is_greater(8.0)


func test_a_flock_of_one_seed_keeps_its_gap_each_bobbing_its_own_way() -> void:
	var settings := {"zone": Rect2i(0, 0, 30, 30), "drift": -1, "seed": 3}
	var first := _flyer(Vector2i(20, 5), settings)
	var second := _flyer(Vector2i(22, 6), settings)
	var bobs_apart := false
	for tick in 300:
		first.advance(0.02)
		second.advance(0.02)
		assert_float(second.position.x - first.position.x).is_equal_approx(32.0, 0.001)
		assert_float(second.position.y - first.position.y).is_equal_approx(16.0, 0.001)
		bobs_apart = bobs_apart or absf(first.sprite.position.y - second.sprite.position.y) > 0.5
	assert_bool(bobs_apart).is_true()


func test_it_cries_over_the_player_never_during_a_message_and_tries_again_soon() -> void:
	_world.audio.setup()
	var player := Node2D.new()
	_world.root.add_child(player)
	_world.maps.traveller = player
	player.position = Vector2(500, 500)
	var flyer := _flyer(Vector2i(2, 2), {"cry_every": Vector2(5, 5), "rest": Vector2(100, 100), "cry_volume": 0.5})
	flyer.advance(5.0)
	assert_bool(_world.audio.cry_player.playing).is_false()
	player.position = flyer.position + Vector2(60, 0)
	_world.dialogue.say("Hello")
	flyer.advance(1.0)
	assert_bool(_world.audio.cry_player.playing).is_false()
	_world.dialogue.close()
	await await_idle_frame()
	flyer.advance(0.5)
	assert_bool(_world.audio.cry_player.playing).is_false()
	flyer.advance(0.5)
	assert_bool(_world.audio.cry_player.playing).is_true()
	assert_float(_world.audio.cry_player.volume_db).is_equal_approx(linear_to_db(0.5), 0.01)
	_world.audio.cry_player.stop()
	flyer.advance(4.9)
	assert_bool(_world.audio.cry_player.playing).is_false()
	flyer.advance(0.1)
	assert_bool(_world.audio.cry_player.playing).is_true()


func test_its_shadow_turns_turquoise_over_water() -> void:
	var flyer := _flyer(Vector2i(2, 2), {"rest": Vector2(100, 100)})
	flyer.advance(0.0)
	assert_that(flyer.shadow.color).is_equal(Color(0, 0, 0, 0.26))
	flyer.position = _world.tiles.center_of(Vector2i(3, 2))
	flyer.advance(0.0)
	assert_that(flyer.shadow.color).is_equal(Color(0, 0.33, 0.4, 0.33))
	T.layer(_map, _map.get_child(1).tile_set, {Vector2i(3, 2): T.JETTY}, 0)
	flyer.advance(0.0)
	assert_that(flyer.shadow.color).is_equal(Color(0, 0, 0, 0.26))
