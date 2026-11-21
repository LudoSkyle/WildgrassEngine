extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const MapBuilder := preload("res://tests/support/map_builder.gd")

var _world: World
var _player: WgWalker


func before_test() -> void:
	_world = World.new(self)
	var potion := WgItem.new()
	potion.id = &"potion"
	potion.name = "Potion"
	potion.plural = "Potions"
	potion.pocket = &"medicine"
	_world.items.register(potion)


func after_test() -> void:
	Input.action_release("ui_accept")
	TranslationServer.set_locale("en")
	_world.root.free()
	_world.cleanup()


func _field() -> void:
	_world.map({}, Vector2i(12, 12))
	_player = _world.walker(Vector2i(5, 5), WgPlayerInput.new())
	_player.facing = Vector2i.UP
	_world.maps.traveller = _player


func _ball(cell: Vector2i, count := 1, hidden := false) -> WgItemBall:
	var ball := WgItemBall.new()
	ball.name = "Ball"
	ball.item = &"potion"
	ball.count = count
	ball.invisible = hidden
	ball.position = _world.tiles.center_of(cell)
	_world.maps.current.entities_node().add_child(ball)
	return ball


func _interact() -> void:
	Input.action_press("ui_accept")
	_player.advance(0.0)
	Input.action_release("ui_accept")
	if _world.dialogue.box != null:
		_world.dialogue.box.set_process(false)
		_world.dialogue.box.advance(10.0)


func _close() -> void:
	var event := InputEventAction.new()
	event.action = "ui_accept"
	event.pressed = true
	_world.screens.handle_input(event)
	await get_tree().process_frame
	await get_tree().process_frame


func test_a_visible_ball_blocks_its_cell_and_an_invisible_one_does_not() -> void:
	_field()
	var ball := _ball(Vector2i(5, 4))
	assert_bool(_player.can_step(Vector2i.UP)).is_false()
	ball.invisible = true
	assert_bool(ball.visible).is_false()
	assert_bool(_player.can_step(Vector2i.UP)).is_true()


func test_what_blocks_covers_its_cells_on_its_level_and_never_from_inside_a_walker() -> void:
	_field()
	var stand := WgInteractable.new()
	stand.blocks = true
	stand.size = Vector2i(2, 1)
	stand.position = _world.tiles.center_of(Vector2i(4, 4))
	_world.maps.current.entities_node().add_child(stand)
	assert_bool(_player.can_step(Vector2i.UP)).is_false()
	stand.level = 1
	assert_bool(_player.can_step(Vector2i.UP)).is_true()
	stand.free()
	var leader := _world.walker(Vector2i(5, 4))
	var held := WgInteractable.new()
	held.blocks = true
	leader.add_child(held)
	assert_bool(leader.step(Vector2i.UP)).is_true()
	assert_bool(_player.can_step(Vector2i.UP)).is_true()


func test_taken_it_goes_in_the_bag_says_its_name_and_is_gone() -> void:
	_field()
	var ball := _ball(Vector2i(5, 4), 3)
	var gifts: Array[String] = []
	_world.bag.given.connect(func(id: StringName, count: int) -> void: gifts.append("%s %d" % [id, count]))
	_interact()
	assert_int(_world.bag.count(&"potion")).is_equal(3)
	assert_array(gifts).is_equal(["potion 3"])
	assert_str(_world.dialogue.box.shown_text()).is_equal("Found Potions!")
	assert_bool(_world.story.has(_world.story.local(ball, &"taken"))).is_true()
	await _close()
	assert_bool(is_instance_valid(ball)).is_false()
	assert_bool(_world.walkers.is_busy(_player)).is_false()
	assert_bool(_player.can_step(Vector2i.UP)).is_true()


func test_one_says_its_singular_name_and_a_full_bag_leaves_it_there() -> void:
	_field()
	_world.bag.add(&"potion", 99)
	var ball := _ball(Vector2i(5, 4))
	_interact()
	assert_str(_world.dialogue.box.shown_text()).is_equal("No room for Potion.")
	await _close()
	assert_bool(is_instance_valid(ball)).is_true()
	assert_bool(_world.story.has(_world.story.local(ball, &"taken"))).is_false()


func test_a_ball_taken_is_gone_from_its_map_on_every_load() -> void:
	var build := MapBuilder.new(_world.sandbox)
	var town := build.map(&"town")
	MapBuilder.spawn(town, "Spawn", Vector2(8, 8))
	var ball := WgItemBall.new()
	ball.name = "Ball"
	ball.item = &"potion"
	town.entities_node().add_child(ball)
	build.save("town", town)
	_world.maps.traveller = Node2D.new()
	await _world.maps.go_to(&"town", &"Spawn")
	var shown := _world.maps.current.get_node("Entities/Ball")
	assert_int(shown.get_children(true).filter(func(child: Node) -> bool: return child is WgShowIf).size()).is_equal(1)
	_world.story.set_flag(_world.story.local(shown, &"taken"))
	await _world.maps.reload(&"none")
	assert_bool(_world.maps.current.entities_node().has_node("Ball")).is_false()


func test_a_child_of_a_ball_may_bear_any_name() -> void:
	var build := MapBuilder.new(_world.sandbox)
	var town := build.map(&"town")
	MapBuilder.spawn(town, "Spawn", Vector2(8, 8))
	var ball := WgItemBall.new()
	ball.name = "Ball"
	ball.item = &"potion"
	town.entities_node().add_child(ball)
	# As in the editor, where the ball's own gate is not made.
	ball.get_child(0, true).free()
	var authored := WgShowIf.new()
	authored.name = "Taken"
	ball.add_child(authored)
	build.save("town", town)
	_world.maps.traveller = Node2D.new()
	await _world.maps.go_to(&"town", &"Spawn")
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var shown := _world.maps.current.get_node("Entities/Ball")
	assert_int(shown.get_children(true).filter(func(child: Node) -> bool: return child is WgShowIf).size()).is_equal(2)
	_world.story.set_flag(_world.story.local(shown, &"taken"))
	await _world.maps.reload(&"none")
	assert_bool(_world.maps.current.entities_node().has_node("Ball")).is_false()
	assert_float(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)).is_equal(orphans)
