extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")

var _world: World


func before_test() -> void:
	_world = World.new(self)
	_world.screens.register(&"pokedex", "res://addons/wildgrass/pokedex/pokedex_screen.tscn")
	_world.screens.register(&"pokedex_entry", "res://addons/wildgrass/pokedex/pokedex_entry_screen.tscn")
	var names := ["Bulbasaur", "Ivysaur", "Venusaur", "Charmander", "Charmeleon", "Charizard", "Squirtle", "Wartortle", "Blastoise", "Caterpie", "Metapod", "Butterfree", "Weedle", "Kakuna", "Beedrill"]
	for index in names.size():
		var species := WgSpecies.new()
		species.id = StringName(names[index].to_lower())
		species.number = index + 1
		species.name = names[index]
		species.genus = "Genus %d" % (index + 1)
		species.description = "About %s." % names[index]
		var form := WgSpeciesForm.new()
		form.types.assign([&"grass", &"poison"] if index < 3 else [&"bug"])
		form.height = 0.7
		form.weight = 6.9
		form.pictures = {&"front": ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))}
		species.forms.append(form)
		_world.species.register(species)
	for id: StringName in [&"grass", &"poison"]:
		var type := WgType.new()
		type.id = id
		type.name = String(id).capitalize()
		_world.types.register(type)


func after_test() -> void:
	TranslationServer.set_locale("en")
	_world.root.free()
	_world.cleanup()


func _args() -> Dictionary:
	return {"pokedex": _world.pokedex, "species": _world.species, "types": _world.types, "texts": _world.texts, "dialogue": _world.dialogue, "screens": _world.screens}


func _open() -> WgPokedexScreen:
	return _world.screens.open(&"pokedex", _args()) as WgPokedexScreen


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_world.screens.handle_input(event)


func _rows(screen: WgPokedexScreen) -> Array[String]:
	var shown: Array[String] = []
	for card: Node in screen.get_node("List/Rows").get_children():
		shown.append(("[%s]" if (card as Button).button_pressed else "%s") % (card as Button).text)
	return shown


func _entry() -> WgPokedexEntryScreen:
	return _world.screens.top() as WgPokedexEntryScreen


func _label(screen: Node, path: String) -> String:
	return (screen.get_node(path) as Label).text


func test_the_list_stops_at_the_last_species_seen_dashes_for_the_others() -> void:
	_world.pokedex.catch(&"bulbasaur")
	_world.pokedex.see(&"venusaur")
	var screen := _open()
	assert_array(_rows(screen)).is_equal(["[● 001  Bulbasaur]", "   002  -----", "○ 003  Venusaur"])
	assert_str(_label(screen, "Header")).is_equal("National Pokédex   Seen 2   Caught 1")
	assert_str(_label(screen, "Side/Name")).is_equal("Bulbasaur")
	assert_object((screen.get_node("Side/Picture") as TextureRect).texture).is_not_null()
	screen.hide_after_last_seen = false
	screen.refresh()
	assert_int(_rows(screen).size()).is_equal(15)


func test_nothing_seen_shows_every_row_in_dashes() -> void:
	var screen := _open()
	assert_int(_rows(screen).size()).is_equal(15)
	assert_str(_rows(screen)[0]).is_equal("[   001  -----]")
	assert_str(_label(screen, "Side/Name")).is_empty()
	assert_object((screen.get_node("Side/Picture") as TextureRect).texture).is_null()


func test_up_and_down_go_round_left_and_right_go_ten() -> void:
	_world.pokedex.see(&"beedrill")
	var screen := _open()
	_press("ui_up")
	assert_int(screen.cursor).is_equal(14)
	_press("ui_down")
	assert_int(screen.cursor).is_equal(0)
	_press("ui_right")
	assert_int(screen.cursor).is_equal(10)
	_press("ui_right")
	assert_int(screen.cursor).is_equal(14)
	_press("ui_left")
	assert_int(screen.cursor).is_equal(4)
	_press("ui_left")
	assert_int(screen.cursor).is_equal(0)
	_press("ui_cancel")
	assert_bool(screen.is_closed()).is_true()


func test_the_entry_of_a_species_seen_shows_what_is_known_once_caught() -> void:
	_world.pokedex.see(&"bulbasaur")
	_world.pokedex.catch(&"venusaur")
	var screen := _open()
	_press("ui_down")
	_press("ui_accept")
	assert_object(_world.screens.top()).is_same(screen)
	_press("ui_up")
	_press("ui_accept")
	var entry := _entry()
	assert_str(_label(entry, "Title")).is_equal("001  Bulbasaur")
	assert_array([_label(entry, "Details/Genus"), _label(entry, "Details/Types"), _label(entry, "Details/Size"), _label(entry, "Description")]).is_equal(["?????", "?????", "?????", ""])
	_press("ui_down")
	assert_str(_label(entry, "Title")).is_equal("003  Venusaur")
	assert_array([_label(entry, "Details/Genus"), _label(entry, "Details/Types"), _label(entry, "Details/Size"), _label(entry, "Description")]).is_equal(["Genus 3", "Grass / Poison", "Height 0.7 m   Weight 6.9 kg", "About Venusaur."])
	_press("ui_down")
	assert_str(_label(entry, "Title")).is_equal("003  Venusaur")
	_press("ui_cancel")
	await get_tree().process_frame
	assert_object(_world.screens.top()).is_same(screen)
	assert_int(screen.cursor).is_equal(2)


func test_the_entry_cries_as_it_shows() -> void:
	# Long enough to still be playing when checked.
	var stream := AudioStreamWAV.new()
	stream.mix_rate = 8000
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	var data := PackedByteArray()
	data.resize(4000)
	stream.data = data
	_world.species.find(&"bulbasaur").forms[0].pictures[&"cry"] = stream
	_world.pokedex.see(&"bulbasaur")
	_open()
	_press("ui_accept")
	var player := _entry().get_node("Cry") as AudioStreamPlayer
	assert_object(player.stream).is_same(stream)
	assert_bool(player.playing).is_true()


func test_the_switch_action_shows_the_next_pokedex() -> void:
	InputMap.add_action(&"test_switch")
	_world.sandbox.write_json("config/pokedex.json", {"dexes": ["kanto", "national"], "switch": "test_switch"})
	var kanto := WgDex.new()
	kanto.id = &"kanto"
	kanto.name = "Kanto"
	kanto.creatures.assign([{"species": &"caterpie", "form": 0}])
	_world.pokedex.register(kanto)
	var screen := _open()
	assert_array(_rows(screen)).is_equal(["[   001  -----]"])
	var event := InputEventAction.new()
	event.action = &"test_switch"
	event.pressed = true
	_world.screens.handle_input(event)
	assert_str(_world.pokedex.dex).is_equal("national")
	assert_int(_rows(screen).size()).is_equal(15)
	_world.pokedex.reset()
	_world.config.get_config(&"pokedex").load_data({"dexes": ["national"]}, "test")
	screen.refresh()
	_press("ui_down")
	_world.screens.handle_input(event)
	assert_int(screen.cursor).is_equal(1)
	InputMap.erase_action(&"test_switch")


func test_the_rows_say_their_words_in_the_language() -> void:
	var translation := Translation.new()
	translation.locale = "fr"
	translation.add_message("{dex}   Seen {seen}   Caught {caught}", "{dex}   Vus {seen}   Pris {caught}")
	translation.add_message("National Pokédex", "Pokédex national")
	TranslationServer.add_translation(translation)
	_world.texts.language = "fr"
	var screen := _open()
	assert_str(_label(screen, "Header")).is_equal("Pokédex national   Vus 0   Pris 0")
	TranslationServer.remove_translation(translation)


func test_opened_by_the_pause_menu_from_the_engine() -> void:
	var engine := get_tree().root.get_node("Wildgrass")
	assert_array(engine.menu.entries().slice(0, 2)).is_equal([&"pokedex", &"bag"])
	assert_str(engine.screens.scene_path(&"pokedex")).is_equal("res://addons/wildgrass/pokedex/pokedex_screen.tscn")
	assert_str(engine.screens.scene_path(&"pokedex_entry")).is_equal("res://addons/wildgrass/pokedex/pokedex_entry_screen.tscn")
	var screen := engine.screens.open(&"pokedex") as WgPokedexScreen
	assert_object(screen.pokedex).is_same(engine.pokedex)
	screen.close()
