## Screens by name. Which scene opens, first match wins: a scene set with
## `set_scene()`, the project setting `wildgrass/screens/<name>`, the default
## given to `register()`. Open screens stack; only the top one gets input.
extends RefCounted

const _Log := preload("res://addons/wildgrass/core/log/log.gd")
const SETTING_PREFIX := "wildgrass/screens/"

signal screen_opened(screen_name: StringName, screen: WgScreen)
signal screen_closed(screen_name: StringName)
## The top screen took `event`.
signal input_taken(event: InputEvent)

var _log: _Log
var _layer: Node
var _defaults: Dictionary[StringName, String] = {}
var _overrides: Dictionary[StringName, String] = {}
var _stack: Array[WgScreen] = []
var _took_frame := -1


## Screens are added as children of `layer`.
func _init(logger: _Log, layer: Node) -> void:
	_log = logger
	_layer = layer


## Declares a screen and its default scene.
func register(screen_name: StringName, path: String) -> void:
	_defaults[screen_name] = path


## Sets the scene of a screen during play. An empty path removes the override.
func set_scene(screen_name: StringName, path: String) -> void:
	if path.is_empty():
		_overrides.erase(screen_name)
	else:
		_overrides[screen_name] = path


## The scene that `open()` would use, or "".
func scene_path(screen_name: StringName) -> String:
	if _overrides.has(screen_name):
		return _overrides[screen_name]
	var setting := str(ProjectSettings.get_setting(SETTING_PREFIX + screen_name, ""))
	if not setting.is_empty():
		return setting
	return _defaults.get(screen_name, "")


## Opens a screen on top of the others. Null, with an error logged, if it
## cannot be opened. A screen that closes itself in `_on_open` is returned
## already closed and never announced.
func open(screen_name: StringName, args: Dictionary = {}) -> WgScreen:
	var path := scene_path(screen_name)
	if path.is_empty():
		_log.error(&"screens", "unknown screen '%s'" % screen_name)
		return null
	var scene := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene == null:
		_log.error(&"screens", "%s: no scene at %s" % [screen_name, path])
		return null
	var node := scene.instantiate()
	if not node is WgScreen:
		_log.error(&"screens", "%s: the root of %s is not a WgScreen" % [screen_name, path])
		node.free()
		return null
	var screen := node as WgScreen
	screen.screen_name = screen_name
	if not _stack.is_empty():
		_set_active(_stack.back(), false)
	_stack.append(screen)
	screen.closed.connect(_on_screen_closed.bind(screen))
	_layer.add_child(screen)
	screen._on_open(args)
	if not screen.is_closed():
		screen_opened.emit(screen_name, screen)
	return screen


## The top screen, or null.
func top() -> WgScreen:
	return null if _stack.is_empty() else _stack.back()


## Open screens, bottom first.
func stack() -> Array[WgScreen]:
	return _stack.duplicate()


func is_open(screen_name: StringName) -> bool:
	return _stack.any(func(screen: WgScreen) -> bool: return screen.screen_name == screen_name)


## Gives `event` to the top screen. Returns true if it handled it.
func handle_input(event: InputEvent) -> bool:
	var screen := top()
	if screen == null or not screen._on_input(event):
		return false
	_took_frame = Engine.get_process_frames()
	input_taken.emit(event)
	return true


## True in the frame a screen handled an input event, even if it closed since:
## the game does not act on that press too.
func took_input() -> bool:
	return _took_frame == Engine.get_process_frames()


func _on_screen_closed(screen: WgScreen) -> void:
	var was_top := screen == top()
	_stack.erase(screen)
	if was_top and not _stack.is_empty():
		_set_active(_stack.back(), true)
	screen_closed.emit(screen.screen_name)


## Mouse and focus reach the top screen only.
static func _set_active(screen: WgScreen, active: bool) -> void:
	screen.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED if active else Control.MOUSE_BEHAVIOR_DISABLED
	screen.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED if active else Control.FOCUS_BEHAVIOR_DISABLED
