## Applies `display_config` to a window.
extends RefCounted


## The game works in game pixels but is drawn at window size, keeping its
## aspect ratio, with nearest filtering.
func apply(config: WgDisplayConfig, window: Window) -> void:
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.content_scale_size = config.resolution
	window.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	if config.fullscreen:
		window.mode = Window.MODE_FULLSCREEN
	else:
		window.mode = Window.MODE_WINDOWED
		window.size = config.resolution * config.window_scale
