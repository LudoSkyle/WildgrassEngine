## The services walkers and dialogue need, built for one test, with a map to
## walk on.
extends RefCounted

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")
const ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")
const ScreenRegistry := preload("res://addons/wildgrass/core/screens/screen_registry.gd")
const Maps := preload("res://addons/wildgrass/maps/maps.gd")
const Tiles := preload("res://addons/wildgrass/tiles/tiles.gd")
const Walkers := preload("res://addons/wildgrass/walking/walkers.gd")
const Dialogue := preload("res://addons/wildgrass/dialogue/dialogue.gd")
const Texts := preload("res://addons/wildgrass/texts/texts.gd")
const Story := preload("res://addons/wildgrass/story/story.gd")
const Quests := preload("res://addons/wildgrass/story/quests.gd")
const Items := preload("res://addons/wildgrass/bag/items.gd")
const Bag := preload("res://addons/wildgrass/bag/bag.gd")
const Clock := preload("res://addons/wildgrass/core/clock/clock.gd")
const Save := preload("res://addons/wildgrass/save/save.gd")
const Menu := preload("res://addons/wildgrass/menu/menu.gd")
const Options := preload("res://addons/wildgrass/options/options.gd")
const Sandbox := preload("res://tests/support/sandbox.gd")
const T := preload("res://tests/support/tile_builder.gd")

var sandbox: Sandbox
var logged: Array[String] = []
var hooks: Hooks
var screens: ScreenRegistry
var maps: Maps
var tiles: Tiles
var walkers: Walkers
var dialogue: Dialogue
var texts: Texts
var story: Story
var quests: Quests
var items: Items
var bag: Bag
var clock: Clock
var save: Save
var menu: Menu
## Its engine options are added by the tests that need them, once their
## configs are written.
var options: Options
var logger: Log
## The paths of this world: missing assets are reported there.
var paths: Paths
var config: ConfigRegistry
## Parent of the maps and the screens; free it with the test.
var root: Node2D
var tile_set: TileSet


func _init(parent: Node, map_config := {}) -> void:
	sandbox = Sandbox.new()
	sandbox.use_data_folder()
	sandbox.set_setting("wildgrass/paths/saves", sandbox.root + "saves/")
	var levels := {"solid_layers": [1, 2], "edge_layers": [4, 5]}
	levels.merge(map_config, true)
	sandbox.write_json("config/map.json", levels)
	logger = Log.new()
	logger.echo = false
	# A local array: a lambda reaching `self` would keep this world alive.
	var lines: Array[String] = []
	logged = lines
	logger.logged.connect(func(level: Log.Level, _channel: StringName, message: String) -> void:
		lines.append("%s %s" % [Log.Level.keys()[level], message]))
	config = ConfigRegistry.new(Paths.new(false), logger)
	config.register(&"display", WgDisplayConfig, "display")
	config.register(&"map", WgMapConfig, "map")
	config.register(&"movement", WgMovementConfig, "movement")
	config.register(&"dialogue", WgDialogueConfig, "dialogue")
	config.register(&"language", WgLanguageConfig, "language")
	config.register(&"bag", WgBagConfig, "bag")
	config.register(&"save", WgSaveConfig, "save")
	config.register(&"options", WgOptionsConfig, "options")
	hooks = Hooks.new()
	root = Node2D.new()
	parent.add_child(root)
	# Screens show at the game's size: 320×240.
	var screen_layer := Control.new()
	screen_layer.size = Vector2(320, 240)
	root.add_child(screen_layer)
	screens = ScreenRegistry.new(logger, screen_layer)
	screens.register(&"transition_none", "res://addons/wildgrass/maps/transitions/none.tscn")
	screens.register(&"message_box", "res://addons/wildgrass/dialogue/message_box.tscn")
	screens.register(&"item_reveal", "res://addons/wildgrass/bag/item_reveal.tscn")
	screens.register(&"bag", "res://addons/wildgrass/bag/bag_screen.tscn")
	screens.register(&"save", "res://addons/wildgrass/save/save_screen.tscn")
	screens.register(&"save_slots", "res://addons/wildgrass/save/save_slots_screen.tscn")
	screens.register(&"menu", "res://addons/wildgrass/menu/menu_screen.tscn")
	screens.register(&"options", "res://addons/wildgrass/options/options_screen.tscn")
	var host := Node2D.new()
	root.add_child(host)
	maps = Maps.new(Paths.new(false), logger, config, hooks, screens, host)
	tiles = Tiles.new(logger, config, hooks, maps)
	walkers = Walkers.new(logger, config, hooks, screens, maps, tiles)
	texts = Texts.new(Paths.new(false), logger, config, hooks)
	story = Story.new(logger, hooks, maps)
	quests = Quests.new(logger, hooks, Paths.new(false))
	paths = Paths.new(false)
	items = Items.new(paths, logger, config)
	bag = Bag.new(logger, hooks, items, quests)
	dialogue = Dialogue.new(logger, config, hooks, screens, maps, texts)
	walkers.dialogue = dialogue
	walkers.story = story
	walkers.bag = bag
	story.add_tags(dialogue)
	bag.add_tags(dialogue, screens)
	clock = Clock.new()
	save = Save.new(paths, logger, config, hooks)
	save.add_part(&"story", story.state, story.restore, story.reset)
	save.add_part(&"quests", quests.state, quests.restore, quests.reset)
	save.add_part(&"bag", bag.state, bag.restore, bag.reset)
	save.add_part(&"clock", clock.state, clock.restore, clock.reset)
	save.add_part(&"map", walkers.map_state, walkers.restore_map, walkers.reset_map, walkers.check_map)
	hooks.add(&"save_summary", &"wildgrass_clock", clock.save_summary)
	hooks.add(&"save_summary", &"wildgrass_map", walkers.map_summary)
	menu = Menu.new(logger, screens, story)
	menu.services = {"bag": bag, "dialogue": dialogue, "texts": texts, "save": save}
	walkers.menu = menu
	menu.add_entry(&"exit", "Exit", menu.exit)
	menu.add_entry(&"bag", "Bag", menu.open_bag)
	menu.add_entry(&"save", "Save", menu.open_save, "!save_disabled")
	options = Options.new(paths, logger, config)
	options.file_path = sandbox.root + "options.json"
	menu.services["options"] = options
	menu.add_entry(&"options", "Options", menu.open_options, "", &"save")
	tile_set = T.tile_set()
	hooks.add(&"map_built", &"test_world_walkers", _give_walkers)


## Walkers of a map built from its scene use this world's service, not the
## engine's.
func _give_walkers(node: Node, _map_id: StringName = &"") -> void:
	for child: Node in node.get_children():
		if child is WgWalker and (child as WgWalker).walkers == null:
			(child as WgWalker).walkers = walkers
		_give_walkers(child)


## A current map of `size` cells with an Entities node and tiles from `cells`.
func map(cells := {}, size := Vector2i(10, 10)) -> WgMap:
	var node := WgMap.new()
	node.size = size
	var entities := Node2D.new()
	entities.name = "Entities"
	node.add_child(entities)
	T.layer(node, tile_set, cells, -1)
	maps.host.add_child(node)
	maps.current = node
	return node


## A walker in the current map, a little off the centre of `cell`, that only
## moves when the test advances it. `frames`: give it a Sprite with them, and
## a Shadow.
func walker(cell: Vector2i, controller: WgWalkerController = null, frames: SpriteFrames = null) -> WgWalker:
	var node := WgWalker.new()
	node.walkers = walkers
	node.position = tiles.center_of(cell) + Vector2(3, -5)
	if controller != null:
		node.add_child(controller)
	if frames != null:
		var sprite := AnimatedSprite2D.new()
		sprite.name = "Sprite"
		sprite.sprite_frames = frames
		node.add_child(sprite)
		var shadow := Sprite2D.new()
		shadow.name = "Shadow"
		node.add_child(shadow)
	maps.current.entities_node().add_child(node)
	node.set_process(false)
	return node


## Sprite frames with an animation of two frames for each name.
static func frames(names: Array[String]) -> SpriteFrames:
	var result := SpriteFrames.new()
	result.remove_animation(&"default")
	var texture := ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
	for animation_name: String in names:
		result.add_animation(animation_name)
		result.add_frame(animation_name, texture)
		result.add_frame(animation_name, texture)
		result.set_animation_loop(animation_name, not animation_name.begins_with("turn"))
	return result


func cleanup() -> void:
	sandbox.cleanup()
