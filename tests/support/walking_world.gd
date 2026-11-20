## The services walkers need, built for one test, with a map to walk on.
extends RefCounted

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")
const ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")
const ScreenRegistry := preload("res://addons/wildgrass/core/screens/screen_registry.gd")
const Maps := preload("res://addons/wildgrass/maps/maps.gd")
const Tiles := preload("res://addons/wildgrass/tiles/tiles.gd")
const Walkers := preload("res://addons/wildgrass/walking/walkers.gd")
const Sandbox := preload("res://tests/support/sandbox.gd")
const T := preload("res://tests/support/tile_builder.gd")

var sandbox: Sandbox
var logged: Array[String] = []
var hooks: Hooks
var screens: ScreenRegistry
var maps: Maps
var tiles: Tiles
var walkers: Walkers
## Parent of the maps and the screens; free it with the test.
var root: Node2D
var tile_set: TileSet


func _init(parent: Node, map_config := {}) -> void:
	sandbox = Sandbox.new()
	sandbox.use_data_folder()
	var levels := {"solidLayers": [1, 2], "edgeLayers": [4, 5]}
	levels.merge(map_config, true)
	sandbox.write_json("Data/configs/map_config.json", levels)
	var logger := Log.new()
	logger.echo = false
	# A local array: a lambda reaching `self` would keep this world alive.
	var lines: Array[String] = []
	logged = lines
	logger.logged.connect(func(level: Log.Level, _channel: StringName, message: String) -> void:
		lines.append("%s %s" % [Log.Level.keys()[level], message]))
	var config := ConfigRegistry.new(Paths.new(false), logger)
	config.register(&"map", WgMapConfig, "map_config")
	config.register(&"movement", WgMovementConfig, "movement_config")
	hooks = Hooks.new()
	root = Node2D.new()
	parent.add_child(root)
	var screen_layer := Node.new()
	root.add_child(screen_layer)
	screens = ScreenRegistry.new(logger, screen_layer)
	screens.register(&"transition_none", "res://addons/wildgrass/maps/transitions/none.tscn")
	var host := Node2D.new()
	root.add_child(host)
	maps = Maps.new(Paths.new(false), logger, config, hooks, screens, host)
	tiles = Tiles.new(logger, config, hooks, maps)
	walkers = Walkers.new(logger, config, hooks, screens, maps, tiles)
	tile_set = T.tile_set()


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
