## The player as a trainer, as the reference keeps them: a boy's and a
## girl's identity, the one played giving the name and the id. Drawn at a
## new game, kept by the save. `{player}` in a text says the name.
extends RefCounted

const _Log := preload("res://addons/wildgrass/core/log/log.gd")
const _Texts := preload("res://addons/wildgrass/texts/texts.gd")

## The boy's id is drawn below this.
const ID_RANGE := 0x3FFFFFFF
## The girl's id is the boy's xor this.
const GIRL_ID_MASK := 0x28F4AB4C
## What `shown_id()` keeps.
const SHOWN_ID_MODULO := 100000

## True when the girl is played.
var girl := false
var boy_name := ""
var girl_name := ""
var boy_id := 0
## Draws the id; seeded by a test.
var random := RandomNumberGenerator.new()

var _texts: _Texts


func _init(_logger: _Log, texts: _Texts) -> void:
	_texts = texts
	texts.set_value(&"player", _player_text)


## The name of the one played.
var name: String:
	get:
		return girl_name if girl else boy_name
	set(value):
		if girl:
			girl_name = value
		else:
			boy_name = value


## The id of the one played.
var id: int:
	get:
		return (boy_id ^ GIRL_ID_MASK) if girl else boy_id


## The id as a trainer card shows it.
func shown_id() -> int:
	return id % SHOWN_ID_MODULO


func state() -> Dictionary:
	return {"girl": girl, "boy_name": boy_name, "girl_name": girl_name, "boy_id": boy_id}


func restore(saved: Dictionary) -> void:
	girl = bool(saved.get("girl", false))
	boy_name = str(saved.get("boy_name", ""))
	girl_name = str(saved.get("girl_name", ""))
	boy_id = int(saved.get("boy_id", 0))


func _player_text() -> String:
	return name


## A new trainer: a boy, the default names in the language shown, an id
## drawn.
func reset() -> void:
	girl = false
	boy_name = _texts.label("wg.trainer.boy")
	girl_name = _texts.label("wg.trainer.girl")
	boy_id = random.randi_range(0, ID_RANGE - 1)
