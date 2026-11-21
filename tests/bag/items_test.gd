extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")

var _world: World
var _missing: Array[String] = []


func before_test() -> void:
	_world = World.new(self)
	_missing = []
	_world.sandbox.set_setting("wildgrass/paths/graphics", _world.sandbox.root + "graphics/")
	_world.paths.asset_missing.connect(func(path: String, requester: String) -> void: _missing.append("%s %s" % [path.get_file(), requester]))
	_world.sandbox.write_json("Data/Studio/items/potion.json", {
		"id": 17, "dbSymbol": "potion", "icon": "017", "price": 200, "socket": 6, "position": 1,
		"isBattleUsable": true, "isMapUsable": true, "isLimited": true, "isHoldable": true,
		"isAllowingMega": false, "flingPower": 30, "klass": "ConstantHealItem", "loyaltyMalus": 0, "hpCount": 20, "isBerry": false,
	})
	_world.sandbox.write_json("Data/Studio/items/tm56.json", {
		"id": 383, "dbSymbol": "tm56", "icon": "383", "price": 0, "socket": 3, "position": 0,
		"isBattleUsable": false, "isMapUsable": true, "isLimited": false, "klass": "TechItem", "isHm": false, "move": "fling",
	})
	_world.sandbox.write_json("Data/Studio/items/letter.json", {"id": 9, "dbSymbol": "letter", "socket": 7, "klass": "Item"})
	_world.sandbox.write("Data/Text/Dialogs/100012.csv", "en,fr\n" + "Thing,Chose\n".repeat(17) + "Potion,Potion\n")
	DirAccess.make_dir_recursive_absolute(_world.sandbox.root + "graphics/icons")
	Image.create(4, 4, false, Image.FORMAT_RGBA8).save_png(_world.sandbox.root + "graphics/icons/017.png")


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func test_a_studio_item_is_read_as_it_is_the_first_time_it_is_asked_for() -> void:
	var potion := _world.items.item(&"potion")
	assert_str(potion.kind).is_equal("constant_heal")
	assert_str(potion.pocket).is_equal("medicine")
	assert_int(potion.position).is_equal(1)
	assert_int(potion.price).is_equal(200)
	assert_bool(potion.consumed).is_true()
	assert_bool(potion.usable).is_true()
	assert_that(potion.data["hp_count"]).is_equal(20.0)
	assert_bool(potion.data["is_holdable"]).is_true()
	assert_str(_world.texts.format(potion.name)).is_equal("Potion")
	assert_str(potion.description).is_equal("{text:100013:17}")
	assert_str(potion.plural).is_equal("{text:9001:17}")
	var tm := _world.items.item(&"tm56")
	assert_str(tm.kind).is_equal("tech")
	assert_str(tm.pocket).is_equal("tms")
	assert_bool(tm.consumed).is_false()
	assert_str(_world.items.item(&"letter").pocket).is_empty()
	assert_str(_world.items.item(&"letter").kind).is_empty()


func test_an_icon_loads_when_it_shows_and_a_missing_one_is_reported_once() -> void:
	var potion := _world.items.item(&"potion")
	assert_str(potion.icon_path.get_file()).is_equal("017.png")
	assert_int(potion.icon.get_width()).is_equal(4)
	assert_object(potion.icon).is_same(potion.icon)
	var tm := _world.items.item(&"tm56")
	assert_object(tm.icon).is_null()
	assert_object(tm.icon).is_null()
	assert_array(_missing).is_equal(["383.png item tm56"])


func test_a_game_item_wins_and_an_unknown_one_is_logged_once() -> void:
	var own := WgItem.new()
	own.id = &"potion"
	own.name = "Bottle"
	_world.items.register(own)
	assert_str(_world.items.item(&"potion").name).is_equal("Bottle")
	assert_object(_world.items.item(&"nope")).is_null()
	assert_object(_world.items.item(&"nope")).is_null()
	assert_bool(_world.items.has(&"tm56")).is_true()
	assert_bool(_world.items.has(&"nope")).is_false()
	_world.items.register(WgItem.new())
	_world.sandbox.write_json("Data/Studio/items/odd.json", {"dbSymbol": "other"})
	assert_object(_world.items.item(&"odd")).is_null()
	assert_array(_world.logged).is_equal([
		"ERROR unknown item 'nope'",
		"ERROR an item needs an id",
		"ERROR %sData/Studio/items/odd.json: not a Studio item" % _world.sandbox.root,
		"ERROR unknown item 'odd'",
	])


func test_a_use_is_found_by_the_item_s_id_else_its_kind() -> void:
	var by_kind := func(_id: StringName) -> bool: return true
	var by_id := func(_id: StringName) -> bool: return false
	_world.items.add_use(&"constant_heal", by_kind)
	assert_bool(_world.items.use_of(_world.items.item(&"potion")) == by_kind).is_true()
	_world.items.add_use(&"potion", by_id)
	assert_bool(_world.items.use_of(_world.items.item(&"potion")) == by_id).is_true()
	assert_bool(_world.items.use_of(_world.items.item(&"tm56")).is_valid()).is_false()


func test_pockets_and_limits_come_from_the_config() -> void:
	_world.sandbox.write_json("Data/configs/bag_config.json", {"pockets": [{"id": "stuff", "socket": 6}, {"name": "no id"}], "maxCount": -1})
	assert_str(_world.items.item(&"potion").pocket).is_equal("stuff")
	assert_int(_world.items.bag_config().max_count).is_equal(99)
	assert_int(_world.logged.size()).is_equal(2)


func test_the_default_pockets_show_studio_s_names_else_english_ones() -> void:
	var names: Array[String] = []
	for pocket: Dictionary in _world.items.bag_config().pockets:
		names.append(_world.texts.format(pocket["name"]))
	assert_array(names).is_equal(["Other Items", "Poké Balls", "Medicine", "TMs", "Key Items", "Berries"])
	assert_array(_world.logged).is_empty()
