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
const ScreenRegistry := preload("res://addons/wildgrass/core/screens/screen_registry.gd")
const Maps := preload("res://addons/wildgrass/maps/maps.gd")
const Tiles := preload("res://addons/wildgrass/tiles/tiles.gd")

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
var screens: ScreenRegistry
var maps: Maps
var tiles: Tiles
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
	tiles = _service(&"tiles", Tiles, [log, config, hooks, maps])
	config.register(&"log", WgLogConfig, "log_config")
	config.register(&"display", WgDisplayConfig, "display_config")
	config.register(&"map", WgMapConfig, "map_config")
	screens.register(&"transition_none", "res://addons/wildgrass/maps/transitions/none.tscn")
	screens.register(&"transition_fade", "res://addons/wildgrass/maps/transitions/fade.tscn")


func _ready() -> void:
	paths.asset_missing.connect(func(path: String, requester: String) -> void:
		log.warn(&"paths", "%s, requested by %s" % [path, requester]))
	log.configure(config.get_config(&"log") as WgLogConfig)
	if config.has_file(&"display"):
		display.apply(config.get_config(&"display") as WgDisplayConfig, get_window())
	Clock.declare_shader_global()
	clock.updates_shader_global = true
	_start.call_deferred()


func _process(delta: float) -> void:
	clock.advance(delta)


func _unhandled_input(event: InputEvent) -> void:
	if screens.handle_input(event):
		get_viewport().set_input_as_handled()


## Runs after every autoload and the main scene are ready, so they can add
## `engine_ready` hooks first.
func _start() -> void:
	hooks.run(&"engine_ready")
	ready_for_game.emit()


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
