## Entry point of the engine: every service goes through it.
extends Node

## Emitted once the engine has started and the `engine_ready` hooks have run.
signal ready_for_game

const _Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const _Log := preload("res://addons/wildgrass/core/log/log.gd")
const _ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const _Display := preload("res://addons/wildgrass/core/display/display.gd")
const _Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")
const _Clock := preload("res://addons/wildgrass/core/clock/clock.gd")
const _Texts := preload("res://addons/wildgrass/texts/texts.gd")
const _ScreenRegistry := preload("res://addons/wildgrass/core/screens/screen_registry.gd")
const _Maps := preload("res://addons/wildgrass/maps/maps.gd")
const _Tiles := preload("res://addons/wildgrass/tiles/tiles.gd")
const _Walkers := preload("res://addons/wildgrass/walking/walkers.gd")
const _Followers := preload("res://addons/wildgrass/walking/followers.gd")
const _Story := preload("res://addons/wildgrass/story/story.gd")
const _Quests := preload("res://addons/wildgrass/story/quests.gd")
const _Items := preload("res://addons/wildgrass/bag/items.gd")
const _Bag := preload("res://addons/wildgrass/bag/bag.gd")
const _Dialogue := preload("res://addons/wildgrass/dialogue/dialogue.gd")
const _Save := preload("res://addons/wildgrass/save/save.gd")
const _Menu := preload("res://addons/wildgrass/menu/menu.gd")
const _Options := preload("res://addons/wildgrass/options/options.gd")
const _Studio := preload("res://addons/wildgrass/studio/studio.gd")
const _Title := preload("res://addons/wildgrass/title/title.gd")
const _SpeciesData := preload("res://addons/wildgrass/pokemon/species_data.gd")
const _Types := preload("res://addons/wildgrass/pokemon/types.gd")
const _Pokedex := preload("res://addons/wildgrass/pokedex/pokedex.gd")
const _Encounters := preload("res://addons/wildgrass/wild/encounters.gd")
const _Audio := preload("res://addons/wildgrass/audio/audio.gd")
const _Daytime := preload("res://addons/wildgrass/daytime/daytime.gd")
const _Weather := preload("res://addons/wildgrass/weather/weather.gd")
const _TallGrass := preload("res://addons/wildgrass/life/tall_grass.gd")
const _Footprints := preload("res://addons/wildgrass/life/footprints.gd")
const _Reflections := preload("res://addons/wildgrass/life/reflections.gd")
const _ReflectionsDriver := preload("res://addons/wildgrass/life/reflections_driver.gd")
const _Zones := preload("res://addons/wildgrass/maps/zones.gd")
const _Debug := preload("res://addons/wildgrass/debug/debug.gd")
const _EngineTools := preload("res://addons/wildgrass/debug/engine_tools.gd")
const _Events := preload("res://addons/wildgrass/events/events.gd")

## A project setting here names a subclass to use instead of a service.
const SERVICE_SETTING_PREFIX := "wildgrass/services/"
const SCREEN_LAYER := 100

var paths: _Paths
@warning_ignore("shadowed_global_identifier")
var log: _Log
var config: _ConfigRegistry
var display: _Display
var hooks: _Hooks
var clock: _Clock
var texts: _Texts
var screens: _ScreenRegistry
var maps: _Maps
var tiles: _Tiles
var walkers: _Walkers
var events: _Events
var followers: _Followers
var story: _Story
var quests: _Quests
var items: _Items
var bag: _Bag
var dialogue: _Dialogue
var save: _Save
var menu: _Menu
var options: _Options
var title: _Title
var species: _SpeciesData
var types: _Types
var pokedex: _Pokedex
var encounters: _Encounters
var audio: _Audio
var daytime: _Daytime
var weather: _Weather
var grass: _TallGrass
var footprints: _Footprints
var reflections: _Reflections
var zones: _Zones
## The debug tools.
var debug: _Debug
## The engine's debug tools, on the `engine` page.
var debug_tools: _EngineTools
## The Studio layer, installed when the project is a Studio project.
var studio: _Studio
## Parent of every open screen, above the game.
var screen_layer: CanvasLayer
## Default parent of the maps on screen; y-sorted, so the lower map draws on top.
var map_host: Node2D


func _init() -> void:
	paths = _service(&"paths", _Paths)
	log = _service(&"log", _Log)
	config = _service(&"config", _ConfigRegistry, [paths, log])
	display = _service(&"display", _Display)
	hooks = _service(&"hooks", _Hooks)
	clock = _service(&"clock", _Clock)
	daytime = _service(&"daytime", _Daytime, [log, config, hooks])
	texts = _service(&"texts", _Texts, [paths, log, config, hooks])
	screen_layer = CanvasLayer.new()
	screen_layer.name = "Screens"
	screen_layer.layer = SCREEN_LAYER
	add_child(screen_layer)
	screens = _service(&"screens", _ScreenRegistry, [log, screen_layer])
	map_host = Node2D.new()
	map_host.name = "Map"
	map_host.y_sort_enabled = true
	add_child(map_host)
	maps = _service(&"maps", _Maps, [paths, log, config, hooks, screens, map_host])
	daytime.follow(maps)
	zones = _service(&"zones", _Zones, [paths, log, maps, screens, texts, screen_layer])
	weather = _service(&"weather", _Weather, [paths, log])
	weather.daytime = daytime
	weather.follow(maps)
	tiles = _service(&"tiles", _Tiles, [log, config, hooks, maps])
	story = _service(&"story", _Story, [log, hooks, maps])
	texts.add_placeholder("flag", story.flag_text)
	texts.add_placeholder("value", story.value_text)
	quests = _service(&"quests", _Quests, [log, hooks, paths])
	items = _service(&"items", _Items, [paths, log, config])
	species = _service(&"species", _SpeciesData, [paths, log])
	types = _service(&"types", _Types, [paths, log])
	pokedex = _service(&"pokedex", _Pokedex, [paths, log, config, species])
	bag = _service(&"bag", _Bag, [log, hooks, items, quests])
	walkers = _service(&"walkers", _Walkers, [log, config, hooks, screens, maps, tiles])
	dialogue = _service(&"dialogue", _Dialogue, [log, config, hooks, screens, maps, texts])
	walkers.dialogue = dialogue
	walkers.story = story
	walkers.bag = bag
	encounters = _service(&"encounters", _Encounters, [paths, log, config, maps, story, species, tiles, hooks, pokedex, dialogue])
	walkers.encounters = encounters
	events = _service(&"events", _Events, [paths, log, hooks, maps, story, walkers, clock])
	events.bag = bag
	events.dialogue = dialogue
	followers = _service(&"followers", _Followers, [log, hooks, maps, walkers, species])
	grass = _service(&"grass", _TallGrass, [hooks, walkers, tiles])
	footprints = _service(&"footprints", _Footprints, [paths, config, maps, walkers, tiles])
	reflections = _service(&"reflections", _Reflections, [config, walkers, tiles])
	var reflections_driver := _ReflectionsDriver.new()
	reflections_driver.name = "Reflections"
	reflections_driver.reflections = reflections
	add_child(reflections_driver)
	var audio_host := Node.new()
	audio_host.name = "Audio"
	add_child(audio_host)
	audio = _service(&"audio", _Audio, [paths, log, config, species, audio_host])
	events.audio = audio
	audio.follow(maps)
	story.add_tags(dialogue)
	bag.add_tags(dialogue, screens)
	save = _service(&"save", _Save, [paths, log, config, hooks])
	_add_parts()
	menu = _service(&"menu", _Menu, [log, screens, story])
	menu.services = {"bag": bag, "dialogue": dialogue, "texts": texts, "save": save}
	walkers.menu = menu
	_add_entries()
	options = _service(&"options", _Options, [paths, log, config])
	menu.services["options"] = options
	menu.add_entry(&"options", "wg.menu.options", menu.open_options, "", &"save")
	title = _service(&"title", _Title, [paths, log, config, screens, story, maps, dialogue, save, options, texts])
	title.audio = audio
	audio.follow_game(screens, dialogue, save, bag, items)
	config.register(&"log", WgLogConfig, "log")
	config.register(&"display", WgDisplayConfig, "display")
	config.register(&"language", WgLanguageConfig, "language")
	config.register(&"bag", WgBagConfig, "bag")
	config.register(&"save", WgSaveConfig, "save")
	config.register(&"options", WgOptionsConfig, "options")
	config.register(&"map", WgMapConfig, "map")
	config.register(&"movement", WgMovementConfig, "movement")
	config.register(&"dialogue", WgDialogueConfig, "dialogue")
	config.register(&"studio", WgStudioConfig, "studio")
	config.register(&"title", WgTitleConfig, "title")
	config.register(&"pokedex", WgPokedexConfig, "pokedex")
	config.register(&"encounters", WgEncountersConfig, "encounters")
	config.register(&"audio", WgAudioConfig, "audio")
	config.register(&"daytime", WgDaytimeConfig, "daytime")
	config.register(&"footprints", WgFootprintsConfig, "footprints")
	config.register(&"reflections", WgReflectionsConfig, "reflections")
	studio = _service(&"studio", _Studio, [paths, log, config, hooks])
	if studio.is_project():
		studio.install(texts, items, quests, species, types, pokedex, encounters, zones)
	menu.services.merge({"pokedex": pokedex, "species": species, "types": types, "screens": screens})
	menu.add_entry(&"pokedex", "wg.menu.pokedex", _open_pokedex, (config.get_config(&"pokedex") as WgPokedexConfig).condition, &"bag")
	screens.register(&"transition_none", "res://addons/wildgrass/maps/transitions/none.tscn")
	screens.register(&"transition_fade", "res://addons/wildgrass/maps/transitions/fade.tscn")
	screens.register(&"transition_dissolve", "res://addons/wildgrass/maps/transitions/dissolve.tscn")
	screens.register(&"message_box", "res://addons/wildgrass/dialogue/message_box.tscn")
	screens.register(&"item_reveal", "res://addons/wildgrass/bag/item_reveal.tscn")
	screens.register(&"bag", "res://addons/wildgrass/bag/bag_screen.tscn")
	screens.register(&"save", "res://addons/wildgrass/save/save_screen.tscn")
	screens.register(&"save_slots", "res://addons/wildgrass/save/save_slots_screen.tscn")
	screens.register(&"menu", "res://addons/wildgrass/menu/menu_screen.tscn")
	screens.register(&"options", "res://addons/wildgrass/options/options_screen.tscn")
	screens.register(&"splash", "res://addons/wildgrass/title/splash_screen.tscn")
	screens.register(&"title", "res://addons/wildgrass/title/title_screen.tscn")
	screens.register(&"language_choice", "res://addons/wildgrass/title/language_choice_screen.tscn")
	screens.register(&"pokedex", "res://addons/wildgrass/pokedex/pokedex_screen.tscn")
	screens.register(&"pokedex_entry", "res://addons/wildgrass/pokedex/pokedex_entry_screen.tscn")
	screens.register(&"location_banner", "res://addons/wildgrass/maps/location_banner.tscn")
	screens.register(&"debug", "res://addons/wildgrass/debug/debug_screen.tscn")
	screens.register(&"species_view", "res://addons/wildgrass/debug/species_view_screen.tscn")
	config.register(&"debug", WgDebugConfig, "debug")
	debug = _service(&"debug", _Debug, [log, config, screens])
	debug.services = {"dialogue": dialogue, "texts": texts, "species": species, "screens": screens}
	debug_tools = _EngineTools.new(debug, {
		"texts": texts, "dialogue": dialogue, "bag": bag, "items": items, "quests": quests, "maps": maps,
		"daytime": daytime, "weather": weather, "pokedex": pokedex, "species": species, "clock": clock,
		"encounters": encounters, "followers": followers, "save": save, "hooks": hooks, "screens": screens,
	})


## The engine's parts of a saved game, in the order they are restored.
func _add_parts() -> void:
	save.add_part(&"story", story.state, story.restore, story.reset)
	save.add_part(&"quests", quests.state, quests.restore, quests.reset)
	save.add_part(&"bag", bag.state, bag.restore, bag.reset)
	save.add_part(&"clock", clock.state, clock.restore, clock.reset)
	save.add_part(&"daytime", daytime.state, daytime.restore, daytime.reset)
	save.add_part(&"pokedex", pokedex.state, pokedex.restore, pokedex.reset)
	save.add_part(&"followers", followers.state, followers.restore, followers.reset)
	save.add_part(&"map", walkers.map_state, walkers.restore_map, walkers.reset_map, walkers.check_map)
	hooks.add(&"save_summary", &"wildgrass_clock", clock.save_summary)
	hooks.add(&"save_summary", &"wildgrass_map", walkers.map_summary)
	hooks.add(&"save_summary", &"wildgrass_pokedex", pokedex.save_summary)


## The pause menu's Pokédex entry.
func _open_pokedex() -> bool:
	await menu.show_screen(&"pokedex")
	return false


## The engine's entries of the pause menu, in order.
func _add_entries() -> void:
	menu.add_entry(&"exit", "wg.menu.exit", menu.exit)
	menu.add_entry(&"bag", "wg.menu.bag", menu.open_bag)
	menu.add_entry(&"save", "wg.menu.save", menu.open_save, "!save_disabled")


func _ready() -> void:
	paths.asset_missing.connect(func(path: String, requester: String) -> void:
		log.warn(&"paths", "%s, requested by %s" % [path, requester]))
	log.configure(config.get_config(&"log") as WgLogConfig)
	# The display config's, given or by default; a project that chose its
	# window in Godot's settings and gives none keeps that window.
	if config.is_given(&"display") or not display.project_sets_window():
		display.apply(config.get_config(&"display") as WgDisplayConfig, get_window())
	texts.apply_default()
	options.read()
	options.add_engine_options(dialogue, texts)
	audio.setup()
	options.add_volume_options(audio.config().buses)
	_Clock.declare_shader_global()
	clock.updates_shader_global = true
	_Daytime.declare_shader_globals()
	daytime.updates_shader_globals = true
	if debug.is_enabled():
		menu.add_entry(&"debug", "wg.menu.debug", _open_debug, "", &"exit")
	_start.call_deferred()


## The pause menu's Debug entry.
func _open_debug() -> bool:
	return await debug.open_from_menu(menu)


## A traveller out of the tree, back at the title, has no one else to free it:
## it would keep every service alive past the end.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and maps != null and is_instance_valid(maps.traveller) and maps.traveller.get_parent() == null:
		maps.traveller.free()


func _process(delta: float) -> void:
	clock.advance(delta)
	events.advance(delta)
	daytime.advance(delta)
	grass.advance(delta)
	footprints.advance(delta)
	reflections.advance(delta)
	audio.advance(delta)
	dialogue.repeat_keys(delta)


func _unhandled_input(event: InputEvent) -> void:
	if screens.handle_input(event):
		get_viewport().set_input_as_handled()


## Runs after every autoload and the main scene are ready, so they can add
## `engine_ready` hooks first.
func _start() -> void:
	hooks.run(&"engine_ready")
	ready_for_game.emit()
	if (config.get_config(&"title") as WgTitleConfig).show_at_start:
		title.start()


func _service(service_name: StringName, default: GDScript, args: Array = []) -> Object:
	var script := default
	var path := str(ProjectSettings.get_setting(SERVICE_SETTING_PREFIX + service_name, ""))
	if not path.is_empty():
		var custom := load(path) as GDScript if ResourceLoader.exists(path) else null
		if custom != null and _ConfigRegistry._extends(custom, default):
			script = custom
		else:
			push_error("Wildgrass: %s must be a script extending %s, got '%s'" % [SERVICE_SETTING_PREFIX + service_name, default.resource_path, path])
	return script.callv(&"new", args)
