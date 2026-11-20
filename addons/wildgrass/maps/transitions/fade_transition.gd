## Fades to black, then back.
extends WgTransition

var _veil: ColorRect


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_veil = ColorRect.new()
	_veil.color = Color.BLACK
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.modulate.a = 0.0
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)


func cover() -> void:
	await _fade_to(1.0)


func uncover() -> void:
	await _fade_to(0.0)


## Opacity of the veil, 0 to 1.
func opacity() -> float:
	return _veil.modulate.a


func _fade_to(alpha: float) -> void:
	if seconds <= 0.0:
		_veil.modulate.a = alpha
		return
	var tween := create_tween()
	tween.tween_property(_veil, "modulate:a", alpha, seconds)
	await tween.finished
