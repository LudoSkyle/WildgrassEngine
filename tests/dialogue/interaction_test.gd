extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const MapBuilder := preload("res://tests/support/map_builder.gd")
const T := preload("res://tests/support/tile_builder.gd")
const WaitingInteractable := preload("res://tests/support/waiting_interactable.gd")

const ACTIONS := ["ui_accept", "ui_up", "ui_down", "ui_left", "ui_right"]

var _world: World
var _player: WgWalker


func before_test() -> void:
	_world = World.new(self)


func after_test() -> void:
	for action: String in ACTIONS:
		Input.action_release(action)
	_world.root.free()
	_world.cleanup()


## A map with `cells`, the player on (5, 5) facing up.
func _field(cells := {}) -> void:
	_world.map(cells, Vector2i(12, 12))
	_player = _world.walker(Vector2i(5, 5), WgPlayerInput.new())
	_player.facing = Vector2i.UP
	_world.maps.traveller = _player


func _place(node: WgInteractable, cell: Vector2i) -> WgInteractable:
	node.position = _world.tiles.center_of(cell)
	_world.maps.current.entities_node().add_child(node)
	return node


func _sign(cell: Vector2i, text: String) -> WgSign:
	var sign_node := WgSign.new()
	sign_node.text = text
	return _place(sign_node, cell) as WgSign


## Presses interact in this frame and lets the player act on it.
func _interact() -> void:
	Input.action_press("ui_accept")
	_player.advance(0.0)
	Input.action_release("ui_accept")
	if _world.dialogue.box != null:
		_world.dialogue.box.set_process(false)
		_world.dialogue.box.advance(10.0)


func _shown() -> String:
	return _world.dialogue.box.shown_text() if _world.dialogue.is_open() else ""


func _event(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_world.screens.handle_input(event)


func _next_frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func test_interact_reads_the_sign_faced_and_the_player_waits() -> void:
	_field()
	_sign(Vector2i(5, 4), "Route 1")
	_interact()
	assert_str(_shown()).is_equal("Route 1")
	assert_str((_world.dialogue.box.get_node("Frame") as Control).theme_type_variation).is_equal("MessageFrame_sign")
	assert_bool(_world.walkers.is_busy(_player)).is_true()
	Input.action_press("ui_left")
	_player.advance(1.0)
	assert_that(_player.cell).is_equal(Vector2i(5, 5))


func test_the_key_that_ends_a_message_does_not_read_it_again() -> void:
	_field()
	_sign(Vector2i(5, 4), "Route 1")
	var opened := [0]
	_world.dialogue.opened.connect(func() -> void: opened[0] += 1)
	_interact()
	Input.action_press("ui_accept")
	_event("ui_accept")
	_player.advance(0.0)
	# Godot may close the box before the player acts in that frame.
	_world.dialogue.close()
	_player.advance(0.0)
	await _next_frames()
	_player.advance(0.0)
	assert_bool(_world.dialogue.is_open()).is_false()
	assert_int(opened[0]).is_equal(1)


func test_a_sign_ends_when_the_player_walks_away() -> void:
	_field()
	_sign(Vector2i(5, 4), "Route 1")
	_interact()
	Input.action_press("ui_down")
	_event("ui_down")
	await _next_frames()
	assert_bool(_world.dialogue.is_open()).is_false()
	_player.advance(0.13)
	assert_that(_player.facing).is_equal(Vector2i.DOWN)
	assert_bool(_player.is_moving).is_true()


func test_sides_limit_where_it_is_read_from() -> void:
	_field()
	var sign_node := _sign(Vector2i(5, 4), "Route 1")
	sign_node.sides = 2
	_interact()
	assert_bool(_world.dialogue.is_open()).is_false()
	sign_node.sides = 1
	_interact()
	assert_bool(_world.dialogue.is_open()).is_true()


func test_an_interactable_covers_its_size_on_its_level() -> void:
	_field()
	var met: Array[WgWalker] = []
	var wide := _place(WgInteractable.new(), Vector2i(4, 4))
	wide.size = Vector2i(2, 1)
	wide.interacted.connect(func(walker: WgWalker) -> void: met.append(walker))
	wide.level = 1
	_interact()
	assert_array(met).is_empty()
	wide.level = 0
	_interact()
	assert_array(met).is_equal([_player])


func test_one_inside_a_walker_is_that_walker_on_its_level() -> void:
	_field()
	var npc := _world.walker(Vector2i(5, 4))
	var met: Array[WgWalker] = []
	var talk := WgInteractable.new()
	talk.interacted.connect(func(walker: WgWalker) -> void: met.append(walker))
	npc.add_child(talk)
	npc.level = 1
	_interact()
	assert_array(met).is_empty()
	npc.level = 0
	_interact()
	assert_array(met).is_equal([_player])


func test_a_counter_reaches_the_cell_beyond_and_a_wall_does_not() -> void:
	_field({Vector2i(5, 4): T.COUNTER})
	_sign(Vector2i(5, 3), "Welcome!")
	_interact()
	assert_str(_shown()).is_equal("Welcome!")
	_world.dialogue.close()
	(_world.maps.current.get_child(1) as TileMapLayer).set_cell(Vector2i(5, 4), 0, T.WALL)
	_interact()
	assert_bool(_world.dialogue.is_open()).is_false()


func test_a_tile_message_is_said_whatever_the_level() -> void:
	_field({Vector2i(5, 4): T.SHELF})
	_interact()
	assert_str(_shown()).is_equal("Full of books.")
	_world.dialogue.close()
	_player.level = 1
	_interact()
	assert_str(_shown()).is_equal("Full of books.")


func test_the_interact_hook_runs_last_with_what_was_handled() -> void:
	_field()
	var seen: Array[String] = []
	_world.hooks.add(&"interact", &"surf", func(handled: bool, cell: Vector2i, walker: WgWalker) -> bool:
		seen.append("%s %s %s" % [handled, cell, walker == _player])
		return true)
	_interact()
	assert_array(seen).is_equal(["false (5, 4) true"])
	_sign(Vector2i(5, 4), "Route 1")
	_interact()
	assert_array(seen).is_equal(["false (5, 4) true"])
	_event("ui_accept")
	assert_array(seen).is_equal(["false (5, 4) true", "true (5, 4) true"])


func test_the_player_waits_until_the_interaction_ends_its_target_goes_or_the_map_changes() -> void:
	_field()
	var waiting := _place(WaitingInteractable.new(), Vector2i(5, 4))
	_interact()
	assert_bool(_world.walkers.is_busy(_player)).is_true()
	await get_tree().process_frame
	Input.action_press("ui_left")
	_player.advance(1.0)
	Input.action_release("ui_left")
	assert_that(_player.cell).is_equal(Vector2i(5, 5))
	waiting.release.emit()
	assert_bool(_world.walkers.is_busy(_player)).is_false()
	_interact()
	waiting.free()
	assert_bool(_world.walkers.is_busy(_player)).is_false()
	# Outside the map, so that the warp does not free it.
	var other := WaitingInteractable.new()
	other.position = _world.tiles.center_of(Vector2i(5, 4))
	_world.root.add_child(other)
	_interact()
	assert_bool(_world.walkers.is_busy(_player)).is_true()
	var build := MapBuilder.new(_world.sandbox)
	var town := build.map(&"town")
	MapBuilder.spawn(town, "Spawn", Vector2(8, 8))
	build.save("town", town)
	await _world.maps.go_to(&"town", &"Spawn")
	assert_bool(_world.walkers.is_busy(_player)).is_false()


func test_a_hold_keeps_its_owner_weakly_and_ends_when_it_goes() -> void:
	_field()
	var owner := RefCounted.new()
	var watched: WeakRef = weakref(owner)
	var number := _world.walkers.occupy(_player, owner)
	assert_bool(_world.walkers.is_busy(_player)).is_true()
	owner = null
	assert_object(watched.get_ref()).is_null()
	assert_bool(_world.walkers.is_busy(_player)).is_false()
	_world.walkers.release(_player, number)
	assert_bool(_world.walkers.is_busy(_player)).is_false()


func test_crossing_a_seam_keeps_the_player_waiting() -> void:
	var build := MapBuilder.new(_world.sandbox)
	var route := build.map(&"route")
	route.size = Vector2i(10, 8)
	MapBuilder.spawn(route, "Spawn", Vector2(40, 120))
	MapBuilder.link(route, WgMapLink.Side.SOUTH, &"island", 0)
	build.save("route", route)
	var island := build.map(&"island")
	island.size = Vector2i(10, 6)
	MapBuilder.link(island, WgMapLink.Side.NORTH, &"route", 0)
	build.save("island", island)
	_player = WgWalker.new()
	_player.walkers = _world.walkers
	_player.add_child(WgPlayerInput.new())
	_world.maps.traveller = _player
	await _world.maps.go_to(&"route", &"Spawn")
	_player.set_process(false)
	var guide := WaitingInteractable.new()
	guide.position = _world.tiles.center_of(Vector2i(2, 8))
	_world.root.add_child(guide)
	_player.facing = Vector2i.DOWN
	_interact()
	assert_bool(_world.walkers.is_busy(_player)).is_true()
	_player.global_position = _world.tiles.center_of(Vector2i(2, 8))
	assert_bool(_world.maps.cross()).is_true()
	assert_bool(_world.walkers.is_busy(_player)).is_true()
	guide.release.emit()
