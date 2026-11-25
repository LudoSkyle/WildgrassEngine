## Studio's words for events' scripts (feature 22): the names Studio's Ruby
## scripts call, doing what they do in Studio, on the engine's services. A
## script translated from Ruby (by the importer or by hand) is written with
## them. The Studio layer's: a project uses it through the setting
## `wildgrass/events/script_context`; nothing of the engine depends on it.
extends WgScriptContext

const _StudioCharacter := preload("res://addons/wildgrass/studio/studio_character.gd")
const _StudioText := preload("res://addons/wildgrass/studio/studio_text.gd")

## Studio's common event shown as a trainer appears (a player seen in a band).
const APPEARANCE := 2
## Studio's names of the directions.
const NAMED_DIRECTIONS: Dictionary[StringName, int] = {&"down": 2, &"left": 4, &"right": 6, &"up": 8}

## The player, as Studio's scripts see it (`$game_player`).
var gp: _StudioCharacter:
	get:
		return _StudioCharacter.new(player, _events()) if player != null else null
## Studio's text variables (`PFM::Text`): `text.set_variable("[TEAM]", …)`.
var text: _StudioText:
	get:
		var events := _events()
		if not events.has_meta(&"studio_text"):
			events.set_meta(&"studio_text", _StudioText.new(events.get(&"texts")))
		return events.get_meta(&"studio_text")


## Variable `number` (`gv[number]`, `$game_variables[number]`): 0 if never set.
func gv(number: int) -> Variant:
	return value(StringName("variable_%d" % number))


## `gv[number] = new_value`.
func set_gv(number: int, new_value: Variant) -> void:
	set_value(StringName("variable_%d" % number), new_value)


## Switch `number` (`gs[number]`, `$game_switches[number]`).
func gs(number: int) -> bool:
	return flag(StringName("switch_%d" % number))


## `gs[number] = on`.
func set_gs(number: int, on: bool) -> void:
	set_flag(StringName("switch_%d" % number), on)


## Event `id` of the map (`ge(id)`), this event with none (`ge`); null if
## there is none.
func ge(id := 0) -> _StudioCharacter:
	return get_character(id)


## A character as Studio names it: -1 the player, 0 this event, else an
## event of the map; null if there is none.
func get_character(id: int) -> _StudioCharacter:
	var found := character(id)
	return _StudioCharacter.new(found, _events()) if found != null else null


## Turns local switch `letter` of event `event_id` (0: this one) of the map
## numbered `map_id` (0: the map the list started on) on or off.
func set_self_switch(on: bool, letter: String, event_id := 0, map_id := 0) -> void:
	var map := _map_named(map_id)
	if map_id == 0 or not map.is_empty():
		set_local(letter, on, event_id, map)


## True if local switch `letter` of event `event_id` of the map numbered
## `map_id` is on (0: as `set_self_switch`).
func get_self_switch(letter: String, event_id := 0, map_id := 0) -> bool:
	var map := _map_named(map_id)
	return (map_id == 0 or not map.is_empty()) and local(letter, event_id, map)


## True if this event sees the player within `reach` cells ahead, nothing
## between them (`player_spotted?`).
func player_spotted(reach: int) -> bool:
	return sees_player(reach)


func trainer_spotted(reach: int) -> bool:
	return sees_player(reach)


## True if this event sees the player within `reach` cells ahead, in a band
## `side` cells wide on each side; then Studio's appearance common event
## starts (`player_spotted_rect?`).
func player_spotted_rect(reach: int, side: int) -> bool:
	var seen := sees_player(reach, side)
	if seen:
		start_common(APPEARANCE)
	return seen


func trainer_spotted_rect(reach: int, side: int) -> bool:
	return player_spotted_rect(reach, side)


## `player_spotted_directional?(up: 3, down: 4…)`: the reach of this event's
## facing, else the others' in Studio's order, else 1.
func player_spotted_directional(reaches: Dictionary) -> bool:
	if this == null:
		return false
	var orders := {Vector2i.DOWN: [&"down", &"up", &"left", &"right"], Vector2i.UP: [&"up", &"down", &"left", &"right"],
		Vector2i.LEFT: [&"left", &"right", &"up", &"down"], Vector2i.RIGHT: [&"right", &"left", &"up", &"down"]}
	for key: StringName in orders.get(this.facing, []):
		if reaches.has(key) or reaches.has(String(key)):
			return sees_player(int(reaches.get(key, reaches.get(String(key)))))
	return sees_player(1)


## True if the player is on the line `direction` (`&"right"` or 6…) from
## this event, at most `reach` cells.
func detect_player(reach: int, direction: Variant) -> bool:
	var number: int = NAMED_DIRECTIONS.get(StringName(direction), 8) if direction is String or direction is StringName else int(direction)
	return player_in_line(reach, _StudioCharacter.DIRECTIONS.get(number, Vector2i.UP))


func detect_player_rect(across: int, along: int) -> bool:
	return player_in_rect(Vector2i(across, along))


func detect_player_circle(distance_squared: int) -> bool:
	return player_in_circle(distance_squared)


## Removes this event for good.
func delete_this_event_forever() -> void:
	erase_forever()


## Removes event `event_id` for good; false if the map has none.
func delete_event_forever(event_id: int) -> bool:
	var event := character(event_id) as WgEvent
	if event == null:
		return false
	erase_forever(event)
	return true


func delete_event(event_id: int) -> bool:
	return delete_event_forever(event_id)


## Plays species `id`'s cry (`options`: `volume`, `tempo`, `form`, as Studio's
## keyword arguments).
func cry_pokemon(id: Variant, options := {}) -> void:
	var audio: Object = _events().get(&"audio")
	if audio == null:
		return
	audio.call(&"cry", StringName(str(id)), int(_option(options, "form", 0)), float(_option(options, "volume", 100)) / 100.0)


## A keyword argument of Studio's, given as a String or a StringName key.
static func _option(options: Dictionary, key: String, default: Variant) -> Variant:
	return options.get(key, options.get(StringName(key), default))


## The engine's map Studio numbers `map_id`: empty for 0, or if the map
## config's numbers have none (logged).
func _map_named(map_id: int) -> StringName:
	if map_id == 0:
		return &""
	var named: StringName = _events().get(&"maps").call(&"map_of_number", map_id)
	if named.is_empty():
		_events().get(&"log").error(&"events", "no map numbered %d: give it in the map config's numbers" % map_id)
	return named
