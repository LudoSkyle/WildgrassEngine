## The party's words as Studio's scripts call them (`$pokemon_party`,
## feature 23). The Studio layer's; nothing of the engine depends on it.
extends RefCounted

var _party: WeakRef


func _init(party: Object) -> void:
	_party = weakref(party)


## Each one's HP, status and PP restored.
func heal_party() -> void:
	var party: Object = _party.get_ref()
	if party != null:
		party.call(&"heal")


## How many are alive among the first `among` (all with -1).
func pokemon_alive(among := -1) -> int:
	var party: Object = _party.get_ref()
	return int(party.call(&"alive_count", among)) if party != null else 0


func size() -> int:
	var party: Object = _party.get_ref()
	return int(party.call(&"size")) if party != null else 0


func empty() -> bool:
	return size() == 0


func full() -> bool:
	var party: Object = _party.get_ref()
	return party != null and bool(party.call(&"is_full"))
