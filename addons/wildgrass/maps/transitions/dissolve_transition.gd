## Keeps the last picture of the screen, then dissolves it into the new one:
## RPG Maker's fade. With no picture (no renderer), the new one shows at once.
extends WgTransition

var _picture: TextureRect


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_picture = TextureRect.new()
	_picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_picture)


## Takes the picture shown now, at once: nothing to wait for.
func cover() -> void:
	var shown := get_viewport().get_texture()
	var image := shown.get_image() if shown != null else null
	if image != null and not image.is_empty():
		_picture.texture = ImageTexture.create_from_image(image)


func uncover() -> void:
	if _picture.texture == null or seconds <= 0.0:
		_picture.modulate.a = 0.0
		return
	var tween := create_tween()
	tween.tween_property(_picture, "modulate:a", 0.0, seconds)
	await tween.finished


## Opacity of the old picture, 0 to 1; 0 with none.
func opacity() -> float:
	return _picture.modulate.a if _picture.texture != null else 0.0
