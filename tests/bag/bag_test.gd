extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")

signal used_up

var _world: World
var _changes: Array[String] = []


func before_test() -> void:
	_world = World.new(self)
	_changes = []
	_world.bag.changed.connect(func(id: StringName, count: int) -> void: _changes.append("%s %d" % [id, count]))
	_item(&"potion", &"medicine", 2)
	_item(&"super_potion", &"medicine", 1)
	_item(&"antidote", &"medicine", 1)
	_item(&"poke_ball", &"balls", 0)
	var bell := _item(&"bell", &"key_items", 0)
	bell.consumed = false


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _item(id: StringName, pocket: StringName, position: int) -> WgItem:
	var item := WgItem.new()
	item.id = id
	item.pocket = pocket
	item.position = position
	_world.items.register(item)
	return item


func test_items_are_added_and_removed_all_or_nothing() -> void:
	var bag := _world.bag
	assert_bool(bag.add(&"potion", 98)).is_true()
	assert_bool(bag.add(&"potion", 2)).is_false()
	assert_int(bag.count(&"potion")).is_equal(98)
	assert_bool(bag.add(&"potion")).is_true()
	assert_bool(bag.add(&"bell")).is_true()
	assert_bool(bag.add(&"bell")).is_false()
	assert_bool(bag.add(&"potion", 0)).is_false()
	assert_bool(bag.add(&"nope")).is_false()
	assert_bool(bag.remove(&"potion", 100)).is_false()
	assert_bool(bag.remove(&"potion", 99)).is_true()
	assert_bool(bag.has(&"potion")).is_false()
	assert_bool(bag.has(&"bell")).is_true()
	assert_array(_changes).is_equal(["potion 98", "potion 99", "bell 1", "potion 0"])


func test_no_limit_when_max_count_is_zero() -> void:
	_world.sandbox.write_json("Data/configs/bag_config.json", {"maxCount": 0})
	assert_bool(_world.bag.add(&"potion", 5000)).is_true()


func test_a_pocket_lists_its_items_in_the_order_received_or_by_position() -> void:
	var bag := _world.bag
	for id: StringName in [&"potion", &"poke_ball", &"antidote", &"super_potion"]:
		bag.add(id)
	assert_array(bag.items(&"medicine")).is_equal([&"potion", &"antidote", &"super_potion"])
	bag.sort(&"medicine")
	assert_array(bag.items(&"medicine")).is_equal([&"antidote", &"super_potion", &"potion"])
	assert_array(bag.items(&"balls")).is_equal([&"poke_ball"])


func test_ties_keep_the_order_received_in_a_long_pocket() -> void:
	var received: Array[StringName] = []
	for index in 20:
		var id := StringName("berry_%d" % ((index * 7) % 20))
		_item(id, &"berries", 0)
		_world.bag.add(id)
		received.append(id)
	_world.bag.sort(&"berries")
	assert_array(_world.bag.items(&"berries")).is_equal(received)


func test_money_stays_between_zero_and_its_maximum() -> void:
	var bag := _world.bag
	var shown: Array[int] = []
	bag.money_changed.connect(func(money: int) -> void: shown.append(money))
	bag.add_money(500)
	assert_bool(bag.spend(600)).is_false()
	assert_bool(bag.spend(200)).is_true()
	bag.add_money(5000000)
	assert_int(bag.money).is_equal(999999)
	bag.add_money(-2000000)
	assert_array(shown).is_equal([500, 300, 999999, 0])


func test_a_gift_is_announced_and_a_refused_one_logged() -> void:
	var gifts: Array[String] = []
	_world.bag.given.connect(func(id: StringName, count: int) -> void: gifts.append("%s %d" % [id, count]))
	assert_bool(_world.bag.give(&"bell")).is_true()
	assert_bool(_world.bag.give(&"bell")).is_false()
	assert_array(gifts).is_equal(["bell 1"])
	assert_array(_world.logged).is_equal(["WARN bell x1 does not fit in the bag"])


func test_items_count_for_quests_and_quest_earnings_come_through_the_bag() -> void:
	var quests := _world.quests
	var quest := WgQuest.new()
	quest.id = &"heal"
	var objective := WgQuestObjective.new()
	objective.kind = &"obtain_item"
	objective.target = "potion"
	objective.amount = 2
	quest.objectives = [objective]
	for earning: Array in [[&"money", [500.0]], [&"item", ["poke_ball", 10.0]]]:
		var written := WgQuestEarning.new()
		written.kind = earning[0]
		written.args = earning[1]
		quest.earnings.append(written)
	quests.register(quest)
	quests.start(&"heal")
	_world.bag.add(&"potion", 2)
	assert_bool(quests.is_finished(&"heal")).is_true()
	_world.bag.add(&"poke_ball", 95)
	assert_bool(quests.claim(&"heal")).is_false()
	assert_int(_world.bag.money).is_equal(0)
	_world.bag.remove(&"poke_ball", 10)
	var gifts: Array[String] = []
	_world.bag.given.connect(func(id: StringName, count: int) -> void: gifts.append("%s %d" % [id, count]))
	assert_bool(quests.claim(&"heal")).is_true()
	assert_int(_world.bag.money).is_equal(500)
	assert_int(_world.bag.count(&"poke_ball")).is_equal(95)
	assert_array(gifts).is_equal(["poke_ball 10"])


func test_conditions_read_the_bag() -> void:
	var story := _world.story
	_world.bag.add(&"potion", 2)
	_world.bag.add_money(300)
	assert_bool(story.check("has:potion, has:potion*2, !has:potion*3, !has:bell")).is_true()
	assert_bool(story.check("money:300, !money:301")).is_true()


func test_using_an_item_does_what_its_use_says_and_takes_a_consumed_one() -> void:
	var bag := _world.bag
	var potion := _world.items.item(&"potion")
	potion.usable = true
	bag.add(&"potion", 2)
	assert_bool(await bag.use(&"potion")).is_false()
	_world.items.add_use(&"potion", func(_id: StringName) -> bool: return true)
	assert_bool(await bag.use(&"potion")).is_true()
	assert_int(bag.count(&"potion")).is_equal(1)
	_world.items.add_use(&"potion", func(_id: StringName) -> bool: return false)
	assert_bool(await bag.use(&"potion")).is_false()
	assert_int(bag.count(&"potion")).is_equal(1)
	_world.items.add_use(&"potion", func(_id: StringName) -> void:
		await used_up)
	var done := [null]
	var using := func() -> void: done[0] = await bag.use(&"potion")
	using.call()
	assert_that(done[0]).is_null()
	used_up.emit()
	assert_bool(done[0]).is_true()
	assert_int(bag.count(&"potion")).is_equal(0)
	bag.add(&"bell")
	assert_bool(await bag.use(&"bell")).is_false()


func test_the_bag_goes_through_json_and_back() -> void:
	var bag := _world.bag
	bag.add(&"potion", 3)
	bag.add(&"bell")
	bag.add_money(1200)
	var saved: Variant = JSON.parse_string(JSON.stringify(bag.state()))
	bag.reset()
	assert_int(bag.count(&"potion")).is_equal(0)
	bag.restore(saved)
	assert_int(bag.count(&"potion")).is_equal(3)
	assert_array(bag.items(&"key_items")).is_equal([&"bell"])
	assert_int(bag.money).is_equal(1200)
