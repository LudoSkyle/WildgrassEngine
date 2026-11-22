## The line of followers behind the traveller: people first, in the order
## added, then the Pokémon. Each follows the one before it, the first the
## traveller. The line never goes with a map.
extends RefCounted

const Log := preload("res://addons/wildgrass/core/log/log.gd")
const Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")
const Maps := preload("res://addons/wildgrass/maps/maps.gd")
const Walkers := preload("res://addons/wildgrass/walking/walkers.gd")

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
var log: Log
var hooks: Hooks
var maps: Maps
var walkers: Walkers

var _people: Array[WgFollower] = []
## The Pokémon, if one follows: none or one.
var _pokemon: Array[WgFollower] = []


func _init(logger: Log, hook_registry: Hooks, maps_service: Maps, walkers_service: Walkers) -> void:
	log = logger
	hooks = hook_registry
	maps = maps_service
	walkers = walkers_service
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
