extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const SteadyController := preload("res://tests/support/steady_controller.gd")

var _world: World
var _player: WgWalker


func before_test() -> void:
	_world = World.new(self)
	_world.map({}, Vector2i(12, 12))
	_player = _world.walker(Vector2i(5, 5), WgPlayerInput.new())
	_player.facing = Vector2i.UP
	_world.maps.traveller = _player


func after_test() -> void:
	Input.action_release("ui_accept")
	_world.root.free()
	_world.cleanup()


## A character on `cell` facing `facing`, saying `text`.
func _character(cell: Vector2i, facing: Vector2i, text := "Hi!", controller: WgWalkerController = null) -> WgWalker:
	var character := _world.walker(cell, controller)
	character.facing = facing
	var talk := WgTalk.new()
	talk.text = text
	character.add_child(talk)
	return character


func _talk() -> void:
	Input.action_press("ui_accept")
	_player.advance(0.0)
	Input.action_release("ui_accept")
	if _world.dialogue.box != null:
		_world.dialogue.box.set_process(false)
		_world.dialogue.box.advance(10.0)


func _shown() -> String:
	return _world.dialogue.box.shown_text() if _world.dialogue.is_open() else ""


func _close() -> void:
	var event := InputEventAction.new()
	event.action = "ui_accept"
	event.pressed = true
	_world.screens.handle_input(event)


func test_a_character_turns_toward_the_player_speaks_then_turns_back() -> void:
	var alix := _character(Vector2i(5, 4), Vector2i.LEFT)
	var talk := alix.get_child(-1) as WgTalk
	talk.speaker = "Alix"
	talk.speaker_color = Color.RED
	_talk()
	assert_str(_shown()).is_equal("Hi!")
	assert_that(alix.facing).is_equal(Vector2i.DOWN)
	var name_label := _world.dialogue.box.get_node("Speaker/Name") as Label
	assert_str(name_label.text).is_equal("Alix")
	assert_that(name_label.get_theme_color(&"font_color")).is_equal(Color.RED)
	_close()
	assert_that(alix.facing).is_equal(Vector2i.LEFT)


func test_a_character_that_does_not_turn_keeps_its_facing() -> void:
	var clerk := _character(Vector2i(5, 4), Vector2i.LEFT)
	(clerk.get_child(-1) as WgTalk).turns = false
	_talk()
	assert_str(_shown()).is_equal("Hi!")
	assert_that(clerk.facing).is_equal(Vector2i.LEFT)


func test_a_walking_character_is_talked_to_on_the_cell_it_walks_into_after_its_step() -> void:
	var runner := _character(Vector2i(6, 4), Vector2i.LEFT)
	runner.step(Vector2i.LEFT)
	runner.advance(0.1)
	_player.facing = Vector2i.UP
	_talk()
	assert_bool(_world.dialogue.is_open()).is_false()
	runner.advance(0.2)
	_world.dialogue.box.set_process(false)
	_world.dialogue.box.advance(10.0)
	assert_str(_shown()).is_equal("Hi!")
	assert_that(runner.cell).is_equal(Vector2i(5, 4))
	assert_that(runner.facing).is_equal(Vector2i.DOWN)


func test_the_cell_a_character_leaves_does_not_talk() -> void:
	var runner := _character(Vector2i(5, 4), Vector2i.RIGHT)
	runner.step(Vector2i.RIGHT)
	runner.advance(0.1)
	_talk()
	assert_bool(_world.walkers.is_busy(_player)).is_false()


func test_a_character_moved_or_turned_meanwhile_does_not_turn_back() -> void:
	var guard := _character(Vector2i(5, 4), Vector2i.LEFT)
	_talk()
	guard.turn(Vector2i.RIGHT)
	_close()
	assert_that(guard.facing).is_equal(Vector2i.RIGHT)


func test_its_controller_waits_while_it_talks() -> void:
	_world.sandbox.write_json("Data/configs/movement_config.json", {"stillDuringDialogue": false})
	var controller := SteadyController.new()
	controller.direction = Vector2i.UP
	var walker := _character(Vector2i(5, 4), Vector2i.LEFT, "Hi!", controller)
	_talk()
	walker.advance(1.0)
	assert_that(walker.cell).is_equal(Vector2i(5, 4))
	_close()
	walker.advance(0.25)
	assert_that(walker.cell).is_equal(Vector2i(5, 3))
