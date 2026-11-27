## Draws `Wildgrass.screen` each frame (feature 21, step 2): the map's tone
## over the map, the pictures above it, the flash over both, the still of a
## frozen screen over all but the screens; the shake and the scroll as the
## camera's. Made by the engine; a game does not place it.
extends Node

const _Screen := preload("res://addons/wildgrass/screen/screen.gd")
const _ToneShader := preload("res://addons/wildgrass/screen/tone.gdshader")
const _TransitionShader := preload("res://addons/wildgrass/screen/transition.gdshader")

## The canvas layers, above the maps (0), under the screens.
const TONE_LAYER := 10
const PICTURE_LAYER := 20
const FLASH_LAYER := 30
const STILL_LAYER := 90

var screen: _Screen

var _tone: ColorRect
var _pictures: Node2D
var _sprites: Dictionary[int, Sprite2D] = {}
var _flash: ColorRect
var _still: TextureRect
var _was_frozen := false
var _materials: Dictionary[int, Shader] = {}
var _camera: Camera2D


func _init(shown: _Screen) -> void:
	screen = shown
	name = "ScreenEffects"
	_tone = _full_rect(ColorRect.new())
	var tone_material := ShaderMaterial.new()
	tone_material.shader = _ToneShader
	tone_material.set_shader_parameter(&"use_screen", true)
	_tone.material = tone_material
	_layer(TONE_LAYER, "Tone").add_child(_tone)
	_pictures = Node2D.new()
	_pictures.name = "Pictures"
	_layer(PICTURE_LAYER, "Pictures").add_child(_pictures)
	_flash = _full_rect(ColorRect.new())
	_layer(FLASH_LAYER, "Flash").add_child(_flash)
	_still = _full_rect(TextureRect.new())
	_still.stretch_mode = TextureRect.STRETCH_SCALE
	var still_material := ShaderMaterial.new()
	still_material.shader = _TransitionShader
	_still.material = still_material
	_layer(STILL_LAYER, "Still").add_child(_still)
	screen.clamp_scroll = _clamp_scroll


func _process(_delta: float) -> void:
	draw()


## Shows the screen's state now.
func draw() -> void:
	_tone.visible = screen.tone != Vector4.ZERO
	if _tone.visible:
		(_tone.material as ShaderMaterial).set_shader_parameter(&"tone", screen.tone)
	_flash.visible = screen.flash_color.a > 0.0
	_flash.color = Color(screen.flash_color.r, screen.flash_color.g, screen.flash_color.b, screen.flash_color.a)
	_draw_pictures()
	_draw_still()
	_place_camera()


func _draw_pictures() -> void:
	var numbers := screen.picture_numbers()
	for number: int in _sprites.keys():
		if number not in numbers:
			_sprites[number].queue_free()
			_sprites.erase(number)
	for number in numbers:
		var shown := screen.picture(number)
		var sprite: Sprite2D = _sprites.get(number)
		if sprite == null:
			sprite = Sprite2D.new()
			sprite.name = "Picture%d" % number
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.material = ShaderMaterial.new()
			_pictures.add_child(sprite)
			_sprites[number] = sprite
		sprite.z_index = number
		sprite.texture = shown["texture"]
		sprite.centered = shown["origin"] == _Screen.Origin.CENTER
		sprite.position = shown["position"]
		sprite.scale = shown["zoom"] / 100.0
		sprite.rotation = -deg_to_rad(shown["angle"])
		sprite.modulate = Color(1, 1, 1, clampf(shown["opacity"] / 255.0, 0.0, 1.0))
		var material := sprite.material as ShaderMaterial
		material.shader = _blend_shader(shown["blend"])
		material.set_shader_parameter(&"tone", shown["tone"])


## The tone shader drawn as `blend` blends.
func _blend_shader(blend: int) -> Shader:
	if not _materials.has(blend):
		var made := Shader.new()
		var mode := "blend_add" if blend == _Screen.Blend.ADD else ("blend_sub" if blend == _Screen.Blend.SUBTRACT else "blend_mix")
		made.code = _ToneShader.code.replace("shader_type canvas_item;", "shader_type canvas_item;\nrender_mode %s;" % mode)
		_materials[blend] = made
	return _materials[blend]


func _draw_still() -> void:
	if screen.frozen and not _was_frozen:
		_still.texture = _capture()
	_was_frozen = screen.frozen
	_still.visible = screen.frozen and _still.texture != null
	if not _still.visible:
		return
	var material := _still.material as ShaderMaterial
	material.set_shader_parameter(&"progress", screen.transition_progress)
	material.set_shader_parameter(&"use_mask", screen.transition_texture != null)
	material.set_shader_parameter(&"mask", screen.transition_texture)


## What shows now, as a texture; null where it cannot be read (headless).
func _capture() -> Texture2D:
	var image := get_viewport().get_texture().get_image() if is_inside_tree() else null
	return ImageTexture.create_from_image(image) if image != null and not image.is_empty() else null


## The shake moves the view sideways past the map's edges, as the
## reference's; the scroll moves it within them.
func _place_camera() -> void:
	var camera := get_viewport().get_camera_2d() if is_inside_tree() else null
	if camera != _camera and is_instance_valid(_camera):
		_camera.position = Vector2.ZERO
		_camera.offset = Vector2.ZERO
	_camera = camera
	if camera == null:
		return
	camera.position = screen.scroll_offset
	camera.offset = Vector2(screen.shake, 0.0)


## `wanted`, the scroll offset, where the camera's limits let the view go.
func _clamp_scroll(wanted: Vector2) -> Vector2:
	var camera := get_viewport().get_camera_2d() if is_inside_tree() else null
	if camera == null or camera.get_parent() == null:
		return wanted
	var centre := (camera.get_parent() as Node2D).global_position if camera.get_parent() is Node2D else Vector2.ZERO
	var half := camera.get_viewport_rect().size / camera.zoom / 2.0
	var low := Vector2(camera.limit_left, camera.limit_top) + half
	var high := Vector2(camera.limit_right, camera.limit_bottom) - half
	var shown := centre + wanted
	for axis in 2:
		if low[axis] <= high[axis]:
			shown[axis] = clampf(shown[axis], low[axis], high[axis])
		else:
			shown[axis] = (low[axis] + high[axis]) / 2.0
	return shown - centre


func _layer(at: int, layer_name: String) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = at
	layer.name = layer_name
	add_child(layer)
	return layer


static func _full_rect(control: Control) -> Control:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.visible = false
	return control
