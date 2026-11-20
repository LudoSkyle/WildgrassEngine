extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const MapBuilder := preload("res://tests/support/map_builder.gd")

var _world: World
var _changes: Array[String] = []


func before_test() -> void:
	_world = World.new(self)
	_changes = []
	_world.story.changed.connect(func(changed_name: StringName) -> void: _changes.append(str(changed_name)))


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func test_flags_are_set_and_cleared_each_change_announced_once() -> void:
	var story := _world.story
	story.set_flag(&"bell_told")
	story.set_flag(&"bell_told")
	assert_bool(story.has(&"bell_told")).is_true()
	story.clear_flag(&"bell_told")
	story.clear_flag(&"bell_told")
	assert_bool(story.has(&"bell_told")).is_false()
	assert_array(_changes).is_equal(["bell_told", "bell_told"])


func test_values_are_numbers_or_texts_apart_from_flags() -> void:
	var story := _world.story
	assert_int(story.value(&"badges")).is_equal(0)
	story.set_value(&"badges", 3)
	story.set_value(&"badges", 3)
	story.set_value(&"rival", &"Gary")
	story.set_value(&"badges", "3")
	assert_str(story.value(&"badges")).is_equal("3")
	assert_str(story.value(&"rival")).is_equal("Gary")
	story.set_value(&"rival", Vector2.ONE)
	story.set_flag(&"rival")
	assert_str(story.value(&"rival")).is_equal("Gary")
	story.set_value(&"rival", null)
	assert_bool(story.has_value(&"rival")).is_false()
	assert_bool(story.has(&"rival")).is_true()
	assert_array(_changes).is_equal(["badges", "rival", "badges", "rival", "rival"])
	assert_array(_world.logged).is_equal(["ERROR rival: a value is a number or a text, got Vector2"])


func test_a_local_flag_names_the_node_on_its_own_map_shown_as_a_neighbour_too() -> void:
	var build := MapBuilder.new(_world.sandbox)
	for map_id: String in ["route", "island"]:
		var map := build.map(StringName(map_id))
		map.size = Vector2i(10, 8)
		var ball := Node2D.new()
		ball.name = "Ball"
		map.entities_node().add_child(ball)
		MapBuilder.spawn(map, "Spawn", Vector2(8, 8))
		MapBuilder.link(map, WgMapLink.Side.SOUTH if map_id == "route" else WgMapLink.Side.NORTH, &"island" if map_id == "route" else &"route", 0)
		build.save(map_id, map)
	var traveller := Node2D.new()
	_world.maps.traveller = traveller
	await _world.maps.go_to(&"route", &"Spawn")
	var island: WgMap = _world.maps.neighbours[0]
	var here := _world.maps.current.get_node("Entities/Ball")
	var there := island.get_node("Entities/Ball")
	assert_str(_world.story.local(here, &"taken")).is_equal("route/Entities/Ball:taken")
	assert_str(_world.story.local(there, &"taken")).is_equal("island/Entities/Ball:taken")


func test_a_condition_holds_when_every_term_does() -> void:
	var story := _world.story
	story.set_flag(&"bell_told")
	story.set_value(&"badges", 3)
	story.set_value(&"rival", "Gary")
	assert_bool(story.check("")).is_true()
	assert_bool(story.check("bell_told")).is_true()
	assert_bool(story.check("!bell_told")).is_false()
	assert_bool(story.check("bell_told, !bell_hung")).is_true()
	assert_bool(story.check("bell_told, bell_hung")).is_false()
	for passing: String in ["badges >= 3", "badges>2", "badges = 3", "badges != 4", "badges < 3.5", "badges <= 3", "rival = Gary", "rival != Blue", "!badges > 3"]:
		assert_bool(story.check(passing)).override_failure_message(passing).is_true()
	for failing: String in ["badges > 3", "badges < 3", "rival = Blue", "rival > 1", "steps > 0"]:
		assert_bool(story.check(failing)).override_failure_message(failing).is_false()


func test_local_and_game_terms() -> void:
	var map := _world.map()
	var ball := Node2D.new()
	ball.name = "Ball"
	map.entities_node().add_child(ball)
	var story := _world.story
	story.set_flag(story.local(ball, &"taken"))
	assert_bool(story.check("local:taken", ball)).is_true()
	assert_bool(story.check("local:taken")).is_false()
	_world.hooks.add(&"story_term", &"bag", func(read: Variant, term: String, _node: Node) -> Variant:
		return term == "has:potion" if term.begins_with("has:") else read)
	assert_bool(story.check("has:potion")).is_true()
	assert_bool(story.check("has:ball")).is_false()
	assert_bool(story.check("odd term")).is_false()
	assert_bool(story.check("odd term")).is_false()
	assert_array(_world.logged).is_equal([
		"WARN local:taken: no node for a local flag",
		"WARN nobody reads the condition term 'odd term'",
	])


func test_the_state_goes_through_json_and_back() -> void:
	var story := _world.story
	story.set_flag(&"bell_told")
	story.set_value(&"badges", 3)
	story.set_value(&"rival", "Gary")
	var saved: Variant = JSON.parse_string(JSON.stringify(story.state()))
	var restored := [0]
	story.restored.connect(func() -> void: restored[0] += 1)
	story.reset()
	assert_bool(story.has(&"bell_told")).is_false()
	_changes.clear()
	story.restore(saved)
	assert_bool(story.has(&"bell_told")).is_true()
	assert_bool(story.check("badges = 3, rival = Gary")).is_true()
	assert_int(restored[0]).is_equal(2)
	assert_array(_changes).is_empty()


func test_a_value_shows_in_texts_unless_a_text_value_has_its_name() -> void:
	_world.story.set_value(&"badges", 3)
	assert_str(_world.texts.format("{badges} badges, {steps} steps")).is_equal("3 badges, {steps} steps")
	_world.texts.set_value(&"badges", "eight")
	assert_str(_world.texts.format("{badges}")).is_equal("eight")
