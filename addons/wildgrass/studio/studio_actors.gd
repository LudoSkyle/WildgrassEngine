## The party as Studio's scripts see it (`$actors`, feature 23): each
## Pokémon as Studio's view of it. The Studio layer's; nothing of the engine
## depends on it.
extends RefCounted

const _StudioPokemon := preload("res://addons/wildgrass/studio/studio_pokemon.gd")

var _party: WeakRef
var _texts: WeakRef


func _init(party: Object, texts: Object) -> void:
	_party = weakref(party)
	_texts = weakref(texts)


## `$actors[index]`: counted from the end below 0; null past it.
func at(index: int) -> _StudioPokemon:
	var party: Object = _party.get_ref()
	if party == null:
		return null
	var found: WgPokemon = party.call(&"at", index + int(party.call(&"size")) if index < 0 else index)
	return _StudioPokemon.new(found, _texts.get_ref()) if found != null else null


## `$actors.empty?`.
func empty() -> bool:
	return size() == 0


func size() -> int:
	var party: Object = _party.get_ref()
	return int(party.call(&"size")) if party != null else 0


## Each one, as Studio's view of it.
func all() -> Array[_StudioPokemon]:
	var found: Array[_StudioPokemon] = []
	for index in size():
		found.append(at(index))
	return found


## `$actors.any? { |pokemon| … }`: `test` given each one.
func any(test: Callable) -> bool:
	return all().any(test)


## The first `test` accepts; null if none.
func find(test: Callable) -> _StudioPokemon:
	for pokemon in all():
		if test.call(pokemon):
			return pokemon
	return null


## The index of the first `test` accepts; -1 if none.
func index(test: Callable) -> int:
	var listed := all()
	for at_index in listed.size():
		if test.call(listed[at_index]):
			return at_index
	return -1


## How many `test` accepts; all with none.
func count(test := Callable()) -> int:
	return all().filter(test).size() if test.is_valid() else size()
