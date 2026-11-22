## A walker in line behind another: it replays its leader's steps, one
## behind, through anything. The followers service sets its leader.
class_name WgFollower
extends WgWalker

## Who it follows: the traveller, or the follower before it in the line.
var leader: WgWalker:
	set(value):
		if leader == value:
			return
		if is_instance_valid(leader) and leader.step_started.is_connected(_on_leader_step):
			leader.step_started.disconnect(_on_leader_step)
		leader = value
		_last = {}
		if leader != null:
			leader.step_started.connect(_on_leader_step)
			process_priority = leader.process_priority + 1

## The leader's last step: {from, to, level, direction, run, jump, slide}.
var _last := {}
## The leader's step its replay keeps pace with.
var _cue := -1
## Its own step that replays the leader's: another step (a script's) is no
## replay.
var _replay_step := -1
var _replaying := false
var _sliding_replay := false


func _init() -> void:
	through = true


## Moves on with its leader: a replay keeps exactly to the leader's step.
func advance(delta: float) -> void:
	_replaying = _replaying and is_moving and step_count == _replay_step
	if _replaying:
		if is_instance_valid(leader) and leader.is_moving and leader.step_count == _cue:
			delta = maxf(0.0, (leader.step_progress - _progress) * _length / _pace)
		else:
			delta = maxf(delta, (1.0 - _progress) * _length / _pace)
	super.advance(delta)
	_replaying = _replaying and is_moving and step_count == _replay_step
	if not is_moving:
		_keep_in_place()


## Ends its step where it goes and shows: out of the line.
func stop() -> void:
	if is_moving:
		_progress = 1.0
		_move(0.0)
	_replaying = false
	show()


## Puts it on `at` hidden, where it shows once its leader steps off.
func wait_at(at: Vector2i, on_level: int, direction: Vector2i) -> void:
	_replaying = false
	_last = {}
	place_at(at, on_level, direction)
	hide()


func _on_leader_step(from: Vector2i, to: Vector2i) -> void:
	var previous := _last
	_last = {
		"from": from, "to": to, "level": leader.destination_level, "direction": leader.heading,
		"run": leader.is_running, "jump": leader.is_jumping, "slide": leader._legs_still(),
	}
	if not is_inside_tree() or walkers.is_scripted(self):
		return
	if is_moving:
		_progress = 1.0
		_move(0.0)
	if _cell == from:
		show()
		return
	if visible and previous.get("to") == from and previous.get("from") == _cell:
		_replay(previous, leader.step_seconds)
		return
	# Out of place: it goes where its leader steps off, as on arrival.
	place_at(from, leader.level, leader.facing)
	show()


## Starts the step `step` of its leader, lasting `seconds`.
func _replay(step: Dictionary, seconds: float) -> void:
	var to: Vector2i = step["to"]
	var direction: Vector2i = step["direction"]
	var tiles := walkers.tiles
	_face(direction)
	is_moving = true
	step_count += 1
	_entered = false
	walkers.walker_left.emit(self, _cell, direction, step["run"])
	is_jumping = step["jump"]
	is_running = step["run"]
	_sliding_replay = step["slide"]
	_length = maxi(1, absi(to.x - _cell.x) + absi(to.y - _cell.y))
	_pace = _length / maxf(seconds, 0.001)
	_progress = 0.0
	_heading = direction
	_from = tiles.center_of(_cell)
	_to = tiles.center_of(to)
	_to_cell = to
	_to_level = step["level"]
	walkers.hold(self, to, _to_level)
	if is_jumping and _shadow != null:
		_shadow.show()
	_replaying = true
	_replay_step = step_count
	_cue = leader.step_count
	step_started.emit(_cell, to)


## Standing still beside its leader standing still, it faces it; elsewhere,
## out of place, it waits on its leader's cell.
func _keep_in_place() -> void:
	if not is_instance_valid(leader) or leader.is_moving or not is_inside_tree() or walkers.is_scripted(self):
		return
	var at := leader.cell
	if _cell == at:
		# Waiting there: on its leader's level, as a loaded game puts it.
		if not visible and level != leader.level:
			place_at(at, leader.level, leader.facing)
		return
	if not (_last.get("to") == at and _last.get("from") == _cell):
		wait_at(at, leader.level, leader.facing)
		return
	if visible:
		turn_toward(leader)


func _legs_still() -> bool:
	return is_sliding or (_replaying and _sliding_replay)
