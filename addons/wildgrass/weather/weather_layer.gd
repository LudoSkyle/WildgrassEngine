## What a weather draws over a map outside: particles that each live on their
## own, a tiled layer drifting, and the tone of the screen. Everything is
## anchored to the map; the view only says where a particle is born or wraps.
class_name WgWeatherLayer
extends Node2D

const _Daytime := preload("res://addons/wildgrass/daytime/daytime.gd")
const TONE_SHADER := preload("res://addons/wildgrass/weather/weather_tone.gdshader")

## How far the tone's rectangle goes past the view, in pixels.
const MARGIN := 32.0
## Snow's steps aside, drawn at random, and its variety by rank.
const SWAY: Array[int] = [2, 1, 0, -1]
const VARIETY: Array[int] = [2, 1, 1, 0, 0, -1]

## The weather drawn; none: nothing.
var weather: WgWeather
## The day and night its sun fades with; none: never.
var daytime: _Daytime
## The view, in the layer's coordinates.
var view := Rect2(0, 0, 320, 240)
var sprites: Array[Sprite2D] = []
var tiles: Array[Sprite2D] = []
var tone_rect: ColorRect

var _places: PackedVector2Array = []
var _lives: PackedFloat64Array = []
var _shown: PackedFloat64Array = []
var _tiles_wide := 0
var _tiles_tall := 0
var _tile_origin := Vector2.ZERO
var _pulse := 0.0
var _pulse_way := 1.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	z_index = 51
	tone_rect = ColorRect.new()
	tone_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tone_rect.material = ShaderMaterial.new()
	(tone_rect.material as ShaderMaterial).shader = TONE_SHADER
	tone_rect.visible = false
	add_child(tone_rect, false, Node.INTERNAL_MODE_BACK)
	_rng.randomize()


func _process(delta: float) -> void:
	locate()
	advance(delta)


@warning_ignore("shadowed_global_identifier")
func seed(value: int) -> void:
	_rng.seed = value


## Draws `next`, its particles born again.
func show_weather(next: WgWeather) -> void:
	weather = next
	var count := next.particle_count if next != null and not next.particles.is_empty() else 0
	while sprites.size() > count:
		sprites.pop_back().queue_free()
	while sprites.size() < count:
		var sprite := Sprite2D.new()
		sprite.centered = false
		add_child(sprite)
		sprites.append(sprite)
	_places.resize(count)
	_lives.resize(count)
	_shown.resize(count)
	for rank in count:
		sprites[rank].texture = next.picture(rank)
		_lives[rank] = 0.0
		_shown[rank] = 0.0
	var picture: Texture2D = next.layer if next != null else null
	_tiles_wide = ceili(view.size.x / picture.get_width()) + 1 if picture != null else 0
	_tiles_tall = ceili(view.size.y / picture.get_height()) + 1 if picture != null else 0
	while tiles.size() > _tiles_wide * _tiles_tall:
		tiles.pop_back().queue_free()
	while tiles.size() < _tiles_wide * _tiles_tall:
		var tile := Sprite2D.new()
		tile.centered = false
		add_child(tile)
		tiles.append(tile)
	for tile in tiles:
		tile.texture = picture
	_pulse = 0.0
	_pulse_way = 1.0


## Where the view is: the camera's, else the viewport's.
func locate() -> void:
	var camera := get_viewport().get_camera_2d() if is_inside_tree() else null
	if camera == null:
		return
	var size := get_viewport_rect().size / camera.zoom
	var corner := to_local(camera.get_screen_center_position() - size / 2.0)
	view = Rect2(corner.round(), size)


## Moves everything on by `delta` seconds.
func advance(delta: float) -> void:
	if weather == null:
		tone_rect.visible = false
		return
	for rank in sprites.size():
		_move(rank, delta)
		sprites[rank].position = _places[rank].round()
		sprites[rank].modulate.a = _shown[rank]
	if not tiles.is_empty():
		_drift(delta)
	_tone(delta)


## Particle `rank` born again: a splash anywhere in the view, a drop where it
## crosses the view along its slope, for a random distance.
func _born(rank: int) -> void:
	var picture := sprites[rank].texture
	if picture == null:
		return
	var w := float(picture.get_width())
	var h := float(picture.get_height())
	var origin := view.position
	var size := view.size
	if weather.is_splash(rank):
		_places[rank] = Vector2(origin.x - w + _rand(size.x + w * 2.0), origin.y - h + _rand(size.y + h * 2.0))
		_lives[rank] = (30 + _rng.randi_range(0, 19)) * 0.01
		_shown[rank] = 0.0
		return
	var velocity := weather.particle_velocity
	var slope := velocity.x / velocity.y if velocity.y != 0.0 else INF
	if absf(slope) >= 1.0:
		var x := origin.x + size.x + _rand(size.x)
		var y := origin.y + size.y - _rand(size.y + h - (size.x / slope))
		_places[rank] = Vector2(x, y)
		_lives[rank] = absf((x - origin.x - size.x / 2.0 + w + _rand(size.x * 8.0 / 5.0)) / velocity.x)
	else:
		var x := origin.x - w + _rand(size.x + w - slope * size.y)
		var y := origin.y - h - _rand(size.y)
		_places[rank] = Vector2(x, y)
		_lives[rank] = absf((origin.y - y + size.y / 2.0 + _rand(size.y * 8.0 / 5.0)) / velocity.y)
	_shown[rank] = 1.0


func _move(rank: int, delta: float) -> void:
	var picture := sprites[rank].texture
	if picture == null:
		return
	_lives[rank] -= delta
	if _lives[rank] <= 0.0:
		_born(rank)
		return
	if weather.is_splash(rank):
		_shown[rank] = 1.0 if _lives[rank] < 0.2 else 0.0
		return
	var step := weather.particle_velocity * delta
	var place := _places[rank] + step
	var origin := view.position
	var size := view.size
	if weather.floating:
		place.x += step.x * (place.y - origin.y) / (size.y * 3.0)
		place.x += SWAY[_rng.randi_range(0, 3)] * step.x / 8.0
		place.y += VARIETY[rank % 6] * step.y / 10.0
	var w := float(picture.get_width())
	var h := float(picture.get_height())
	if place.x - origin.x > size.x:
		place.x -= size.x
	if place.x - origin.x < -w:
		place.x += size.x
	if place.y - origin.y > size.y:
		place.y -= size.y
	if place.y - origin.y < -h:
		place.y += size.y
	_places[rank] = place
	if _shown[rank] < 0.25 or place.x - origin.x < -w or place.y - origin.y > size.y:
		_born(rank)


## The layer drifts, its tiles put back as they leave the view.
func _drift(delta: float) -> void:
	var tile_size := Vector2(tiles[0].texture.get_size())
	var origin := view.position
	_tile_origin += weather.layer_velocity * delta
	while _tile_origin.x < origin.x - tile_size.x:
		_tile_origin.x += tile_size.x
	while _tile_origin.x > origin.x:
		_tile_origin.x -= tile_size.x
	while _tile_origin.y < origin.y - tile_size.y:
		_tile_origin.y += tile_size.y
	while _tile_origin.y > origin.y:
		_tile_origin.y -= tile_size.y
	for index in tiles.size():
		var place := _tile_origin.round() + Vector2(index % _tiles_wide, index / _tiles_wide) * tile_size
		if place.x - origin.x < -tile_size.x:
			place.x += _tiles_wide * tile_size.x
		if place.y - origin.y > view.size.y:
			place.y -= _tiles_tall * tile_size.y
		tiles[index].position = place


## The tone: the weather's, beating for the sun and fading at night.
func _tone(delta: float) -> void:
	var tone := weather.tone
	if weather.pulse > 0.0:
		if (_pulse_way > 0.0 and _pulse > weather.pulse) or (_pulse_way < 0.0 and _pulse < 0.0):
			_pulse_way = -_pulse_way
		_pulse += _pulse_way * weather.pulse * delta / weather.pulse_seconds
		tone += Vector3(_pulse, _pulse, _pulse / 2.0)
	if weather.sunlight and daytime != null:
		tone *= 1.0 - daytime.map_light()
	var material := tone_rect.material as ShaderMaterial
	material.set_shader_parameter(&"tone", tone)
	material.set_shader_parameter(&"gray", weather.gray)
	tone_rect.visible = tone != Vector3.ZERO or weather.gray != 0.0
	tone_rect.position = view.position - Vector2(MARGIN, MARGIN)
	tone_rect.size = view.size + Vector2(MARGIN, MARGIN) * 2.0


## An integer from 0 to `limit`, excluded; 0 for a limit below 1.
func _rand(limit: float) -> float:
	var bound := int(limit)
	return float(_rng.randi_range(0, bound - 1)) if bound > 0 else 0.0
