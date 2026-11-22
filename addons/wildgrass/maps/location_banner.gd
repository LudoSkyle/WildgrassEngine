## The place's banner: it slides down at the top left, stays, and slides up.
## The engine's is a panel in Godot's theme; a game's draws its styles in
## `_show_style()`. It never takes a key.
class_name WgLocationBanner
extends Control

## Seconds to slide in, and out.
@export var slide_seconds := 0.3
## Seconds it stays.
@export var stay_seconds := 2.2
## Its distance from the top left corner once in, in pixels.
@export var margin := 8.0
## The Control that slides.
@export var panel: NodePath = ^"Panel"
## The Label showing the name.
@export var label: NodePath = ^"Panel/Name"

enum Phase { HIDDEN, SLIDING_IN, STAYING, SLIDING_OUT }

## The name shown, and its style.
var zone_name := ""
var style: StringName = &""
var phase := Phase.HIDDEN

var _elapsed := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := _panel()
	if box != null:
		box.hide()


func _process(delta: float) -> void:
	advance(delta)


## Shows `text` in the style `banner_style`, sliding in from the start.
func show_zone(text: String, banner_style: StringName) -> void:
	zone_name = text
	style = banner_style
	var shown := get_node_or_null(label) as Label
	if shown != null:
		shown.text = text
	_show_style(banner_style)
	_set_phase(Phase.SLIDING_IN)
	var box := _panel()
	if box != null:
		box.reset_size()
		box.show()
	_place(0.0)


func is_showing() -> bool:
	return phase != Phase.HIDDEN


## Moves on by `delta` seconds.
func advance(delta: float) -> void:
	if phase == Phase.HIDDEN:
		return
	_elapsed += delta
	match phase:
		Phase.SLIDING_IN:
			_place(_progress())
			if _elapsed >= slide_seconds:
				_set_phase(Phase.STAYING)
		Phase.STAYING:
			if _elapsed >= stay_seconds:
				_set_phase(Phase.SLIDING_OUT)
		Phase.SLIDING_OUT:
			_place(1.0 - _progress())
			if _elapsed >= slide_seconds:
				_set_phase(Phase.HIDDEN)
				var box := _panel()
				if box != null:
					box.hide()


## Override to draw `banner_style`: a texture, the colour of the text.
func _show_style(_banner_style: StringName) -> void:
	pass


func _panel() -> Control:
	return get_node_or_null(panel) as Control


func _set_phase(next: Phase) -> void:
	phase = next
	_elapsed = 0.0


func _progress() -> float:
	return minf(_elapsed / slide_seconds, 1.0) if slide_seconds > 0.0 else 1.0


## 0: hidden above the screen; 1: in place.
func _place(amount: float) -> void:
	var box := _panel()
	if box == null:
		return
	var hidden := -box.size.y - margin
	box.position = Vector2(margin, hidden + (margin - hidden) * amount)
