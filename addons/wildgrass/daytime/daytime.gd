## The hour of the game, the player's clock or an hour of its own, and the
## moments of the day it falls in: their tint and light.
extends RefCounted

const _Log := preload("res://addons/wildgrass/core/log/log.gd")
const _ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const _Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")

## The shader globals it keeps up to date.
const TINT_GLOBAL := &"day_tint"
const LIGHT_GLOBAL := &"night_light"

## The hour crossed a mark of another moment.
signal moment_changed(old: StringName, new: StringName)

@warning_ignore("shadowed_global_identifier")
var log: _Log
## An hour that wins over the others, 0 to 24; -1: none. Not saved.
var forced_hour := -1.0
## Keeps `day_tint` and `night_light` up to date; set once they are declared.
var updates_shader_globals := false
## What tints the maps outside, under the maps' host.
var canvas_modulate: CanvasModulate

var _config: _ConfigRegistry
## The game's own time, in minutes since day 0 at midnight.
var _minutes := -1.0
var _moment: StringName = &""
var _maps: Object


func _init(logger: _Log, config_registry: _ConfigRegistry, hooks: _Hooks) -> void:
	log = logger
	_config = config_registry
	hooks.add(&"story_term", &"wildgrass_daytime", _story_term)


func config() -> WgDaytimeConfig:
	return _config.get_config(&"daytime") as WgDaytimeConfig


## The hour, 0 to 24: 18.5 at half past six.
func hour() -> float:
	if forced_hour >= 0.0:
		return fmod(forced_hour, 24.0)
	if config().source == "game":
		return fmod(_game_minutes() / 60.0, 24.0)
	var now := Time.get_time_dict_from_system()
	return now["hour"] + now["minute"] / 60.0 + now["second"] / 3600.0


## The days gone by since the game started (`game`), else the day of the year
## from 1.
func day() -> int:
	if config().source == "game":
		return int(_game_minutes() / 1440.0)
	var today := Time.get_date_dict_from_system()
	var first := Time.get_unix_time_from_datetime_dict({"year": today["year"], "month": 1, "day": 1})
	return int((Time.get_unix_time_from_datetime_dict(today) - first) / 86400.0) + 1


## 0 for Monday to 6 for Sunday.
func weekday() -> int:
	if config().source == "game":
		return day() % 7
	return (int(Time.get_date_dict_from_system()["weekday"]) + 6) % 7


## Tints the maps outside: the current map's, under the maps' host.
func follow(maps: Object) -> void:
	_maps = maps


## Declares the shader globals the project does not.
static func declare_shader_globals() -> void:
	if not ProjectSettings.has_setting("shader_globals/" + TINT_GLOBAL):
		RenderingServer.global_shader_parameter_add(TINT_GLOBAL, RenderingServer.GLOBAL_VAR_TYPE_COLOR, Color.WHITE)
	if not ProjectSettings.has_setting("shader_globals/" + LIGHT_GLOBAL):
		RenderingServer.global_shader_parameter_add(LIGHT_GLOBAL, RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)


## The tint of the maps now: the moment's times the current map's shade
## outside, white inside.
func map_tint() -> Color:
	var map: WgMap = _maps.current if _maps != null else null
	if map == null or not map.outside:
		return Color.WHITE
	return tint() * map.shade


## The light of lights now: the moment's outside, 0 inside.
func map_light() -> float:
	var map: WgMap = _maps.current if _maps != null else null
	return light() if map != null and map.outside else 0.0


## Moves the game's own hour on by `delta` seconds of the game clock, tints
## the maps, and tells when the moment changes.
func advance(delta: float) -> void:
	if config().source == "game":
		_minutes = _game_minutes() + maxf(delta, 0.0) * config().minutes_per_second
	_apply()
	var now := moment()
	if now != _moment:
		var old := _moment
		_moment = now
		if not old.is_empty():
			moment_changed.emit(old, now)


## The moment of the last mark reached at `at`.
func moment(at := -1.0) -> StringName:
	return StringName(str(_between(at)[0][1]))


## The tint at `at`, gliding between two marks.
func tint(at := -1.0) -> Color:
	var marks := _between(at)
	var moments := config().moments
	var from := WgDaytimeConfig.color_of(moments[marks[0][1]].get("tint", Color.WHITE))
	var to := WgDaytimeConfig.color_of(moments[marks[1][1]].get("tint", Color.WHITE))
	return from.lerp(to, marks[2])


## The strength of lights at `at`, 0 to 1, gliding between two marks.
func light(at := -1.0) -> float:
	var marks := _between(at)
	var moments := config().moments
	return lerpf(float(moments[marks[0][1]].get("light", 0.0)), float(moments[marks[1][1]].get("light", 0.0)), marks[2])


func _apply() -> void:
	var color := map_tint()
	if _maps != null and is_instance_valid(_maps.host):
		if not is_instance_valid(canvas_modulate):
			canvas_modulate = CanvasModulate.new()
			_maps.host.add_child(canvas_modulate)
		canvas_modulate.color = color
	if updates_shader_globals:
		_set_shader_globals(color, map_light())


func _set_shader_globals(color: Color, strength: float) -> void:
	RenderingServer.global_shader_parameter_set(TINT_GLOBAL, color)
	RenderingServer.global_shader_parameter_set(LIGHT_GLOBAL, strength)


## The game's own time: a part of the saved game.
func state() -> Dictionary:
	return {"minutes": _game_minutes()}


func restore(saved: Dictionary) -> void:
	_minutes = maxf(float(saved.get("minutes", config().start_hour * 60.0)), 0.0)


## A new game: its own hour at `start_hour`.
func reset() -> void:
	_minutes = config().start_hour * 60.0


func _game_minutes() -> float:
	if _minutes < 0.0:
		_minutes = config().start_hour * 60.0
	return _minutes


## The marks before and after `at` and how far between them, [from, to,
## progress]; the day goes round.
func _between(at: float) -> Array:
	var time := fmod(fmod(hour() if at < 0.0 else at, 24.0) + 24.0, 24.0)
	var keys := config().keys
	var after := 0
	while after < keys.size() and float(keys[after][0]) <= time:
		after += 1
	var from: Array = keys[after - 1] if after > 0 else [float(keys.back()[0]) - 24.0, keys.back()[1]]
	var to: Array = keys[after] if after < keys.size() else [float(keys[0][0]) + 24.0, keys[0][1]]
	var start := float(from[0])
	var span := float(to[0]) - start
	var progress := (time - start) / span if span > 0.0 else 0.0
	return [from, to, clampf(progress, 0.0, 1.0)]


## `time:<moment>` in a story condition.
func _story_term(read: Variant, term: String, _node: Node) -> Variant:
	if read != null or not term.begins_with("time:"):
		return read
	return moment() == StringName(term.substr(5))
