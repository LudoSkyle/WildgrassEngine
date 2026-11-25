extends GdUnitTestSuite

# Conditions of feature 21: seeing the player as RPG Maker's trainers do,
# conditions held together, a cell, another event's local switch. Read
# straight from a list running for the watching event.

const World := preload("res://tests/support/walking_world.gd")
const Events := preload("res://tests/events/events_test.gd")
const T := preload("res://tests/support/tile_builder.gd")
const Run := preload("res://addons/wildgrass/events/event_run.gd")

const K := WgEventIf.Kind

var _world: World
var _player: WgWalker
var _sheet: Texture2D


func before_test() -> void:
	_world = World.new(self)
	_world.map({Vector2i(2, 5): T.WALL}, Vector2i(12, 12))
	_player = _world.walker(Vector2i(5, 6), WgPlayerInput.new())
	_world.maps.traveller = _player
	_sheet = ImageTexture.create_from_image(Image.create(64, 64, false, Image.FORMAT_RGBA8))


func after_test() -> void:
	Input.action_release("ui_accept")
	_world.root.free()
	_world.cleanup()


func _watcher(cell: Vector2i, facing := Vector2i.DOWN, number := 1) -> WgEvent:
	var event := WgEvent.new()
	event.name = "Event%d" % number
	event.event_id = number
	event.walkers = _world.walkers
	event.position = _world.tiles.center_of(cell)
	var page := Events.page()
	page.sheet = _sheet
	page.direction = facing
	event.pages = [page]
	var sprite := WgCharacterSprite.new()
	sprite.name = "Sprite"
	event.add_child(sprite)
	_world.maps.current.entities_node().add_child(event)
	event.set_process(false)
	_world.events.refresh(event)
	return event


static func _if(kind: WgEventIf.Kind, fields := {}) -> WgEventIf:
	var made := WgEventIf.new()
	made.kind = kind
	made.number = 0
	for field: String in fields:
		made.set(field, fields[field])
	return made


func _holds(condition: WgEventIf, watcher: WgEvent) -> bool:
	var run := Run.new(_world.events)
	run.setup([] as Array[WgEventCommand], watcher)
	return condition.holds(run)


func _at(cell: Vector2i) -> void:
	_player.place_at(cell)


func test_a_watcher_sees_the_player_ahead_within_its_reach_nothing_between() -> void:
	var watcher := _watcher(Vector2i(5, 2))
	var seen := _if(K.PLAYER_SEEN, {"reach": 4})
	assert_bool(_holds(seen, watcher)).is_true()
	_at(Vector2i(5, 7))
	assert_bool(_holds(seen, watcher)).override_failure_message("beyond its reach").is_false()
	_at(Vector2i(6, 4))
	assert_bool(_holds(seen, watcher)).override_failure_message("aside").is_false()
	var blocker := _watcher(Vector2i(5, 4), Vector2i.DOWN, 2)
	_at(Vector2i(5, 6))
	assert_bool(_holds(seen, watcher)).override_failure_message("someone between").is_false()
	blocker.free()
	var behind_wall := _watcher(Vector2i(2, 2), Vector2i.DOWN, 3)
	_at(Vector2i(2, 6))
	assert_bool(_holds(seen, behind_wall)).override_failure_message("a wall between").is_false()


func test_a_watcher_through_sees_no_one_along_a_line() -> void:
	# A wall right behind the player: a watcher that is not through sees it.
	var watcher := _watcher(Vector2i(2, 2))
	_at(Vector2i(2, 4))
	assert_bool(_holds(_if(K.PLAYER_SEEN, {"reach": 4}), watcher)).is_true()
	watcher.through = true
	watcher.passes_walls = true
	assert_bool(_holds(_if(K.PLAYER_SEEN, {"reach": 4}), watcher)).is_false()


func test_a_watcher_s_reach_follows_its_facing() -> void:
	var watcher := _watcher(Vector2i(5, 2))
	var seen := _if(K.PLAYER_SEEN, {"reaches": [2, 9, 9, 9] as Array[int]})
	assert_bool(_holds(seen, watcher)).override_failure_message("down: 2 cells").is_false()
	watcher.turn(Vector2i.RIGHT)
	_at(Vector2i(9, 2))
	assert_bool(_holds(seen, watcher)).override_failure_message("right: 9 cells").is_true()


func test_a_band_sees_the_player_aside_and_starts_its_common_event() -> void:
	var watcher := _watcher(Vector2i(5, 2))
	_at(Vector2i(6, 4))
	assert_bool(_holds(_if(K.PLAYER_SEEN, {"reach": 4, "side": 1, "then_common": 7}), watcher)).is_true()
	assert_int(_world.events.get(&"_common_wanted")).is_equal(7)
	_at(Vector2i(8, 4))
	assert_bool(_holds(_if(K.PLAYER_SEEN, {"reach": 4, "side": 1}), watcher)).is_false()


func test_the_action_key_facing_the_watcher_is_seen_from_any_side() -> void:
	var watcher := _watcher(Vector2i(5, 2))
	_at(Vector2i(5, 1))
	_player.turn(Vector2i.DOWN)
	var seen := _if(K.PLAYER_SEEN, {"reach": 4})
	assert_bool(_holds(seen, watcher)).is_false()
	Input.action_press("ui_accept")
	assert_bool(_holds(seen, watcher)).is_true()


func test_the_player_in_a_line_a_rectangle_or_a_circle_whatever_stands_between() -> void:
	var watcher := _watcher(Vector2i(2, 2))
	_at(Vector2i(2, 6))
	assert_bool(_holds(_if(K.PLAYER_IN_LINE, {"reach": 4, "direction": Vector2i.DOWN}), watcher)).is_true()
	assert_bool(_holds(_if(K.PLAYER_IN_LINE, {"reach": 3, "direction": Vector2i.DOWN}), watcher)).is_false()
	assert_bool(_holds(_if(K.PLAYER_IN_LINE, {"reach": 4, "direction": Vector2i.UP}), watcher)).is_false()
	assert_bool(_holds(_if(K.PLAYER_IN_RECT, {"size": Vector2i(0, 4)}), watcher)).is_true()
	assert_bool(_holds(_if(K.PLAYER_IN_RECT, {"size": Vector2i(4, 3)}), watcher)).is_false()
	assert_bool(_holds(_if(K.PLAYER_IN_CIRCLE, {"value": 16}), watcher)).is_true()
	assert_bool(_holds(_if(K.PLAYER_IN_CIRCLE, {"value": 15}), watcher)).is_false()


func test_conditions_held_together_turned_over_and_a_part_not_read_making_all_false() -> void:
	var watcher := _watcher(Vector2i(2, 2))
	_world.story.set_flag(&"switch_1")
	var on := _if(K.SWITCH, {"number": 1})
	var off := _if(K.SWITCH, {"number": 2})
	assert_bool(_holds(_if(K.ALL, {"terms": [on, off] as Array[WgEventCommand]}), watcher)).is_false()
	assert_bool(_holds(_if(K.ANY, {"terms": [on, off] as Array[WgEventCommand]}), watcher)).is_true()
	assert_bool(_holds(_if(K.SWITCH, {"number": 2, "negate": true}), watcher)).is_true()
	var unread := _if(K.UNSUPPORTED, {"about": "script nope"})
	assert_bool(_holds(_if(K.ANY, {"terms": [on, unread] as Array[WgEventCommand]}), watcher)).is_false()
	assert_bool(_holds(_if(K.ALL, {"terms": [on, unread] as Array[WgEventCommand], "negate": true}), watcher)).is_false()
	assert_array(_world.logged.filter(func(line: String) -> bool: return line.contains("script nope"))).has_size(1)


func test_a_cell_and_another_event_s_local_switch() -> void:
	var watcher := _watcher(Vector2i(2, 2))
	assert_bool(_holds(_if(K.CELL, {"number": -1, "axis": 1, "value": 6}), watcher)).is_true()
	assert_bool(_holds(_if(K.CELL, {"number": -1, "axis": 0, "value": 6}), watcher)).is_false()
	assert_bool(_holds(_if(K.CELL, {"number": 0, "axis": 0, "comparison": WgEventIf.Comparison.LESS, "value": 3}), watcher)).is_true()
	_world.story.set_flag(&"town/event_4:B")
	assert_bool(_holds(_if(K.LOCAL_SWITCH, {"letter": "B", "event": 4, "map": &"town"}), watcher)).is_true()
	assert_bool(_holds(_if(K.LOCAL_SWITCH, {"letter": "B", "event": 4, "map": &"field"}), watcher)).is_false()
