extends GdUnitTestSuite

# The engine writes none of its words: each is a key the game gives in its
# translations (feature 5, docs/design/05b-text-keys.md).

const World := preload("res://tests/support/walking_world.gd")
const EngineWords := preload("res://tests/support/engine_words.gd")
const Texts := preload("res://addons/wildgrass/texts/texts.gd")

const ENGLISH := "res://tests/support/engine_words.en.po"
const LIST := "res://docs/design/05b-text-keys.md"

var _world: World


func before_test() -> void:
	_world = World.new(self)


func after_test() -> void:
	for screen in _world.screens.stack():
		screen.close()
	_world.dialogue.close()
	EngineWords.reset()
	TranslationServer.set_locale("en")
	_world.root.free()
	_world.cleanup()


## The keys written in the engine's scripts and scenes, sorted, once each;
## a key built from a written start and an id (`"wg.debug.moment." + id`)
## shows as that start.
static func _keys_in(folder: String) -> Array[String]:
	var found: Dictionary[String, bool] = {}
	var pattern := RegEx.create_from_string("\"(wg(?:\\.[a-z_]+)+\\.?)\"")
	for path in _files_in(folder):
		for hit in pattern.search_all(FileAccess.get_file_as_string(path)):
			found[hit.get_string(1)] = true
	var keys: Array[String] = []
	keys.assign(found.keys())
	keys.sort()
	return keys


static func _files_in(folder: String) -> Array[String]:
	var paths: Array[String] = []
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd") or file.ends_with(".tscn"):
			paths.append(folder.path_join(file))
	for sub in DirAccess.get_directories_at(folder):
		paths.append_array(_files_in(folder.path_join(sub)))
	return paths


## Every text a screen shows: labels, buttons, rich texts, tree cells.
static func _texts_of(node: Node) -> Array[String]:
	var shown: Array[String] = []
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return shown
	if node is Label:
		shown.append((node as Label).text)
	elif node is Button:
		shown.append((node as Button).text)
	elif node is RichTextLabel:
		shown.append((node as RichTextLabel).get_parsed_text())
	elif node is Tree:
		var item := (node as Tree).get_root()
		while item != null:
			for column in (node as Tree).columns:
				shown.append(item.get_text(column))
			item = item.get_next_in_tree()
	for child in node.get_children():
		shown.append_array(_texts_of(child))
	return shown


## The texts that are words written by the engine: not empty, not a key,
## not figures and signs alone, not the game's name.
static func _english(texts: Array[String]) -> Array[String]:
	var words := RegEx.create_from_string("[A-Za-z]{2,}")
	var found: Array[String] = []
	for text in texts:
		var stripped := text.strip_edges()
		# The game's own name, shown where it has no logo, is the game's.
		if stripped.is_empty() or Texts.is_key(stripped) or words.search(stripped) == null or stripped == ProjectSettings.get_setting("application/config/name"):
			continue
		found.append(stripped)
	return found


func test_a_key_with_no_text_stays_as_written_and_is_logged_once_a_game_s_label_is_not() -> void:
	TranslationServer.clear()
	assert_str(_world.texts.label("wg.menu.bag")).is_equal("wg.menu.bag")
	assert_str(_world.texts.label("wg.item.found", {"item": "Potion"})).is_equal("wg.item.found")
	_world.texts.label("wg.menu.bag")
	assert_str(_world.texts.label("Shall we go?")).is_equal("Shall we go?")
	assert_str(_world.texts.label("wg.not a key")).is_equal("wg.not a key")
	assert_array(_world.logged).is_equal([
		"WARN no text for wg.menu.bag: give it in the game's translations",
		"WARN no text for wg.item.found: give it in the game's translations",
	])


func _confirm(text: String, answer: Array) -> void:
	answer[0] = await _world.dialogue.confirm(text)


func test_a_message_and_its_choices_say_a_key_s_text() -> void:
	var answer := [null]
	_confirm("wg.save.question", answer)
	_world.dialogue.box.set_process(false)
	_world.dialogue.box.advance(10.0)
	assert_str(_world.dialogue.box.shown_text()).is_equal("Would you like to save the game?")
	var choices: Array[String] = []
	for button in _world.dialogue.box.get_node("Choices").get_children():
		if (button as Button).visible:
			choices.append((button as Button).text)
	assert_array(choices).is_equal(["Yes", "No"])
	_world.dialogue.close()


func test_every_key_the_engine_writes_has_its_english_and_its_line_in_the_list() -> void:
	var keys := _keys_in("res://addons/wildgrass")
	assert_array(keys).contains(["wg.yes", "wg.menu.bag", "wg.save.question"])
	var english := load(ENGLISH) as Translation
	var listed := FileAccess.get_file_as_string(LIST)
	var missing: Array[String] = []
	for key: String in keys.filter(func(written: String) -> bool: return not written.ends_with(".")):
		if String(english.get_message(key)).is_empty():
			missing.append("no English: " + key)
		if not listed.contains("`%s`" % key):
			missing.append("not in the list: " + key)
	for key: String in english.get_message_list():
		var built := keys.any(func(start: String) -> bool: return start.ends_with(".") and key.begins_with(start))
		if not key.is_empty() and key not in keys and not built:
			missing.append("written nowhere: " + key)
	assert_array(missing).is_empty()


func test_with_no_words_given_the_engine_s_screens_show_keys_and_no_english() -> void:
	TranslationServer.clear()
	_world.options.add_engine_options(_world.dialogue, _world.texts)
	_world.screens.register(&"title", "res://addons/wildgrass/title/title_screen.tscn")
	_world.screens.register(&"pokedex", "res://addons/wildgrass/pokedex/pokedex_screen.tscn")
	var shown: Dictionary[String, Array] = {}
	var services := {"dialogue": _world.dialogue, "texts": _world.texts}
	var screens := {
		&"menu": {"menu": _world.menu},
		&"options": {"options": _world.options},
		&"save_slots": {"save": _world.save},
		&"bag": {"bag": _world.bag, "pocket": &"medicine"},
		&"pokedex": {"pokedex": _world.pokedex, "species": _world.species, "types": _world.types},
	}
	for screen_name: StringName in screens:
		var args: Dictionary = screens[screen_name].merged(services)
		var screen := _world.screens.open(screen_name, args)
		shown[screen_name] = _english(_texts_of(screen))
		screen.close()
	var debug := _world.debug.open()
	shown[&"debug"] = _english(_texts_of(debug))
	debug.close()
	var title := _world.title.show_title()
	title.set_process(false)
	title.advance(30.0)
	shown[&"title"] = _english(_texts_of(title))
	title.close()
	var empty: Dictionary[String, Array] = {}
	for screen_name: String in shown:
		empty[screen_name] = []
	assert_dict(shown).is_equal(empty)
