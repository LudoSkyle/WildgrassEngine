extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")

signal used_up

var _world: World
var _potion_icon: Texture2D


func before_test() -> void:
	_world = World.new(self)
	_world.sandbox.write_json("Data/configs/bag_config.json", {"pockets": [
		{"id": "medicine", "name": "Medicine"},
		{"id": "key_items", "name": "Key Items"},
		{"id": "berries", "name": "Berries"},
	]})
	_potion_icon = ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	var potion := _item(&"potion", "Potion", &"medicine", "Heals 20 HP.")
	potion.plural = "Potions"
	potion.icon = _potion_icon
	potion.usable = true
	_item(&"antidote", "Antidote", &"medicine", "Cures poison.")
	_item(&"bell", "Bell", &"key_items", "It rings.").consumed = false


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _item(id: StringName, item_name: String, pocket: StringName, description: String) -> WgItem:
	var item := WgItem.new()
	item.id = id
	item.name = item_name
	item.pocket = pocket
	item.description = description
	_world.items.register(item)
	return item


func _open(pocket: StringName = &"medicine") -> WgBagScreen:
	return _world.screens.open(&"bag", {"pocket": pocket, "bag": _world.bag, "dialogue": _world.dialogue, "texts": _world.texts}) as WgBagScreen


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_world.screens.handle_input(event)


## Writes the message under way at once.
func _write() -> void:
	_world.dialogue.box.set_process(false)
	_world.dialogue.box.advance(10.0)


func _box_text() -> String:
	return _world.dialogue.box.shown_text()


func _choices() -> Array[String]:
	var shown: Array[String] = []
	for child: Node in _world.dialogue.box.get_node("Choices").get_children():
		if (child as Button).visible:
			shown.append((child as Button).text)
	return shown


func _rows(screen: WgBagScreen) -> Array:
	var rows := []
	for row: TreeItem in (screen.get_node("Box/List") as Tree).get_root().get_children():
		rows.append([row.get_text(0), row.get_text(1)])
	return rows


func _pocket_name(screen: WgBagScreen) -> String:
	return (screen.get_node("Box/Pocket/Name") as Label).text


func _description(screen: WgBagScreen) -> String:
	return (screen.get_node("Box/Details/Description") as Label).text


func _icon(screen: WgBagScreen) -> Texture2D:
	return (screen.get_node("Box/Details/Icon") as TextureRect).texture


func _selected_row(screen: WgBagScreen) -> String:
	return (screen.get_node("Box/List") as Tree).get_selected().get_text(0)


func test_it_shows_a_pocket_with_counts_and_turns_round_the_pockets_each_keeping_its_cursor() -> void:
	_world.bag.add(&"potion", 3)
	_world.bag.add(&"antidote")
	_world.bag.add(&"bell")
	var screen := _open()
	assert_str(_pocket_name(screen)).is_equal("Medicine")
	assert_array(_rows(screen)).is_equal([["Potion", "×3"], ["Antidote", "×1"]])
	assert_int((screen.get_node("Box/List") as Tree).get_column_width(1)).is_equal(40)
	assert_object(_icon(screen)).is_same(_potion_icon)
	assert_str(_description(screen)).is_equal("Heals 20 HP.")
	_press("ui_down")
	_press("ui_down")
	assert_str(screen.selected()).is_equal("antidote")
	assert_str(_selected_row(screen)).is_equal("Antidote")
	assert_str(_description(screen)).is_equal("Cures poison.")
	_press("ui_right")
	assert_str(_pocket_name(screen)).is_equal("Key Items")
	assert_array(_rows(screen)).is_equal([["Bell", ""]])
	_press("ui_right")
	assert_array(_rows(screen)).is_empty()
	assert_str(screen.selected()).is_empty()
	assert_object(_icon(screen)).is_null()
	assert_str(_description(screen)).is_empty()
	_press("ui_right")
	assert_str(screen.selected()).is_equal("antidote")
	_press("ui_left")
	assert_str(_pocket_name(screen)).is_equal("Berries")


func test_a_long_count_widens_its_column() -> void:
	_world.sandbox.write_json("Data/configs/bag_config.json", {"maxCount": 0, "pockets": [{"id": "medicine", "name": "Medicine"}]})
	_world.bag.add(&"potion", 5000)
	var tree := _open().get_node("Box/List") as Tree
	var shown := tree.get_theme_font(&"font").get_string_size("×5000", HORIZONTAL_ALIGNMENT_LEFT, -1, tree.get_theme_font_size(&"font_size")).x
	assert_int(tree.get_column_width(1)).is_greater(int(shown))


func test_it_follows_the_bag_while_open() -> void:
	_world.bag.add(&"potion")
	_world.bag.add(&"antidote")
	var screen := _open()
	_press("ui_down")
	_world.bag.remove(&"antidote")
	assert_array(_rows(screen)).is_equal([["Potion", "×1"]])
	assert_str(screen.selected()).is_equal("potion")
	_world.bag.add(&"potion", 4)
	assert_array(_rows(screen)).is_equal([["Potion", "×5"]])


func test_an_item_offers_use_with_a_use_toss_when_consumed_and_cancel() -> void:
	_world.items.add_use(&"potion", func(_id: StringName) -> bool: return true)
	_world.bag.add(&"potion", 3)
	_world.bag.add(&"bell")
	var screen := _open()
	_press("ui_accept")
	_write()
	assert_str(_box_text()).is_equal("Potion is selected.")
	assert_array(_choices()).is_equal(["Use", "Toss", "Cancel"])
	var details := screen.get_node("Box/Details") as Control
	assert_bool(details.visible).is_false()
	_press("ui_accept")
	assert_array(_rows(screen)).is_equal([["Potion", "×2"]])
	assert_bool(details.visible).is_true()
	await get_tree().process_frame
	screen.close()
	screen = _open(&"key_items")
	assert_str(screen.selected()).is_equal("bell")
	_press("ui_accept")
	_write()
	assert_array(_choices()).is_equal(["Cancel"])


func test_toss_asks_how_many_unless_there_is_one_then_yes_or_no() -> void:
	_world.bag.add(&"potion", 3)
	_open()
	_press("ui_accept")
	_write()
	assert_array(_choices()).is_equal(["Toss", "Cancel"])
	_press("ui_accept")
	_write()
	assert_str(_box_text()).is_equal("Toss how many Potions?")
	assert_str((_world.dialogue.box.get_node("Number/Value") as Label).text).is_equal("1")
	_press("ui_up")
	_press("ui_accept")
	_write()
	assert_str(_box_text()).is_equal("Throw away 2 Potions?")
	_press("ui_accept")
	assert_int(_world.bag.count(&"potion")).is_equal(1)
	await get_tree().process_frame
	_press("ui_accept")
	_write()
	_press("ui_accept")
	_write()
	assert_str(_box_text()).is_equal("Throw away 1 Potion?")
	_press("ui_down")
	_press("ui_accept")
	assert_int(_world.bag.count(&"potion")).is_equal(1)


func test_toss_cancelled_at_how_many_takes_nothing_and_asks_nothing_more() -> void:
	_world.bag.add(&"potion", 3)
	_open()
	_press("ui_accept")
	_write()
	_press("ui_accept")
	_write()
	_press("ui_cancel")
	await get_tree().process_frame
	assert_bool(_world.dialogue.is_open()).is_false()
	assert_int(_world.bag.count(&"potion")).is_equal(3)


func test_keys_wait_for_an_item_in_use_then_cancel_closes_and_lets_go_of_the_bag() -> void:
	var listeners := _world.bag.changed.get_connections().size()
	_world.items.add_use(&"potion", func(_id: StringName) -> void:
		await used_up)
	_world.bag.add(&"potion", 3)
	var screen := _open()
	_press("ui_accept")
	_write()
	_press("ui_accept")
	await get_tree().process_frame
	assert_object(_world.screens.top()).is_same(screen)
	_press("ui_accept")
	_press("ui_cancel")
	assert_bool(_world.dialogue.is_open()).is_false()
	assert_bool(screen.is_closed()).is_false()
	used_up.emit()
	assert_int(_world.bag.count(&"potion")).is_equal(2)
	_press("ui_cancel")
	assert_bool(screen.is_closed()).is_true()
	assert_int(_world.bag.changed.get_connections().size()).is_equal(listeners)


func test_opened_by_name_alone_it_uses_the_engine_s_services() -> void:
	var engine := get_tree().root.get_node("Wildgrass")
	assert_str(engine.screens.scene_path(&"bag")).is_equal("res://addons/wildgrass/bag/bag_screen.tscn")
	var screen := engine.screens.open(&"bag") as WgBagScreen
	assert_object(screen.bag).is_same(engine.bag)
	assert_object(screen.dialogue).is_same(engine.dialogue)
	assert_object(screen.texts).is_same(engine.texts)
	assert_str(screen.pocket).is_equal("medicine")
	screen.close()


func test_a_bag_with_no_pocket_is_logged_and_shows_nothing() -> void:
	_world.sandbox.write_json("Data/configs/bag_config.json", {"pockets": []})
	assert_bool(_open().is_closed()).is_true()
	assert_object(_world.screens.top()).is_null()
	assert_array(_world.logged).is_equal(["WARN the bag has no pocket to show"])
