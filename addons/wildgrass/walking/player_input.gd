## Drives its walker from the input actions of `movement_config.json`: tap to
## turn, hold to walk, the last direction pressed wins, run while held.
class_name WgPlayerInput
extends WgWalkerController

const DIRECTIONS: Dictionary[String, Vector2i] = {
	"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT,
}

## Directions held, in the order they were pressed.
var _held: Array[Vector2i] = []
## The direction acted on; zero at a standstill.
var _active := Vector2i.ZERO
var _held_for := 0.0
## Ignored until released: the way back through the door just used.
var _blocked := Vector2i.ZERO
var _walker: WgWalker


func _drive(walker: WgWalker, delta: float) -> void:
	_listen(walker)
	var walkers := walker.walkers
	for action_key: String in DIRECTIONS:
		var direction := DIRECTIONS[action_key]
		if walkers.is_held(action_key):
			if direction not in _held:
				_held.append(direction)
		else:
			_held.erase(direction)
	if _blocked != Vector2i.ZERO and _blocked not in _held:
		_blocked = Vector2i.ZERO
	var wanted := Vector2i.ZERO
	for index in range(_held.size() - 1, -1, -1):
		if _held[index] != _blocked:
			wanted = _held[index]
			break
	if wanted == Vector2i.ZERO or walkers.maps.is_changing or not walkers.screens.stack().is_empty():
		_active = Vector2i.ZERO
		_held_for = 0.0
		return
	var hold := walkers.movement().hold_seconds
	if wanted != _active:
		if _active == Vector2i.ZERO or _held_for < hold:
			walker.turn(wanted)
		if _active == Vector2i.ZERO:
			_held_for = 0.0
		_active = wanted
	_held_for += delta
	if _held_for >= hold:
		walker.step(_active, walkers.is_held("run"))


func _listen(walker: WgWalker) -> void:
	if _walker == walker:
		return
	_walker = walker
	walker.walkers.maps.traveller_arrived.connect(_on_traveller_arrived)


func _on_traveller_arrived(direction: Vector2i, point: Node2D) -> void:
	if _walker.walkers.maps.traveller != _walker or not point is WgDoor:
		return
	_blocked = -direction
	if _active == _blocked:
		_active = Vector2i.ZERO
		_held_for = 0.0
