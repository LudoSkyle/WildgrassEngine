## The way into a game: splashes, the language at first launch, the title
## screen and its choices, a new game or one continued, and back to the title.
extends RefCounted

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")
const ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const ScreenRegistry := preload("res://addons/wildgrass/core/screens/screen_registry.gd")
const Story := preload("res://addons/wildgrass/story/story.gd")
const Entries := preload("res://addons/wildgrass/menu/entries.gd")
const Maps := preload("res://addons/wildgrass/maps/maps.gd")
const Dialogue := preload("res://addons/wildgrass/dialogue/dialogue.gd")
const Save := preload("res://addons/wildgrass/save/save.gd")
const Options := preload("res://addons/wildgrass/options/options.gd")
const Texts := preload("res://addons/wildgrass/texts/texts.gd")

## The title screen shows; a game plays its music.
signal title_shown
## A game was left for the title.
signal back_to_title
## A game is on screen, the black lifted: `new`, a new game.
signal game_started(slot: int, new: bool)
signal _game_chosen

@warning_ignore("shadowed_global_identifier")
var log: Log
## What the screens the title opens are given: the services, by name.
var services := {}
## The title screen while it shows.
var screen: WgScreen
## Called by the `quit` choice; the engine's quits the game.
var quit_game := func() -> void: (Engine.get_main_loop() as SceneTree).quit()

var _paths: Paths
var _config: ConfigRegistry
var _screens: ScreenRegistry
var _maps: Maps
var _save: Save
var _options: Options
var _texts: Texts
var _choices: Entries
var _starting := false


func _init(paths: Paths, logger: Log, config_registry: ConfigRegistry, screen_registry: ScreenRegistry, story: Story, maps: Maps, dialogue: Dialogue, save: Save, options: Options, texts: Texts) -> void:
	_paths = paths
	log = logger
	_config = config_registry
	_screens = screen_registry
	_maps = maps
	_save = save
	_options = options
	_texts = texts
	_choices = Entries.new(story)
	services = {"dialogue": dialogue, "texts": texts, "save": save, "options": options}
	add_choice(&"play", "Play", play, "", &"")
	add_choice(&"options", "Options", open_options, "", &"")
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		add_choice(&"quit", "Quit", quit, "", &"")


func config() -> WgTitleConfig:
	return _config.get_config(&"title") as WgTitleConfig


## Shows the splashes, asks the language at first launch, then shows the
## title. Awaited; a second call while it runs does nothing.
func start() -> void:
	if _starting:
		return
	_starting = true
	for path in config().splashes:
		var texture := load_image(path, "title splash")
		if texture != null:
			await _until_closed(_screens.open(&"splash", _given({"texture": texture})))
	if must_choose_language():
		await choose_language()
	_starting = false
	show_title()


## True when the language is to be asked: the config wants it, two languages
## or more are choosable, none was ever kept in the options and no game is
## saved.
func must_choose_language() -> bool:
	return config().choose_language and _texts.languages().size() >= 2 and not _options.was_kept(&"language") and not has_game()


## Opens the `language_choice` screen; the one picked is kept as the
## `language` option.
func choose_language() -> void:
	var picked := [""]
	var opened := _screens.open(&"language_choice", _given({"languages": _texts.languages()}))
	if opened == null or opened.is_closed():
		return
	if opened.has_signal(&"chosen"):
		opened.chosen.connect(func(code: String) -> void: picked[0] = code)
	await opened.closed
	if picked[0].is_empty():
		return
	if _options.has_option(&"language"):
		_options.set_value(&"language", picked[0])
	else:
		_texts.language = picked[0]


## Opens the `title` screen; the one already open, if it is.
func show_title() -> WgScreen:
	if is_instance_valid(screen) and not screen.is_closed():
		return screen
	screen = _screens.open(&"title", _given({"title": self}))
	if screen != null and not screen.is_closed():
		title_shown.emit()
	return screen


## Back to the title from a game: every screen closed, the message box and
## what it had to say with them, the maps dropped, every part of the game reset. True: the menu closes.
func back() -> bool:
	if _maps.is_changing:
		return false
	# The maps first: a message closing asks nothing of them then.
	_maps.clear()
	_close_screens()
	_save.reset()
	back_to_title.emit()
	show_title()
	return true


## True if a slot holds a game.
func has_game() -> bool:
	return _save.slots().any(func(slot: int) -> bool: return _save.has(slot))


## Adds a choice before `before` (the last one if it is not there): its
## callable is awaited and returns true to close the title. An id taken again
## replaces that choice where it stands. Texts are labels.
func add_choice(id: StringName, text: String, callable: Callable, condition := "", before: StringName = &"quit") -> void:
	_choices.add(id, text, callable, condition, before)


func remove_choice(id: StringName) -> bool:
	return _choices.remove(id)


## Every choice's id, in order.
func choices() -> Array[StringName]:
	return _choices.ids()


## The choices whose condition holds now, in order.
func shown() -> Array[Dictionary]:
	return _choices.shown()


## A new game in `slot`, on the config's start map: the screen fades to black,
## the title hides beneath it, the traveller arrives, black lifts and the
## title closes. False, logged, the title staying, with no start map, no
## traveller, or a start map that cannot be reached.
func new_game(slot := 1) -> bool:
	var settings := config()
	var map_id := StringName(settings.start_map)
	if not _maps.has_map(map_id):
		log.error(&"title", "no start map '%s' for a new game (title config, start_map)" % map_id)
		return false
	if _maps.traveller == null:
		log.error(&"title", "no traveller for a new game: set Wildgrass.maps.traveller")
		return false
	var veil := await _cover()
	_save.new_game(slot)
	_show_screens(false, veil)
	if not await _maps.warp(map_id, StringName(settings.start_point), &"none"):
		log.error(&"title", "the new game could not reach '%s'" % map_id)
		_save.reset()
		_show_screens(true, veil)
		await _uncover(veil)
		return false
	await _leave(veil)
	game_started.emit(slot, true)
	return true


## Continues the game of `slot`, leaving the title as a new game does. False,
## the title staying, if it cannot be loaded.
func continue_game(slot: int) -> bool:
	var veil := await _cover()
	if not await _save.load_game(slot):
		await _uncover(veil)
		return false
	_show_screens(false, veil)
	await _leave(veil)
	game_started.emit(slot, false)
	return true


## The engine's choices.
func play() -> bool:
	if not has_game():
		return await new_game(1)
	return await choose_game()


## Opens `save_slots` over the title; a game chosen there starts as
## `new_game()` or `continue_game()` do. True if one started.
func choose_game() -> bool:
	# The screen closes beneath the fade, before the game is on screen.
	var state := {"started": false, "starting": false}
	var starting := func(slot: int, start: Callable) -> bool:
		state["starting"] = true
		state["started"] = await start.call(slot)
		state["starting"] = false
		_game_chosen.emit()
		return state["started"]
	var opened := _screens.open(&"save_slots", _given({"new_game": starting.bind(new_game), "continue": starting.bind(continue_game)}))
	await _until_closed(opened)
	if state["starting"]:
		await _game_chosen
	return state["started"]


func open_options() -> bool:
	await _until_closed(_screens.open(&"options", _given()))
	return false


func quit() -> bool:
	quit_game.call()
	return true


## The image at `path`, imported or a plain file; null, reported once, if it
## is missing.
func load_image(path: String, requester: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image != null:
			return ImageTexture.create_from_image(image)
	_paths.report_missing(path, requester)
	return null


func _given(args := {}) -> Dictionary:
	var given := services.duplicate()
	given.merge(args, true)
	return given


func _cover() -> WgTransition:
	var veil := _screens.open(&"transition_fade", {"seconds": config().fade_seconds}) as WgTransition
	if veil != null:
		await veil.cover()
	return veil


func _uncover(veil: WgTransition) -> void:
	if veil == null:
		return
	await veil.uncover()
	veil.close()


## Lifts the black over the game, then closes the screens hidden beneath it:
## closed at the end, the screens waiting on a choice are still there when it
## returns.
func _leave(veil: WgTransition) -> void:
	await _uncover(veil)
	_close_screens()


## Closes every open screen, the top one first.
func _close_screens() -> void:
	var open := _screens.stack()
	open.reverse()
	for opened in open:
		if is_instance_valid(opened):
			opened.close()


## Shows or hides every open screen but `kept`.
func _show_screens(shown: bool, kept: WgScreen) -> void:
	for opened in _screens.stack():
		if opened != kept:
			opened.visible = shown


static func _until_closed(opened: WgScreen) -> void:
	if opened != null and not opened.is_closed():
		await opened.closed
