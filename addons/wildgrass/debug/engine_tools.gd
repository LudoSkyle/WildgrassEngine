## The engine's debug tools, on the `engine` page: what works in every game.
## Settings forced here (hour, weather, speed, walls, encounters) last until
## changed or the game quits, and are never saved.
extends RefCounted

const _Debug := preload("res://addons/wildgrass/debug/debug.gd")

## The pages and tools, in order.
const PAGE := _Debug.ENGINE

## Walking through walls runs after every other `can_step` hook.
const WALLS_PRIORITY := 1000

## Walking through tiles and characters, for the traveller.
var through_walls := false

var _debug: _Debug
var _s := {}


## Adds the engine's tools to `debug`, with `services` by name: texts,
## dialogue, bag, items, quests, maps, daytime, weather, pokedex, species,
## clock, encounters, followers, save, hooks, screens.
func _init(debug: _Debug, services: Dictionary) -> void:
	_debug = debug
	_s = services
	var hooks: Object = _s.get("hooks")
	if hooks != null:
		hooks.add(&"can_step", &"wildgrass_debug_walls", _walk_through, WALLS_PRIORITY)
	_tool(&"fill_bag", "wg.debug.fill_bag", fill_bag)
	debug.add_page(&"quests", "wg.debug.quests", {"page": PAGE, "lines": quest_lines, "shown": _has_quests})
	_tool(&"hour", hour_label, next_hour)
	_tool(&"weather", weather_label, next_weather)
	_tool(&"species", "wg.debug.species", show_species, {"shown": _has_species})
	_tool(&"fill_pokedex", "wg.debug.fill_pokedex", fill_pokedex)
	_tool(&"speed", speed_label, next_speed)
	_tool(&"empty_bag", "wg.debug.empty_bag", empty_bag)
	_tool(&"empty_pokedex", "wg.debug.empty_pokedex", empty_pokedex)
	debug.add_page(&"warp", "wg.debug.warp", {"page": PAGE, "lines": map_lines})
	_tool(&"reload", "wg.debug.reload", reload_map, {"shown": _has_map})
	_tool(&"walls", walls_label, toggle_walls)
	_tool(&"encounters", encounters_label, next_encounters)
	_tool(&"followers", followers_label, toggle_followers)
	_tool(&"save_here", "wg.debug.save_here", save_here, {"shown": _has_map})


func _tool(id: StringName, label: Variant, action: Callable, options := {}) -> void:
	options["page"] = PAGE
	_debug.add_tool(id, label, action, options)


func _label(text: String, values := {}) -> String:
	return _s["texts"].label(text, values)


func _say(text: String, values := {}) -> void:
	var dialogue: Object = _s["dialogue"]
	var said := _label(text, values)
	_debug.then(func() -> void: await dialogue.say(said))


## Every item but those of pockets that reveal (key items): 3 of the first,
## 4 of the next…, up to the bag's limit.
func fill_bag() -> bool:
	var items: Object = _s["items"]
	var bag: Object = _s["bag"]
	var config: WgBagConfig = bag.config()
	var count := 3
	for id: StringName in items.ids():
		var item: WgItem = items.item(id)
		if item == null or bool(config.pocket(item.pocket).get("reveal", false)):
			continue
		bag.add(id, mini(count, config.max_count))
		count += 1
	_say("wg.debug.bag_filled")
	return false


func empty_bag() -> bool:
	var bag: Object = _s["bag"]
	for pocket: Dictionary in bag.config().pockets:
		for id: StringName in bag.items(StringName(str(pocket.get("id", "")))):
			bag.remove(id, bag.count(id))
	_say("wg.debug.bag_emptied")
	return false


## A line per quest known, each leading to its three actions.
func quest_lines() -> Array:
	var quests: Object = _s["quests"]
	var found := []
	for id: StringName in quests.ids():
		var quest: WgQuest = quests.quest(id)
		var name := quest.name if not quest.name.is_empty() else str(id)
		found.append({"label": _label(name), "lines": _quest_actions.bind(id, name)})
	return found


func _quest_actions(id: StringName, name: String) -> Array:
	return [
		{"label": _label("wg.debug.quest_start_over"), "action": start_over.bind(id, name)},
		{"label": _label("wg.debug.quest_next"), "action": next_objective.bind(id, name)},
		{"label": _label("wg.debug.quest_finish"), "action": finish_quest.bind(id, name)},
	]


func start_over(id: StringName, name: String) -> bool:
	if _s["quests"].forget(id):
		_say("wg.debug.quest_started_over", {"quest": _label(name)})
		_reload_after()
	else:
		_say("wg.debug.quest_not_started", {"quest": _label(name)})
	return false


func next_objective(id: StringName, name: String) -> bool:
	return _advance(id, name, false)


func finish_quest(id: StringName, name: String) -> bool:
	return _advance(id, name, true)


## Completes the first objective not done, or all, starting the quest if it
## was not.
func _advance(id: StringName, name: String, all: bool) -> bool:
	var quests: Object = _s["quests"]
	if quests.is_finished(id):
		_say("wg.debug.quest_already_done", {"quest": _label(name)})
		return false
	if not quests.is_active(id):
		quests.start(id)
	var quest: WgQuest = quests.quest(id)
	for index in quest.objectives.size():
		if quests.is_done(id, index):
			continue
		quests.reveal(id, index)
		quests.complete(id, index)
		if not all:
			break
	if quests.is_finished(id):
		_say("wg.debug.quest_finished", {"quest": _label(name)})
	else:
		_say("wg.debug.quest_advanced", {"quest": _label(name)})
	_reload_after()
	return false


func _reload_after() -> void:
	var maps: Object = _s["maps"]
	_debug.then(func() -> void:
		if maps.current != null:
			await maps.reload(&"fade"))


func _has_quests() -> bool:
	return not _s["quests"].ids().is_empty()


func hour_label() -> String:
	var at := _hour_index()
	if at < 0:
		return _label("wg.debug.hour_real")
	return _label("wg.debug.hour", {"moment": _label("wg.debug.moment." + str(_hours()[at][0]))})


## The next hour of the config's, then the real one again.
func next_hour() -> bool:
	var hours := _hours()
	var at := _hour_index() + 1
	_s["daytime"].forced_hour = float(hours[at][1]) if at < hours.size() else -1.0
	return true


func _hours() -> Array:
	return _debug.config().hours


func _hour_index() -> int:
	var forced: float = _s["daytime"].forced_hour
	if forced < 0.0:
		return -1
	var hours := _hours()
	for index in hours.size():
		if is_equal_approx(float(hours[index][1]), forced):
			return index
	return -1


## The current weather; the map's own too when it has one, which shows
## instead.
func weather_label() -> String:
	var weather: Object = _s["weather"]
	var shown := _label("wg.debug.weather", {"name": _weather_name(weather.current)})
	if weather.shown() != weather.current:
		shown += " " + _label("wg.debug.weather_here", {"name": _weather_name(weather.shown())})
	return shown


func _weather_name(id: StringName) -> String:
	var found: WgWeather = _s["weather"].find(id)
	return _label(found.name) if found != null and not found.name.is_empty() else str(id)


func next_weather() -> bool:
	_s["weather"].cycle()
	return true


## In the dex shown: one species in three caught, the next seen, the next
## left unknown.
## The species view, over the tools, until it closes.
func show_species() -> bool:
	var opened: WgScreen = _s["screens"].open(&"species_view", {"species": _s["species"], "texts": _s["texts"], "dialogue": _s["dialogue"]})
	if opened != null and not opened.is_closed():
		await opened.closed
	return true


func _has_species() -> bool:
	return not _s["species"].ids().is_empty()


func fill_pokedex() -> bool:
	var pokedex: Object = _s["pokedex"]
	var entries: Array = pokedex.entries()
	for index in entries.size():
		var entry: Dictionary = entries[index]
		match index % 3:
			0:
				pokedex.catch(entry["species"], entry["form"])
			1:
				pokedex.see(entry["species"], entry["form"])
	_say("wg.debug.pokedex_filled")
	return false


func empty_pokedex() -> bool:
	var pokedex: Object = _s["pokedex"]
	for id: StringName in _s["species"].ids():
		if pokedex.is_seen(id):
			pokedex.forget(id)
	_say("wg.debug.pokedex_emptied")
	return false


func speed_label() -> String:
	return _label("wg.debug.speed", {"speed": _number(_s["clock"].speed)})


## The next speed of the config's after the one on.
func next_speed() -> bool:
	var speeds: Array = _debug.config().speeds
	var at := -1
	for index in speeds.size():
		if is_equal_approx(float(speeds[index]), _s["clock"].speed):
			at = index
	_s["clock"].speed = float(speeds[(at + 1) % speeds.size()])
	return true


## A line per map of the maps folder, warping to its first spawn point.
func map_lines() -> Array:
	var found := []
	for id: StringName in _map_ids():
		found.append({"label": str(id), "action": warp_to.bind(id)})
	return found


func warp_to(id: StringName) -> bool:
	var maps: Object = _s["maps"]
	_debug.then(func() -> void: await maps.warp(id, &"", &"fade"))
	return false


func _map_ids() -> Array[StringName]:
	var found: Array[StringName] = []
	var folder: String = _s["maps"].maps_folder()
	if folder.is_empty() or not DirAccess.dir_exists_absolute(folder):
		return found
	var files := DirAccess.get_files_at(folder)
	files.sort()
	for file in files:
		var name := file.trim_suffix(".remap")
		if name.ends_with(".tscn") and StringName(name.get_basename()) not in found:
			found.append(StringName(name.get_basename()))
	return found


func reload_map() -> bool:
	_reload_after()
	return false


func _has_map() -> bool:
	return _s["maps"].current != null


func walls_label() -> String:
	return _label("wg.debug.walls_on") if through_walls else _label("wg.debug.walls_off")


func toggle_walls() -> bool:
	through_walls = not through_walls
	return true


## The `can_step` hook, after the walkers' own: the traveller goes anywhere
## while walking through walls.
func _walk_through(allowed: bool, _cell: Vector2i, _direction: Vector2i, _level: int, walker: Node) -> bool:
	return true if through_walls and walker != null and walker == _s["maps"].traveller else allowed


func encounters_label() -> String:
	match int(_s["encounters"].forced):
		1:
			return _label("wg.debug.encounters_always")
		0:
			return _label("wg.debug.encounters_never")
	return _label("wg.debug.encounters_chance")


## Chance, always, never, chance.
func next_encounters() -> bool:
	var encounters: Object = _s["encounters"]
	match int(encounters.forced):
		1:
			encounters.forced = 0
		0:
			encounters.forced = -1
		_:
			encounters.forced = 1
	return true


func followers_label() -> String:
	return _label("wg.debug.followers_on") if _s["followers"].enabled else _label("wg.debug.followers_off")


func toggle_followers() -> bool:
	_s["followers"].enabled = not _s["followers"].enabled
	return true


## Writes the game in its slot, or the first free one, even where saving is
## off.
func save_here() -> bool:
	if _s["save"].write():
		_say("wg.save.saved")
	else:
		_say("wg.save.failed")
	return false


static func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else str(value)
