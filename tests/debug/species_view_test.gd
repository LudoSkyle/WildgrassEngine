extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")

var _world: World
var _sheet: Texture2D
var _french: Translation


func before_test() -> void:
	_world = World.new(self)
	_world.sandbox.write_json("config/language.json", {"choosable": ["en", "fr"]})
	_french = Translation.new()
	_french.locale = "fr"
	# Every text in French but Ivysaur's name.
	for pair: Array in [["Bulbasaur", "Bulbizarre"], ["A seed.", "Une graine."], ["A mon.", "Un mon."]]:
		_french.add_message(pair[0], pair[1])
	for number in range(3, 13):
		_french.add_message("Mon %d" % number, "Mon %d fr" % number)
	TranslationServer.add_translation(_french)
	_world.texts.language = "en"
	_sheet = _texture(128, 128)
	_species(&"bulbasaur", 1, "Bulbasaur", "A seed.", {&"icon": _texture(64, 32), &"front": _texture(96, 96), &"character": _sheet}, 0.7, 6.9)
	var drawn := _world.sandbox.root + "front.png"
	Image.create(4, 4, false, Image.FORMAT_RGBA8).save_png(drawn)
	_species(&"ivysaur", 2, "Ivysaur", "", {&"front": drawn, &"character": _world.sandbox.root + "nowhere.png"}, 1.0, 0.0)
	for number in range(3, 13):
		_species(StringName("mon%d" % number), number, "Mon %d" % number, "A mon.", {&"icon": _texture(32, 32), &"front": _texture(8, 8), &"character": _sheet}, 1.0, 1.0)


func after_test() -> void:
	TranslationServer.remove_translation(_french)
	_world.root.free()
	_world.cleanup()


static func _texture(width: int, height: int) -> Texture2D:
	return ImageTexture.create_from_image(Image.create(width, height, false, Image.FORMAT_RGBA8))


func _species(id: StringName, number: int, name: String, description: String, pictures: Dictionary, height: float, weight: float) -> void:
	var species := WgSpecies.new()
	species.id = id
	species.number = number
	species.name = name
	species.description = description
	species.genus = "Seed Pokémon"
	species.generation = 1
	var form := WgSpeciesForm.new()
	form.height = height
	form.weight = weight
	form.types = [&"grass"]
	for kind: StringName in pictures:
		form.pictures[kind] = pictures[kind]
	species.forms.append(form)
	_world.species.register(species)


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_world.screens.handle_input(event)


func _open() -> WgSpeciesViewScreen:
	return _world.screens.open(&"species_view", {"species": _world.species, "texts": _world.texts, "dialogue": _world.dialogue}) as WgSpeciesViewScreen


func test_what_is_missing_is_found_without_loading_a_picture() -> void:
	var screen := _open()
	assert_array(screen.entries[0]["missing"]).is_empty()
	assert_array(screen.entries[1]["missing"]).is_equal(["description (en)", "name (fr)", "description (fr)", "weight", "icon", "character"])
	var ivysaur := _world.species.find(&"ivysaur").forms[0]
	assert_bool(ivysaur.pictures[&"front"] is String).is_true()
	assert_int(screen.incomplete()).is_equal(1)
	assert_str((screen.get_node("List/Title") as Label).text).is_equal("Species: 12, 1 incomplete")


func test_the_list_stars_the_incomplete_and_follows_the_cursor_by_one_and_ten_round() -> void:
	var screen := _open()
	assert_str(screen.line_of(0)).is_equal("> 0001 Bulbasaur")
	assert_str(screen.line_of(1)).is_equal("  0002 Ivysaur *")
	_press("ui_down")
	assert_int(screen.selected).is_equal(1)
	assert_str((screen.get_node("List/Lines").get_child(1) as Label).text).is_equal("> 0002 Ivysaur *")
	_press("ui_right")
	assert_int(screen.selected).is_equal(11)
	assert_str((screen.get_node("List/Lines").get_child(11) as Label).text).is_equal("> 0012 Mon 12")
	_press("ui_down")
	assert_int(screen.selected).is_equal(0)
	_press("ui_up")
	assert_int(screen.selected).is_equal(11)
	_press("ui_left")
	assert_int(screen.selected).is_equal(1)
	_press("ui_cancel")
	assert_bool(screen.is_closed()).is_true()


func test_the_card_shows_the_data_every_language_and_what_is_missing_in_red() -> void:
	var screen := _open()
	var card := (screen.get_node("Card/Text") as RichTextLabel).text
	assert_str(card).contains("#0001  Seed Pokémon")
	assert_str(card).contains("Generation 1 · grass")
	assert_str(card).contains("0.7 m · 6.9 kg")
	assert_str(card).contains("[b]en[/b] Bulbasaur")
	assert_str(card).contains("[b]fr[/b] Bulbizarre")
	var icon := (screen.get_node("Card/Pictures/Icon") as TextureRect).texture
	assert_that((icon as AtlasTexture).region).is_equal(Rect2(0, 0, 32, 32))
	_press("ui_down")
	card = (screen.get_node("Card/Text") as RichTextLabel).text
	assert_str(card).contains("1.0 m · [color=#e04040]0.0 kg[/color]")
	assert_str(card).contains("[color=#e04040]0.0 kg[/color]")
	assert_str(card).contains("[color=#e04040]no description[/color]")
	assert_str(card).contains("[b]en[/b] Ivysaur")
	assert_str(card).contains("[b]fr[/b] [color=#e04040]no name[/color]")
	assert_str(card).contains("[color=#e04040]No picture: icon, character[/color]")


func test_the_sheet_turns_a_quarter_a_second_at_one_scale_from_down_again_on_a_new_species() -> void:
	var screen := _open()
	var view := screen.sheet_view
	assert_that(view.custom_minimum_size).is_equal(Vector2(64, 64))
	var seen: Array[String] = []
	for quarter in 4:
		seen.append("%s %s" % [view.facing(), view.frame().position.y])
		screen.advance(1.0)
	assert_array(seen).is_equal(["down 0.0", "left 32.0", "up 96.0", "right 64.0"])
	assert_str(view.facing()).is_equal("down")
	screen.advance(1.0)
	_press("ui_down")
	_press("ui_down")
	assert_str(view.facing()).is_equal("down")


func test_the_engine_tool_opens_the_view_and_keeps_the_tools_open() -> void:
	var done: Array[bool] = []
	var run := func() -> void: done.append(await _world.debug_tools.show_species())
	run.call()
	var screen := _world.screens.top() as WgSpeciesViewScreen
	assert_object(screen).is_not_null()
	_press("ui_cancel")
	await get_tree().process_frame
	assert_array(done).is_equal([true])
