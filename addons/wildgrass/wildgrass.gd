## Entry point of the engine: every service goes through it.
extends Node

## Emitted once the engine has started and the `engine_ready` hooks have run.
signal ready_for_game

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")
const ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const Display := preload("res://addons/wildgrass/core/display/display.gd")
const Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")
const Clock := preload("res://addons/wildgrass/core/clock/clock.gd")
const Texts := preload("res://addons/wildgrass/texts/texts.gd")
const ScreenRegistry := preload("res://addons/wildgrass/core/screens/screen_registry.gd")
const Maps := preload("res://addons/wildgrass/maps/maps.gd")
const Tiles := preload("res://addons/wildgrass/tiles/tiles.gd")
const Walkers := preload("res://addons/wildgrass/walking/walkers.gd")
const Story := preload("res://addons/wildgrass/story/story.gd")
const Quests := preload("res://addons/wildgrass/story/quests.gd")
const Items := preload("res://addons/wildgrass/bag/items.gd")
const Bag := preload("res://addons/wildgrass/bag/bag.gd")
const Dialogue := preload("res://addons/wildgrass/dialogue/dialogue.gd")
const Save := preload("res://addons/wildgrass/save/save.gd")
const Menu := preload("res://addons/wildgrass/menu/menu.gd")
const Options := preload("res://addons/wildgrass/options/options.gd")
const Studio := preload("res://addons/wildgrass/studio/studio.gd")
const Title := preload("res://addons/wildgrass/title/title.gd")
const SpeciesData := preload("res://addons/wildgrass/pokemon/species_data.gd")
const Types := preload("res://addons/wildgrass/pokemon/types.gd")
const Pokedex := preload("res://addons/wildgrass/pokedex/pokedex.gd")
const Encounters := preload("res://addons/wildgrass/wild/encounters.gd")
const Audio := preload("res://addons/wildgrass/audio/audio.gd")
const Daytime := preload("res://addons/wildgrass/daytime/daytime.gd")

## A project setting here names a subclass to use instead of a service.
const SERVICE_SETTING_PREFIX := "wildgrass/services/"
const SCREEN_LAYER := 100

var paths: Paths
@warning_ignore("shadowed_global_identifier")
var log: Log
var config: ConfigRegistry
var display: Display
var hooks: Hooks
var clock: Clock
var texts: Texts
var screens: ScreenRegistry
var maps: Maps
var tiles: Tiles
var walkers: Walkers
var story: Story
var quests: Quests
var items: Items
var bag: Bag
var dialogue: Dialogue
var save: Save
var menu: Menu
var options: Options
var title: Title
var species: SpeciesData
var types: Types
var pokedex: Pokedex
var encounters: Encounters
var audio: Audio
var daytime: Daytime
## The Studio layer, installed when the project is a Studio project.
var studio: Studio
## Parent of every open screen, above the game.
var screen_layer: CanvasLayer
## Default parent of the maps on screen; y-sorted, so the lower map draws on top.
var map_host: Node2D


func _init() -> void:
	paths = _service(&"paths", Paths)
	log = _service(&"log", Log)
	config = _service(&"config", ConfigRegistry, [paths, log])
	display = _service(&"display", Display)
	hooks = _service(&"hooks", Hooks)
	clock = _service(&"clock", Clock)
	daytime = _service(&"daytime", Daytime, [log, config, hooks])
	texts = _service(&"texts", Texts, [paths, log, config, hooks])
	screen_layer = CanvasLayer.new()
	screen_layer.name = "Screens"
	screen_layer.layer = SCREEN_LAYER
	add_child(screen_layer)
	screens = _service(&"screens", ScreenRegistry, [log, screen_layer])
	map_host = Node2D.new()
	map_host.name = "Map"
	map_host.y_sort_enabled = true
	add_child(map_host)
	maps = _service(&"maps", Maps, [paths, log, config, hooks, screens, map_host])
	daytime.follow(maps)
	tiles = _service(&"tiles", Tiles, [log, config, hooks, maps])
	story = _service(&"story", Story, [log, hooks, maps])
	quests = _service(&"quests", Quests, [log, hooks, paths])
	items = _service(&"items", Items, [paths, log, config])
	species = _service(&"species", SpeciesData, [paths, log])
	types = _service(&"types", Types, [paths, log])
	pokedex = _service(&"pokedex", Pokedex, [paths, log, config, species])
	bag = _service(&"bag", Bag, [log, hooks, items, quests])
	walkers = _service(&"walkers", Walkers, [log, config, hooks, screens, maps, tiles])
	dialogue = _service(&"dialogue", Dialogue, [log, config, hooks, screens, maps, texts])
	walkers.dialogue = dialogue
	walkers.story = story
	walkers.bag = bag
	encounters = _service(&"encounters", Encounters, [paths, log, config, maps, story, species, tiles, hooks, pokedex, dialogue])
	walkers.encounters = encounters
	var audio_host := Node.new()
	audio_host.name = "Audio"
	add_child(audio_host)
	audio = _service(&"audio", Audio, [paths, log, config, species, audio_host])
	audio.follow(maps)
	story.add_tags(dialogue)
	bag.add_tags(dialogue, screens)
	save = _service(&"save", Save, [paths, log, config, hooks])
	_add_parts()
	menu = _service(&"menu", Menu, [log, screens, story])
	menu.services = {"bag": bag, "dialogue": dialogue, "texts": texts, "save": save}
	walkers.menu = menu
	_add_entries()
	options = _service(&"options", Options, [paths, log, config])
	menu.services["options"] = options
	menu.add_entry(&"options", "Options", menu.open_options, "", &"save")
	title = _service(&"title", Title, [paths, log, config, screens, story, maps, dialogue, save, options, texts])
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
	studio = _service(&"studio", Studio, [paths, log, config, hooks])
	if studio.is_project():
		studio.install(texts, items, quests, species, types, pokedex, encounters)
	menu.services.merge({"pokedex": pokedex, "species": species, "types": types, "screens": screens})
	menu.add_entry(&"pokedex", "Pokédex", _open_pokedex, (config.get_config(&"pokedex") as WgPokedexConfig).condition, &"bag")
	screens.register(&"transition_none", "res://addons/wildgrass/maps/transitions/none.tscn")
	screens.register(&"transition_fade", "res://addons/wildgrass/maps/transitions/fade.tscn")
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


## The engine's parts of a saved game, in the order they are restored.
func _add_parts() -> void:
	save.add_part(&"story", story.state, story.restore, story.reset)
	save.add_part(&"quests", quests.state, quests.restore, quests.reset)
	save.add_part(&"bag", bag.state, bag.restore, bag.reset)
	save.add_part(&"clock", clock.state, clock.restore, clock.reset)
	save.add_part(&"daytime", daytime.state, daytime.restore, daytime.reset)
	save.add_part(&"pokedex", pokedex.state, pokedex.restore, pokedex.reset)
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
	menu.add_entry(&"exit", "Exit", menu.exit)
	menu.add_entry(&"bag", "Bag", menu.open_bag)
	menu.add_entry(&"save", "Save", menu.open_save, "!save_disabled")


func _ready() -> void:
	paths.asset_missing.connect(func(path: String, requester: String) -> void:
		log.warn(&"paths", "%s, requested by %s" % [path, requester]))
	log.configure(config.get_config(&"log") as WgLogConfig)
	if config.is_given(&"display"):
		display.apply(config.get_config(&"display") as WgDisplayConfig, get_window())
	texts.apply_default()
	options.read()
	options.add_engine_options(dialogue, texts)
	audio.setup()
	options.add_volume_options(audio.config().buses)
	Clock.declare_shader_global()
	clock.updates_shader_global = true
	Daytime.declare_shader_globals()
	daytime.updates_shader_globals = true
	_start.call_deferred()


## A traveller out of the tree, back at the title, has no one else to free it:
## it would keep every service alive past the end.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and maps != null and is_instance_valid(maps.traveller) and maps.traveller.get_parent() == null:
		maps.traveller.free()


func _process(delta: float) -> void:
	clock.advance(delta)
	daytime.advance(delta)
	audio.advance(delta)


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
		if custom != null and ConfigRegistry._extends(custom, default):
			script = custom
		else:
			push_error("Wildgrass: %s must be a script extending %s, got '%s'" % [SERVICE_SETTING_PREFIX + service_name, default.resource_path, path])
	return script.callv(&"new", args)
