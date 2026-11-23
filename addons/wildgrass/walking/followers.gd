## The line of followers behind the traveller: people first, in the order
## added, then the Pokémon. Each follows the one before it, the first the
## traveller. The line never goes with a map.
extends RefCounted

const _Log := preload("res://addons/wildgrass/core/log/log.gd")
const _Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")
const _Maps := preload("res://addons/wildgrass/maps/maps.gd")
const _Walkers := preload("res://addons/wildgrass/walking/walkers.gd")
const _SpeciesData := preload("res://addons/wildgrass/pokemon/species_data.gd")

## A project setting naming the scene of the line's Pokémon.
const POKEMON_SCENE_SETTING := "wildgrass/followers/pokemon_scene"
## The engine's Pokémon walks at 6 frames a second: a drawing a third of a
## second.
const POKEMON_FPS := 6.0

## Someone joined or left the line.
signal line_changed

## The line, the first behind the traveller.
var line: Array[WgFollower]:
	get:
		var found: Array[WgFollower] = []
		for follower: Variant in _people + _pokemon:
			if is_instance_valid(follower):
				found.append(follower)
		return found
## False: no one follows.
var enabled := true:
	set(value):
		if enabled == value:
			return
		enabled = value
		_put_back()

@warning_ignore("shadowed_global_identifier")
var log: _Log
var hooks: _Hooks
var maps: _Maps
var walkers: _Walkers
var species: _SpeciesData
## The scene of the line's Pokémon, a WgFollower; empty: the engine's, made
## in code. The project setting `wildgrass/followers/pokemon_scene` sets it.
var pokemon_scene := ""
## The line's Pokémon, or null.
var pokemon: WgFollower:
	get:
		return _pokemon[0] if not _pokemon.is_empty() and is_instance_valid(_pokemon[0]) else null

var _people: Array[WgFollower] = []
## The Pokémon, if one follows: none or one.
var _pokemon: Array[WgFollower] = []


func _init(logger: _Log, hook_registry: _Hooks, maps_service: _Maps, walkers_service: _Walkers, species_data: _SpeciesData) -> void:
	log = logger
	hooks = hook_registry
	maps = maps_service
	walkers = walkers_service
	species = species_data
	pokemon_scene = str(ProjectSettings.get_setting(POKEMON_SCENE_SETTING, ""))
	hooks.add(&"map_leaving", &"wildgrass_followers", _on_map_leaving)
	maps.map_changed.connect(_on_map_changed)
	maps.cleared.connect(_take_out)


## Out of the tree (back at the title, off a map), nothing else would free
## the line. No method of this object can run here.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for follower: Variant in _people + _pokemon:
			if is_instance_valid(follower) and (follower as Node).get_parent() == null:
				(follower as Node).free()


## Puts `follower` in line, after the people already there, before the
## Pokémon. It waits on the traveller's cell, hidden; the others walk on.
func add(follower: WgFollower) -> void:
	if follower == null or line.has(follower):
		return
	_people.append(follower)
	_joined(follower)


## Takes `follower` out of the line and off the map, its step ended and
## shown; it is not freed. One freed leaves the line by itself.
func remove(follower: WgFollower) -> void:
	if follower == null or not line.has(follower):
		return
	_people.erase(follower)
	_pokemon.erase(follower)
	_leave(follower)
	_relink()
	line_changed.emit()


## Puts `species_id`'s Pokémon at the end of the line, in place of the one
## following; null, logged and nobody following for an unknown species or
## one with no `character` picture.
func follow_pokemon(species_id: StringName, form := 0, shiny := false, female := false) -> WgFollower:
	stop_pokemon()
	var species_form := species.form(species_id, form) if species.has(species_id) else null
	if species_form == null:
		log.error(&"followers", "no species '%s' to follow" % species_id)
		return null
	var follower := _make_pokemon()
	if follower == null:
		return null
	if not follower._dress(species_form, shiny, female):
		log.error(&"followers", "'%s' has no character picture to follow with" % species_id)
		follower.free()
		return null
	follower.species = species_id
	follower.form = species_form.form
	follower.shiny = shiny
	follower.female = female
	_pokemon.append(follower)
	_joined(follower)
	return follower


## No Pokémon follows any more.
func stop_pokemon() -> void:
	var following := pokemon
	_pokemon.clear()
	if following == null:
		return
	_leave(following)
	following.free()
	_relink()
	line_changed.emit()


## The scene of `pokemon_scene`, else the engine's: a WgFollower with a
## WgCharacterSprite, always stepping, leaving no prints in sand.
func _make_pokemon() -> WgFollower:
	if not pokemon_scene.is_empty():
		var packed := load(pokemon_scene) as PackedScene if ResourceLoader.exists(pokemon_scene) else null
		var made := packed.instantiate() if packed != null else null
		if made is WgFollower:
			return made
		if made != null:
			made.free()
		log.error(&"followers", "%s must be a scene whose root is a WgFollower, got '%s'" % [POKEMON_SCENE_SETTING, pokemon_scene])
		return null
	var follower := WgFollower.new()
	follower.name = "Pokemon"
	follower.always_stepping = true
	follower.prints = false
	var drawn := WgCharacterSprite.new()
	drawn.name = "Sprite"
	drawn.fps = POKEMON_FPS
	follower.add_child(drawn)
	return follower


## The `followers` part of a saved game: `enabled`, the Pokémon, and the
## people's scenes in order. Where they stand is not saved.
func state() -> Dictionary:
	var people: Array[String] = []
	for follower: Variant in _people:
		if not is_instance_valid(follower):
			continue
		var path := (follower as Node).scene_file_path
		if path.is_empty():
			log.warn(&"followers", "%s was made in code: it is not saved" % (follower as Node).name)
			continue
		people.append(path)
	var saved := {"enabled": enabled, "people": people}
	var following := pokemon
	if following != null:
		saved["pokemon"] = {"species": str(following.species), "form": following.form, "shiny": following.shiny, "female": following.female}
	return saved


## Puts back the line `state()` saw, on the traveller's cell, hidden.
func restore(saved: Dictionary) -> void:
	reset()
	enabled = bool(saved.get("enabled", true))
	var people: Variant = saved.get("people", [])
	if people is Array:
		for path: Variant in people:
			var packed := load(str(path)) as PackedScene if ResourceLoader.exists(str(path)) else null
			var made := packed.instantiate() if packed != null else null
			if made is WgFollower:
				add(made)
				continue
			if made != null:
				made.free()
			log.error(&"followers", "the saved follower '%s' is not a WgFollower scene" % path)
	var following: Variant = saved.get("pokemon")
	if following is Dictionary:
		follow_pokemon(StringName(str(following.get("species", ""))), int(following.get("form", 0)), bool(following.get("shiny", false)), bool(following.get("female", false)))


## A new game: no one follows, and following is on.
func reset() -> void:
	for follower: WgFollower in line:
		_leave(follower)
		follower.free()
	_people.clear()
	_pokemon.clear()
	enabled = true
	line_changed.emit()


func _joined(follower: WgFollower) -> void:
	if follower.walkers == null:
		follower.walkers = walkers
	follower.tree_exited.connect(_on_follower_exited)
	_put_back(false)
	line_changed.emit()


func _leave(follower: WgFollower) -> void:
	if follower.tree_exited.is_connected(_on_follower_exited):
		follower.tree_exited.disconnect(_on_follower_exited)
	follower.leader = null
	follower.stop()
	if follower.get_parent() != null:
		follower.get_parent().remove_child(follower)


## Each follower follows the one before it, the first the traveller.
func _relink() -> void:
	var ahead := maps.traveller as WgWalker
	for follower: WgFollower in line:
		follower.leader = ahead
		ahead = follower


## True if the line shows on the current map: enabled, a walker travelling,
## and the filter hook `followers_shown(shown, map)` agreeing.
func is_shown() -> bool:
	if not enabled or maps.current == null or not maps.traveller is WgWalker or maps.traveller.get_parent() == null:
		return false
	return bool(hooks.filter(&"followers_shown", true, [maps.current]))


## Puts the line back beside the traveller, on its cell, hidden; or off the
## map if it does not show there. `all` false: only those off the map.
func _put_back(all := true) -> void:
	_relink()
	if not is_shown():
		_take_out()
		return
	var traveller := maps.traveller as WgWalker
	var at := walkers.tiles.cell_of(traveller.global_position)
	var everyone := line
	everyone.reverse()
	for follower: WgFollower in everyone:
		var placed := follower.is_inside_tree()
		_beside(follower, traveller)
		if all or not placed:
			follower.wait_at(at, traveller.level, traveller.facing)


## Puts `follower` among the traveller's siblings, just before it, so the
## traveller draws over it on the same row. Called from the last follower to
## the first, the first draws over the next.
func _beside(follower: WgFollower, traveller: WgWalker) -> void:
	var parent := traveller.get_parent()
	if follower.get_parent() != parent:
		var at := follower.global_position
		if follower.get_parent() != null:
			follower.get_parent().remove_child(follower)
		parent.add_child(follower)
		follower.global_position = at
	var at_index := traveller.get_index()
	parent.move_child(follower, at_index - 1 if follower.get_index() < at_index else at_index)


func _take_out() -> void:
	for follower: WgFollower in line:
		if follower.get_parent() != null:
			follower.get_parent().remove_child(follower)


## A crossing carries the line on in step; a warp or a reload puts it back on
## the traveller's cell.
func _on_map_changed(_map: WgMap) -> void:
	if not maps.is_crossing:
		_put_back()
		return
	_relink()
	if not is_shown():
		_take_out()
		return
	var traveller := maps.traveller as WgWalker
	var at := walkers.tiles.cell_of(traveller.global_position)
	var all := line
	all.reverse()
	for follower: WgFollower in all:
		var placed := follower.is_inside_tree()
		_beside(follower, traveller)
		if not placed:
			follower.wait_at(at, traveller.level, traveller.facing)


## A follower left the tree: if it was freed, the line closes up once it is
## gone.
func _on_follower_exited() -> void:
	_close_up.call_deferred()


func _close_up() -> void:
	var before := _people.size() + _pokemon.size()
	_people.assign(_people.filter(func(follower: Variant) -> bool: return is_instance_valid(follower)))
	_pokemon.assign(_pokemon.filter(func(follower: Variant) -> bool: return is_instance_valid(follower)))
	if _people.size() + _pokemon.size() == before:
		return
	_relink()
	line_changed.emit()


## A map leaving takes no follower with it.
func _on_map_leaving(map: WgMap) -> void:
	for follower: WgFollower in line:
		if map.is_ancestor_of(follower):
			follower.get_parent().remove_child(follower)
