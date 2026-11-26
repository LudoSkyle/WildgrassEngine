extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const Trainer := preload("res://addons/wildgrass/party/trainer.gd")

var _world: World


func before_test() -> void:
	_world = World.new(self)


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func test_a_new_trainer_is_a_boy_with_the_default_names_and_an_id_drawn() -> void:
	_world.trainer.random.seed = 7
	_world.trainer.reset()
	var expected := RandomNumberGenerator.new()
	expected.seed = 7
	assert_bool(_world.trainer.girl).is_false()
	assert_str(_world.trainer.name).is_equal("Alex")
	assert_str(_world.trainer.girl_name).is_equal("Sam")
	assert_int(_world.trainer.id).is_equal(expected.randi_range(0, 0x3FFFFFFE))
	assert_int(_world.trainer.id).is_less(0x3FFFFFFF)


func test_the_girl_has_her_own_name_and_id() -> void:
	_world.trainer.reset()
	_world.trainer.boy_id = 123456789
	_world.trainer.girl = true
	assert_str(_world.trainer.name).is_equal("Sam")
	assert_int(_world.trainer.id).is_equal(123456789 ^ 0x28F4AB4C)
	_world.trainer.name = "Lea"
	assert_str(_world.trainer.girl_name).is_equal("Lea")
	assert_str(_world.trainer.boy_name).is_equal("Alex")


func test_the_id_shown_keeps_five_digits() -> void:
	_world.trainer.boy_id = 123456789
	assert_int(_world.trainer.shown_id()).is_equal(56789)


func test_kept_by_the_save_through_json() -> void:
	_world.trainer.reset()
	_world.trainer.boy_id = 987654321
	_world.trainer.name = "Remi"
	_world.trainer.girl = true
	var saved: Dictionary = JSON.parse_string(JSON.stringify(_world.trainer.state()))
	_world.trainer.reset()
	_world.trainer.restore(saved)
	assert_bool(_world.trainer.girl).is_true()
	assert_int(_world.trainer.boy_id).is_equal(987654321)
	assert_str(_world.trainer.boy_name).is_equal("Remi")
	assert_str(_world.trainer.name).is_equal("Sam")


func test_player_in_a_text_says_the_name() -> void:
	_world.trainer.reset()
	assert_str(_world.texts.format("Hello {player}!")).is_equal("Hello Alex!")
