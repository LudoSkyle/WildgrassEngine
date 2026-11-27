## Studio's words for events' scripts (feature 22): the names Studio's Ruby
## scripts call, doing what they do in Studio, on the engine's services. A
## script translated from Ruby (by the importer or by hand) is written with
## them. The Studio layer's: a project uses it through the setting
## `wildgrass/events/script_context`; nothing of the engine depends on it.
extends WgScriptContext

const _StudioCharacter := preload("res://addons/wildgrass/studio/studio_character.gd")
const _StudioText := preload("res://addons/wildgrass/studio/studio_text.gd")
const _StudioPokemon := preload("res://addons/wildgrass/studio/studio_pokemon.gd")
const _StudioActors := preload("res://addons/wildgrass/studio/studio_actors.gd")
const _StudioParty := preload("res://addons/wildgrass/studio/studio_party.gd")
const _StudioMap := preload("res://addons/wildgrass/studio/studio_map.gd")
const _StudioFollowMe := preload("res://addons/wildgrass/studio/studio_follow_me.gd")

## Studio's common event shown as a trainer appears (a player seen in a band).
const APPEARANCE := 2
## Studio's switch on when a Pokémon given went to the PC, off when it
## joined the party.
const STORED_SWITCH := 9
## Studio's order of the stats in a Pokémon's hash (`stats`, `bonus`).
const HASH_STATS: Array[StringName] = [&"hp", &"attack", &"defense", &"speed", &"special_attack", &"special_defense"]
## Studio's order of the contest conditions in a Pokémon's hash.
const HASH_CONDITIONS: Array[StringName] = [&"cool", &"beautiful", &"cute", &"clever", &"tough", &"sheen"]
## A Pokémon's hash's keys read as they are: Studio's key, the option's.
const HASH_OPTIONS: Dictionary[String, String] = {
	"given_name": "nickname", "captured_at": "caught_at", "captured_level": "caught_level", "trainer_name": "trainer_name",
	"trainer_id": "trainer_id", "gender": "gender", "nature": "nature", "item": "held_item", "ability": "ability",
	"loyalty": "friendship",
}
## A text naming a line of Studio's files, as Studio reads it: `19, 168 …`.
const TEXT_REFERENCE := "^([0-9]+),( |)([0-9]+)"
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


## The map's view, as Studio's scripts nudge it (`gm`, `$game_map`).
var gm: _StudioMap:
	get:
		return _StudioMap.new(_events())
## The followers' line, as Studio's scripts turn it off and back.
var follow_me: _StudioFollowMe:
	get:
		return _StudioFollowMe.new(_events())
## The party, as Studio's scripts see it (`$actors`).
var actors: _StudioActors:
	get:
		return _StudioActors.new(party, _events().get(&"texts"))
## The party's words, as Studio's scripts call them (`$pokemon_party`).
var pokemon_party: _StudioParty:
	get:
		return _StudioParty.new(party)


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


## A Pokémon made from Studio's hash (`PFM::Pokemon.generate_from_hash`):
## `id` (a symbol or a national number), `level`, `shiny`, `no_shiny`,
## `form`, and the keys the design lists; null if its species is unknown.
func pokemon_from_hash(hash: Dictionary) -> _StudioPokemon:
	var made := _make(_option(hash, "id", null), int(_option(hash, "level", 0)), _hash_options(hash))
	return _StudioPokemon.new(made, _events().get(&"texts")) if made != null else null


## Adds a Pokémon to the party: one given, else species `pokemon_or_id` at
## `level`, `shiny` true always, 0 never, n one chance in n, false by the
## draws. Null, logged, if it cannot be made or the party is full (no PC
## yet).
func add_pokemon(pokemon_or_id: Variant, level := 5, shiny: Variant = false) -> _StudioPokemon:
	var given := _StudioPokemon.engine_of(pokemon_or_id)
	if given == null:
		var maker: Object = _events().get(&"pokemon")
		if level < 1 or maker == null or level > int(maker.get(&"level_limit")):
			_events().get(&"log").error(&"events", "add_pokemon: level %d is out of bounds" % level)
			return null
		var options := {}
		if shiny is bool and shiny:
			options["shiny"] = true
		elif shiny is int and shiny == 0:
			options["shiny"] = false
		elif shiny is int and shiny > 0 and int(maker.call(&"draw", 0, shiny - 1)) == 0:
			options["shiny"] = true
		given = _make(pokemon_or_id, level, options)
	if given == null or party == null or not bool(party.call(&"add", given)):
		return null
	set_gs(STORED_SWITCH, false)
	return _StudioPokemon.new(given, _events().get(&"texts"))


## Adds the Pokémon Studio's hash describes (see `pokemon_from_hash`).
func add_specific_pokemon(hash: Dictionary) -> _StudioPokemon:
	var made := pokemon_from_hash(hash)
	return add_pokemon(made) if made != null else null


## Adds a Pokémon as `add_pokemon`, then would show the naming screen: not
## handled yet, logged once.
func add_rename_pokemon(pokemon_or_id: Variant, level := 5, shiny: Variant = false, _letters := 12) -> _StudioPokemon:
	var added := add_pokemon(pokemon_or_id, level, shiny)
	if added != null:
		_unsupported("the naming screen (add_rename_pokemon)")
	return added


## The next message asks `choices` (texts, one after another or as a list;
## `"19, 168 Morning"` is line 168 of Studio's file 19, as Studio reads it);
## the one taken, from 1, goes into variable `variable_id`. `cancel_type`:
## the choice cancelling takes, from 1; -1 or 0: not allowed.
func choice(variable_id: int, cancel_type: int, ...choices: Array) -> void:
	var listed: Array = choices[0] if choices.size() == 1 and choices[0] is Array else choices
	var shown := listed.map(func(text: Variant) -> String: return _studio_text(str(text)))
	next_message_asks(shown, func(answer: int) -> void: set_gv(variable_id, answer + 1), cancel_type - 1 if cancel_type > 0 else -1)


## Line `line` of Studio's text file `file`, in the language shown: the key
## `dialogs.<file>.<line>` an imported game has, else Studio's text itself.
func ext_text(file: int, line: int) -> String:
	var texts: Object = _events().get(&"texts")
	if texts == null:
		return ""
	var key := "dialogs.%d.%d" % [file, line]
	var shown := str(texts.call(&"label", key))
	return shown if shown != key else str(texts.call(&"label", "{text:%d:%d}" % [file, line]))


## `text`, or the line of Studio's file it names (`"19, 168 …"`). Its
## colors (`\c[18]`) are left out: a script's own text has no palette
## (logged once).
func _studio_text(text: String) -> String:
	var found := RegEx.create_from_string(TEXT_REFERENCE).search(text)
	if found != null:
		return ext_text(found.get_string(1).to_int(), found.get_string(3).to_int())
	var plain := RegEx.create_from_string("\\\\[cC]\\[[0-9]+\\]").sub(text, "", true)
	if plain != text:
		_unsupported("Studio's colors in a script's text")
	return plain


## The engine's options from Studio's hash.
func _hash_options(hash: Dictionary) -> Dictionary:
	var options := {}
	for key: Variant in hash:
		var name := str(key)
		var value: Variant = hash[key]
		if value == null or name in ["id", "level"]:
			continue
		if HASH_OPTIONS.has(name):
			options[HASH_OPTIONS[name]] = value
			continue
		match name:
			"form":
				options["form"] = int(value)
			"shiny":
				if value:
					options["shiny"] = true
			"no_shiny":
				pass
			"captured_with", "ball":
				if name == "captured_with" or not _has_option(hash, "captured_with"):
					options["ball"] = value
			"stats", "bonus", "conditions":
				var order := HASH_CONDITIONS if name == "conditions" else HASH_STATS
				var by_name := {}
				for index in mini((value as Array).size() if value is Array else 0, order.size()):
					if value[index] != null:
						by_name[order[index]] = int(value[index])
				options[{"stats": "ivs", "bonus": "evs", "conditions": "conditions"}[name]] = by_name
			"moves":
				var moves := []
				for move: Variant in (value as Array if value is Array else []):
					if move is StringName and not move in [&"__undef__", &"__remove__"]:
						moves.append(move)
					else:
						if move is StringName and move == &"__remove__":
							_unsupported("a move removed by a Pokémon's hash (__remove__)")
						moves.append(null)
				options["moves"] = moves
			_:
				_unsupported("the key '%s' of a Pokémon's hash" % name)
	if _has_option(hash, "no_shiny") and _option(hash, "no_shiny", false):
		options["shiny"] = false
	return options


## A Pokémon of species `id` (a symbol or a national number); null, logged,
## if there is no such species.
func _make(id: Variant, level: int, options: Dictionary) -> WgPokemon:
	var maker: Object = _events().get(&"pokemon")
	var species: Object = _events().get(&"species")
	if maker == null or species == null:
		_unsupported("Pokémon (no party)")
		return null
	var found: WgSpecies = species.call(&"of_number", id) if id is int else species.call(&"find", StringName(str(id)))
	if found == null:
		_events().get(&"log").error(&"events", "no species '%s' to make" % id)
		return null
	return maker.call(&"make", found.id, level, options)


static func _has_option(options: Dictionary, key: String) -> bool:
	return options.has(key) or options.has(StringName(key))
