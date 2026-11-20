extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")

var _world: World
var _gifts: Array[String] = []


func before_test() -> void:
	_world = World.new(self)
	_gifts = []
	_world.bag.given.connect(func(id: StringName, count: int) -> void: _gifts.append("%s %d" % [id, count]))
	for entry: Array in [[&"potion", &"medicine", true], [&"bell", &"key_items", false]]:
		var item := WgItem.new()
		item.id = entry[0]
		item.pocket = entry[1]
		item.consumed = entry[2]
		item.icon = ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
		_world.items.register(item)


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _box() -> WgMessageBox:
	var box := _world.dialogue.box
	box.set_process(false)
	return box


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_world.screens.handle_input(event)


func _reveal() -> WgItemReveal:
	var top := _world.screens.top()
	return top as WgItemReveal


func test_give_puts_items_in_the_bag_where_writing_reaches_it_in_the_game_s_voice() -> void:
	_world.dialogue.say("Here.[give=potion*3] Enjoy!", {"speaker": "Alix"})
	assert_bool((_box().get_node("Speaker") as Control).visible).is_false()
	assert_int(_world.bag.count(&"potion")).is_equal(0)
	_box().advance(10.0)
	assert_int(_world.bag.count(&"potion")).is_equal(3)
	assert_array(_gifts).is_equal(["potion 3"])
	assert_object(_reveal()).is_null()


func test_a_gift_that_does_not_fit_is_logged_and_the_message_goes_on() -> void:
	_world.bag.add(&"bell")
	_world.dialogue.say("Take it.[give=bell]")
	_box().advance(10.0)
	assert_str(_box().shown_text()).is_equal("Take it.")
	assert_array(_gifts).is_empty()
	assert_array(_world.logged).is_equal(["WARN bell x1 does not fit in the bag"])


func test_take_removes_items_or_nothing_when_there_are_fewer() -> void:
	_world.bag.add(&"potion", 2)
	_world.dialogue.say("[take=potion]One.[take=potion*5]")
	_box().advance(10.0)
	assert_int(_world.bag.count(&"potion")).is_equal(1)
	assert_array(_world.logged).is_equal(["WARN cannot take potion x5: there are 1"])


func test_an_item_of_a_reveal_pocket_shows_while_written_then_goes_on_by_itself() -> void:
	var done := [false]
	var talk := func() -> void:
		await _world.dialogue.say("[give=bell]You got the Bell!")
		done[0] = true
	talk.call()
	assert_object(_reveal()).is_not_null()
	assert_object((_reveal().get_node("Panel/Icon") as TextureRect).texture).is_same(_world.items.item(&"bell").icon)
	_press("ui_accept")
	assert_str(_box().shown_text()).is_equal("You got the Bell!")
	_press("ui_accept")
	_box().advance(0.9)
	assert_bool(done[0]).is_false()
	_box().advance(0.2)
	assert_bool(done[0]).is_true()
	assert_object(_reveal()).is_null()


func test_a_reveal_closes_with_its_dialogue() -> void:
	_world.dialogue.say("[give=bell]You got the Bell!")
	var shown := _reveal()
	_world.dialogue.close()
	assert_bool(shown.is_closed()).is_true()


func test_the_bag_s_tags_keep_no_service_alive() -> void:
	var other := World.new(self)
	var bag_ref: WeakRef = weakref(other.bag)
	other.root.free()
	other.cleanup()
	other = null
	assert_object(bag_ref.get_ref()).is_null()
