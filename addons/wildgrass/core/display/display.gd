## Applies `display_config` to a window.
extends RefCounted

## Godot's window settings: a project that changed one of them chose its
## window there, and the display config's defaults leave it as it is.
const WINDOW_SETTINGS: Array[String] = [
	"display/window/size/viewport_width",
	"display/window/size/viewport_height",
	"display/window/size/window_width_override",
	"display/window/size/window_height_override",
	"display/window/size/mode",
	"display/window/stretch/mode",
	"display/window/stretch/aspect",
	"display/window/stretch/scale",
]


## The screen's scale, the pixels of a point; 0: the screens' own (2 on a
## Retina screen).
var screen_scale := 0.0


## Whether the project set its window in Godot's own settings.
static func project_sets_window() -> bool:
	for setting in WINDOW_SETTINGS:
		if ProjectSettings.get_setting(setting) != ProjectSettings.property_get_revert(setting):
			return true
	return false


## The game works in game pixels but is drawn at window size, keeping its
## aspect ratio, with nearest filtering. The window's size counts the
## screen's points, as the player sees them: on a screen of scale 2
## (Retina) it is twice as many pixels.
func apply(config: WgDisplayConfig, window: Window) -> void:
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.content_scale_size = config.resolution
	window.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	if config.fullscreen:
		window.mode = Window.MODE_FULLSCREEN
	else:
		window.mode = Window.MODE_WINDOWED
		var scale := screen_scale if screen_scale > 0.0 else DisplayServer.screen_get_max_scale()
		window.size = (Vector2(config.resolution * config.window_scale) * scale).round()
		if window.is_inside_tree():
			window.move_to_center()
