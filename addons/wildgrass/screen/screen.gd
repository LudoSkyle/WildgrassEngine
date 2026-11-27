## What a scene does to the screen (feature 21, step 2), as the reference
## does, in RPG Maker's ticks (60 a second): the tone of the map, a flash, a
## shake, the view scrolled away from the player, pictures over the map, the
## screen held still then shown again through a transition. The state only:
## its view (`screen_view.gd`) draws it. Kept by the save.
extends RefCounted

const _Log := preload("res://addons/wildgrass/core/log/log.gd")
const _ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")

## One of RPG Maker's frames.
const TICK := 1.0 / 60.0
## The pictures' numbers: 1 to this.
const PICTURES := 50
## A transition with no picture lasts this many ticks, one through a
## picture this many, as the reference's.
const DISSOLVE_TICKS := 20
const PICTURE_TRANSITION_TICKS := 60
enum Origin { TOP_LEFT, CENTER }
enum Blend { NORMAL, ADD, SUBTRACT }

@warning_ignore("shadowed_global_identifier")
var log: _Log
## Red, green, blue added (-255 to 255), gray (0 to 255): the map's tone.
var tone := Vector4.ZERO
## How much of the day's tint shows (feature 16): 0 while a tone is set,
## back to 1 as it goes neutral.
var day_share := 1.0
## The flash shown; its alpha goes down to 0.
var flash_color := Color(0, 0, 0, 0)
## The shake's sideways offset, in game pixels.
var shake := 0.0
## How far the view is scrolled from the player, in game pixels.
var scroll_offset := Vector2.ZERO
## Set by the view: the scroll offset it can show (within the map), given one.
var clamp_scroll := Callable()
## The screen held still (`freeze()`), until a transition ends.
var frozen := false
## The transition under way: its picture (null: a dissolve), and how far it
## is, 0 to 1.
var transition_texture: Texture2D
var transition_progress := 0.0

var _config: _ConfigRegistry
var _time := 0.0
var _tone_target := Vector4.ZERO
var _day_target := 1.0
var _tone_ticks := 0
var _flash_ticks := 0
var _shake_power := 0
var _shake_speed := 0
var _shake_ticks := 0
var _shake_direction := 1
var _scroll_direction := Vector2i.ZERO
var _scroll_rest := 0.0
var _scroll_speed := 4
var _transition_ticks := 0
var _transition_total := 0
var _pictures: Dictionary[int, Dictionary] = {}


func _init(logger: _Log, config_registry: _ConfigRegistry) -> void:
	log = logger
	_config = config_registry


## Tones the map toward `target` over `seconds`; zero: back to the day's
## tint, which a tone replaces while it lasts.
func tone_to(target: Vector4, seconds := 0.0) -> void:
	_tone_target = Vector4(clampf(target.x, -255, 255), clampf(target.y, -255, 255), clampf(target.z, -255, 255), clampf(target.w, 0, 255))
	_day_target = 1.0 if _tone_target == Vector4.ZERO else 0.0
	_tone_ticks = _ticks(seconds)
	if _tone_ticks == 0:
		tone = _tone_target
		day_share = _day_target


## Flashes `color` over the map and pictures, fading over `seconds`.
func flash(color: Color, seconds := 0.0) -> void:
	flash_color = color
	_flash_ticks = _ticks(seconds)


## Shakes the map sideways: `power` and `speed` 1 to 9, for `seconds`.
func shake_screen(power: int, speed: int, seconds: float) -> void:
	_shake_power = power
	_shake_speed = speed
	_shake_ticks = _ticks(seconds)


## Scrolls the view `cells` cells toward `direction` at RPG Maker's `speed`
## (1 to 6: `2^speed / 128` cells a tick), held within the map.
func scroll(direction: Vector2i, cells: int, speed: int) -> void:
	_scroll_direction = direction
	_scroll_rest = maxf(cells, 0) * _cell()
	_scroll_speed = clampi(speed, 1, 6)


func is_scrolling() -> bool:
	return _scroll_rest > 0.0


## Shows `texture` as picture `number` (1 to 50). Options: `origin`
## (`Origin`), `position` (game pixels from the screen's top-left), `zoom`
## (`Vector2`, percent), `opacity` (0 to 255), `blend` (`Blend`).
func show_picture(number: int, texture: Texture2D, options := {}) -> void:
	if not _valid(number):
		return
	var shown := {
		"texture": texture, "origin": int(options.get("origin", Origin.TOP_LEFT)),
		"position": Vector2(options.get("position", Vector2.ZERO)), "zoom": Vector2(options.get("zoom", Vector2(100, 100))),
		"opacity": float(options.get("opacity", 255.0)), "blend": int(options.get("blend", Blend.NORMAL)),
		"tone": Vector4.ZERO, "angle": 0.0, "rotate_speed": 0.0,
	}
	shown.merge({"to_position": shown["position"], "to_zoom": shown["zoom"], "to_opacity": shown["opacity"], "ticks": 0,
		"to_tone": Vector4.ZERO, "tone_ticks": 0})
	_pictures[number] = shown
	if texture == null:
		log.warn(&"screen", "picture %d shows nothing: no texture" % number)


## Moves picture `number` toward the options given (as `show_picture`'s;
## those not given stay) over `seconds`.
func move_picture(number: int, seconds: float, options := {}) -> void:
	var shown: Dictionary = _pictures.get(number, {})
	if shown.is_empty():
		return
	shown["origin"] = int(options.get("origin", shown["origin"]))
	shown["blend"] = int(options.get("blend", shown["blend"]))
	shown["to_position"] = Vector2(options.get("position", shown["to_position"]))
	shown["to_zoom"] = Vector2(options.get("zoom", shown["to_zoom"]))
	shown["to_opacity"] = float(options.get("opacity", shown["to_opacity"]))
	shown["ticks"] = _ticks(seconds)
	if shown["ticks"] == 0:
		_land(shown)


## Turns picture `number` by `speed / 2` degrees a tick (0: stops).
func rotate_picture(number: int, speed: float) -> void:
	if _pictures.has(number):
		_pictures[number]["rotate_speed"] = speed


## Tones picture `number` toward `target` over `seconds`.
func tone_picture(number: int, target: Vector4, seconds := 0.0) -> void:
	var shown: Dictionary = _pictures.get(number, {})
	if shown.is_empty():
		return
	shown["to_tone"] = target
	shown["tone_ticks"] = _ticks(seconds)
	if shown["tone_ticks"] == 0:
		shown["tone"] = target


func erase_picture(number: int) -> void:
	_pictures.erase(number)


## Picture `number` as it shows now (`texture`, `origin`, `position`, `zoom`,
## `opacity`, `blend`, `tone`, `angle`); empty if none.
func picture(number: int) -> Dictionary:
	return _pictures.get(number, {})


## The numbers of the pictures shown, in order.
func picture_numbers() -> Array[int]:
	var numbers: Array[int] = []
	numbers.assign(_pictures.keys())
	numbers.sort()
	return numbers


## Holds what shows still, until `transition()`.
func freeze() -> void:
	frozen = true
	transition_progress = 0.0
	_transition_ticks = 0


## Shows the screen again: a dissolve of 20 ticks, or through `texture` (its
## dark parts first) in 60 ticks; `seconds` above 0 sets the length.
func transition(texture: Texture2D = null, seconds := 0.0) -> void:
	if not frozen:
		return
	transition_texture = texture
	_transition_total = _ticks(seconds) if seconds > 0.0 else (PICTURE_TRANSITION_TICKS if texture != null else DISSOLVE_TICKS)
	_transition_ticks = _transition_total
	transition_progress = 0.0
	if _transition_total == 0:
		_end_transition()


func is_transitioning() -> bool:
	return frozen and _transition_ticks > 0


## Moves everything on by `delta` seconds, tick by tick.
func advance(delta: float) -> void:
	_time += delta
	while _time >= TICK * 0.999:
		_time -= TICK
		_tick()


## The view scrolled away from a player on another map comes back.
func reset_scroll() -> void:
	scroll_offset = Vector2.ZERO
	_scroll_rest = 0.0


## The `screen` part of a saved game: the tone, the scroll and the pictures.
func state() -> Dictionary:
	var shown := {}
	for number: int in _pictures:
		var picture_state := {}
		for key: String in _pictures[number]:
			var value: Variant = _pictures[number][key]
			picture_state[key] = (value as Texture2D).resource_path if value is Texture2D else var_to_str(value)
		shown[str(number)] = picture_state
	return {
		"tone": var_to_str(tone), "tone_target": var_to_str(_tone_target), "tone_ticks": _tone_ticks,
		"day_share": day_share, "day_target": _day_target, "scroll": var_to_str(scroll_offset), "pictures": shown,
	}


func restore(saved: Dictionary) -> void:
	reset()
	tone = _vector4(saved.get("tone"))
	_tone_target = _vector4(saved.get("tone_target"))
	_tone_ticks = int(saved.get("tone_ticks", 0))
	day_share = float(saved.get("day_share", 1.0))
	_day_target = float(saved.get("day_target", 1.0))
	var offset: Variant = str_to_var(str(saved.get("scroll", "")))
	scroll_offset = offset if offset is Vector2 else Vector2.ZERO
	var shown: Variant = saved.get("pictures", {})
	for key: Variant in (shown as Dictionary if shown is Dictionary else {}):
		var number := str(key).to_int()
		var picture_state: Variant = shown[key]
		if not _valid(number) or not picture_state is Dictionary:
			continue
		var restored := {}
		for field: String in picture_state:
			var value: Variant = picture_state[field]
			if field == "texture":
				restored[field] = load(str(value)) as Texture2D if ResourceLoader.exists(str(value)) else null
			else:
				restored[field] = str_to_var(str(value))
		_pictures[number] = restored


## A new game: no tone, no flash, no shake, no scroll, no picture.
func reset() -> void:
	tone = Vector4.ZERO
	_tone_target = Vector4.ZERO
	_tone_ticks = 0
	day_share = 1.0
	_day_target = 1.0
	flash_color = Color(0, 0, 0, 0)
	_flash_ticks = 0
	shake = 0.0
	_shake_ticks = 0
	_shake_power = 0
	reset_scroll()
	_pictures.clear()
	frozen = false
	_transition_ticks = 0
	transition_progress = 0.0


func _tick() -> void:
	if _tone_ticks >= 1:
		var d := float(_tone_ticks)
		tone = (tone * (d - 1) + _tone_target) / d
		day_share = (day_share * (d - 1) + _day_target) / d
		_tone_ticks -= 1
	if _flash_ticks >= 1:
		flash_color.a = flash_color.a * (_flash_ticks - 1) / _flash_ticks
		_flash_ticks -= 1
	if _shake_ticks >= 1 or shake != 0.0:
		var change := (_shake_power * _shake_speed * _shake_direction) / 10.0
		if _shake_ticks <= 1 and shake * (shake + change) < 0:
			shake = 0.0
		else:
			shake += change
		if shake > _shake_power * 2:
			_shake_direction = -1
		if shake < -_shake_power * 2:
			_shake_direction = 1
		if _shake_ticks >= 1:
			_shake_ticks -= 1
	if _scroll_rest > 0.0:
		var distance := minf(pow(2.0, _scroll_speed) / 128.0 * _cell(), _scroll_rest)
		var wanted := scroll_offset + Vector2(_scroll_direction) * distance
		scroll_offset = clamp_scroll.call(wanted) if clamp_scroll.is_valid() else wanted
		_scroll_rest -= distance
	for number: int in _pictures:
		_tick_picture(_pictures[number])
	if is_transitioning():
		_transition_ticks -= 1
		transition_progress = 1.0 - float(_transition_ticks) / _transition_total
		if _transition_ticks == 0:
			_end_transition()


## A picture's share of the way left, as the reference's.
func _tick_picture(shown: Dictionary) -> void:
	if shown["ticks"] >= 1:
		var d := float(shown["ticks"])
		shown["position"] = (shown["position"] * (d - 1) + shown["to_position"]) / d
		shown["zoom"] = (shown["zoom"] * (d - 1) + shown["to_zoom"]) / d
		shown["opacity"] = (shown["opacity"] * (d - 1) + shown["to_opacity"]) / d
		shown["ticks"] -= 1
	if shown["tone_ticks"] >= 1:
		var d := float(shown["tone_ticks"])
		shown["tone"] = (shown["tone"] * (d - 1) + shown["to_tone"]) / d
		shown["tone_ticks"] -= 1
	if shown["rotate_speed"] != 0.0:
		shown["angle"] = fposmod(shown["angle"] + shown["rotate_speed"] / 2.0, 360.0)


func _land(shown: Dictionary) -> void:
	shown["position"] = shown["to_position"]
	shown["zoom"] = shown["to_zoom"]
	shown["opacity"] = shown["to_opacity"]


func _end_transition() -> void:
	frozen = false
	_transition_ticks = 0
	transition_progress = 1.0
	transition_texture = null


func _valid(number: int) -> bool:
	if number >= 1 and number <= PICTURES:
		return true
	log.warn(&"screen", "no picture numbered %d: 1 to %d" % [number, PICTURES])
	return false


func _cell() -> float:
	var config := _config.get_config(&"map") as WgMapConfig if _config != null else null
	return float(config.tile_size) if config != null else 16.0


static func _ticks(seconds: float) -> int:
	return maxi(roundi(seconds / TICK), 0)


static func _vector4(saved: Variant) -> Vector4:
	var value: Variant = str_to_var(str(saved)) if saved != null else null
	return value if value is Vector4 else Vector4.ZERO
