extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")

var _world: World


func before_test() -> void:
	_world = World.new(self)
	var potion := WgItem.new()
	potion.id = &"potion"
	potion.kind = &"constant_heal"
	_world.items.register(potion)
	var tm := WgItem.new()
	tm.id = &"tm56"
	tm.kind = &"tech"
	_world.items.register(tm)


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func test_an_unknown_item_is_logged_once_and_one_without_an_id_refused() -> void:
	assert_object(_world.items.item(&"nope")).is_null()
	assert_object(_world.items.item(&"nope")).is_null()
	_world.items.register(WgItem.new())
	assert_array(_world.logged).is_equal(["ERROR unknown item 'nope'", "ERROR an item needs an id"])


func test_a_use_is_found_by_the_item_s_id_else_its_kind() -> void:
	var by_kind := func(_id: StringName) -> bool: return true
	var by_id := func(_id: StringName) -> bool: return false
	_world.items.add_use(&"constant_heal", by_kind)
	assert_bool(_world.items.use_of(_world.items.item(&"potion")) == by_kind).is_true()
	_world.items.add_use(&"potion", by_id)
	assert_bool(_world.items.use_of(_world.items.item(&"potion")) == by_id).is_true()
	assert_bool(_world.items.use_of(_world.items.item(&"tm56")).is_valid()).is_false()


func test_pockets_and_limits_come_from_the_config() -> void:
	_world.sandbox.write_json("config/bag.json", {"pockets": [{"id": "stuff"}, {"name": "no id"}], "max_count": -1})
	assert_array(_world.items.bag_config().pockets).is_equal([{"id": "stuff"}])
	assert_int(_world.items.bag_config().max_count).is_equal(99)
	assert_int(_world.logged.size()).is_equal(2)


func test_the_engine_s_pockets_by_default() -> void:
	var names: Array[String] = []
	for pocket: Dictionary in _world.items.bag_config().pockets:
		names.append(_world.texts.label(pocket["name"]))
	assert_array(names).is_equal(["Items", "Medicine", "Poké Balls", "TMs", "Berries", "Key Items"])
	assert_array(_world.logged).is_empty()


func test_an_item_is_registered_else_a_resource_of_the_items_folder_else_a_source_s() -> void:
	var made := WgItem.new()
	made.name = "Repel"
	made.price = 350
	DirAccess.make_dir_recursive_absolute(_world.sandbox.root + "items")
	ResourceSaver.save(made, _world.sandbox.root + "items/repel.tres")
	ResourceSaver.save(WgDisplayConfig.new(), _world.sandbox.root + "items/odd.tres")
	var asked: Array[String] = []
	_world.items.add_source(func(id: StringName) -> WgItem:
		asked.append(str(id))
		if id != &"lure":
			return null
		var given := WgItem.new()
		given.name = "Lure"
		return given)
	assert_str(_world.items.item(&"repel").name).is_equal("Repel")
	assert_str(_world.items.item(&"repel").id).is_equal("repel")
	assert_str(_world.items.item(&"lure").name).is_equal("Lure")
	assert_bool(_world.items.has(&"lure")).is_true()
	assert_bool(_world.items.has(&"nothing")).is_false()
	assert_object(_world.items.item(&"odd")).is_null()
	assert_array(asked).is_equal(["lure", "nothing", "odd"])
	assert_array(_world.logged).is_equal(["ERROR odd.tres: not a WgItem", "ERROR unknown item 'odd'"])
