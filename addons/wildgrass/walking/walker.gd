## A character that walks cell by cell: the root of a character scene. Its
## origin is the centre of its cell.
class_name WgWalker
extends Node2D

const _Walkers := preload("res://addons/wildgrass/walking/walkers.gd")
## The z index of a walker drawn on top.
const ON_TOP_Z := 100
const DIRECTION_NAMES: Dictionary[Vector2i, String] = {
	Vector2i.DOWN: "down", Vector2i.UP: "up", Vector2i.LEFT: "left", Vector2i.RIGHT: "right",
}

## The walker now faces `direction`.
signal turned(direction: Vector2i)
## A step from cell `from` to cell `to` began.
signal step_started(from: Vector2i, to: Vector2i)
## A step ended on `cell`.
signal step_finished(cell: Vector2i)
## The walker started pushing against something in `direction`.
signal bumped(direction: Vector2i)

@export var facing := Vector2i.DOWN
## 0 is the ground; see the tiles' levels and bridges.
@export var level := 0
## The AnimatedSprite2D, if any.
@export var sprite: NodePath = ^"Sprite"
## Shown while jumping, if present.
@export var shadow: NodePath = ^"Shadow"
## Jumps ledges.
@export var jumps := true
## Slides on ice.
@export var slides := true
## Blocks no one, and no character blocks it.
@export var through := false
## Walking pace in cells per second; 0: the config's. Running keeps the
## config's.
@export var pace := 0.0
## Shows its reflection over water; off for a Pokémon flying.
@export var reflects := true
## Its ground line below its origin, in pixels: its feet, where water mirrors
## it.
@export var ground_offset := 8.0
## Leaves prints in sand.
@export var prints := true
## Rustles the tall grass it walks into.
@export var rustles := true
## Its walk plays all the time, standing too, at the same cadence whatever its
## pace, as Pokémon do on the map; still while it slides.
@export var always_stepping := false
## Goes through walls (any tile, edge or ledge) as long as there is a map,
## as RPG Maker's `through`; set `through` too to go through walkers.
@export var passes_walls := false
## Keeps its facing when it steps or turns (RPG Maker's direction fix).
@export var fixed_direction := false
## Moves its legs when it walks; else it glides.
@export var walk_animation := true
## Moves what it shows, its cell unchanged, in game pixels: a scene lifting
## it off the ground.
var look_offset := Vector2.ZERO:
	set(value):
		look_offset = value
		if is_node_ready():
			_lift()
## Moves its shadow, in game pixels.
var shadow_offset := Vector2.ZERO:
	set(value):
		shadow_offset = value
		if is_node_ready():
			_lift()
## False: its shadow never shows.
var shadow_shown := true:
	set(value):
		shadow_shown = value
		if is_node_ready():
			_lift()
## Drawn over the map's tiles and walkers.
@export var on_top := false:
	set(value):
		on_top = value
		z_index = ON_TOP_Z if value else level * 2

## The walkers service: the engine's, unless set before entering the tree.
var walkers: _Walkers
## Decides the next step: the first WgWalkerController child, unless set.
var controller: WgWalkerController
## The cell it stands in, or is stepping from.
var cell: Vector2i:
	get:
		return _cell
var is_moving := false
var is_running := false
var is_jumping := false
var is_sliding := false
## The cell it ends on: the one its step goes to, else its own.
var destination: Vector2i:
	get:
		return _to_cell if is_moving else _cell
## The direction of the step under way; zero at rest.
var heading: Vector2i:
	get:
		return _heading if is_moving else Vector2i.ZERO
## The level its step under way reaches; its own at rest.
var destination_level: int:
	get:
		return _to_level if is_moving else level
## How far its step under way has gone, 0 to 1; 0 at rest.
var step_progress: float:
	get:
		return _progress if is_moving else 0.0
## How long its step under way lasts, in seconds; 0 at rest.
var step_seconds: float:
	get:
		return _length / _pace if is_moving and _pace > 0.0 else 0.0
## Steps started since it was made.
var step_count := 0

var _cell := Vector2i.ZERO
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _to_cell := Vector2i.ZERO
var _to_level := 0
var _length := 1
var _progress := 0.0
var _pace := 0.0
var _heading := Vector2i.ZERO
var _pushing := false
var _pushed := false
## True once the step reached halfway into its last cell.
var _entered := false
var _turning := false
var _crossing := false
var _sprite: AnimatedSprite2D
var _shadow: CanvasItem
## The top of the jump under way, px; 0: the config's.
var _jump_height := 0.0
var _sprite_rest := Vector2.ZERO
var _shadow_rest := Vector2.ZERO


func _ready() -> void:
	if walkers == null:
		var engine := get_node_or_null(^"/root/Wildgrass")
		if engine != null:
			walkers = engine.get(&"walkers")
	if walkers == null:
		push_error("%s: no walkers service" % name)
		set_process(false)
		return
	_sprite = get_node_or_null(sprite) as AnimatedSprite2D
	if _sprite != null:
		_sprite_rest = _sprite.position
	_shadow = get_node_or_null(shadow) as CanvasItem
	if _shadow != null:
		_shadow.hide()
		if _shadow is Node2D:
			_shadow_rest = (_shadow as Node2D).position
	_lift()
	if controller == null:
		for child: Node in get_children():
			if child is WgWalkerController:
				controller = child
				break
	walkers.maps.traveller_arrived.connect(_on_traveller_arrived)
	walkers.maps.map_changed.connect(_on_map_changed)
	_settle()
	_animate()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and walkers != null:
		walkers.forget(self)


func _process(delta: float) -> void:
	advance(delta)


## Moves on by `delta` seconds: the step under way, then the next ones that a
## slide or the controller starts, with the time left.
func advance(delta: float) -> void:
	var left := delta
	for _round in 64:
		if not is_moving:
			if is_sliding:
				if not _start_step(_heading, _pace, false):
					is_sliding = false
			elif walkers.is_scripted(self):
				walkers.drive_script(self, left)
			elif controller != null and walkers.may_act(self):
				controller._drive(self, left)
			if not is_moving:
				break
		left = _move(left)
		if left <= 0.0:
			break
	# A scripted walk whose last step just ended ends now, not next frame.
	if not is_moving and walkers.is_scripted(self):
		walkers.drive_script(self, 0.0)
	_pushing = _pushed
	_pushed = false
	_animate()


## True while it keeps walking into something.
func is_pushing() -> bool:
	return _pushing or _pushed


## Turns in place, if not moving.
func turn(direction: Vector2i) -> void:
	if not _valid(direction) or is_moving:
		return
	if facing != direction:
		_turning = true
	_face(direction)


## Faces `target`'s cell, along the axis it is furthest on.
func turn_toward(target: Node2D) -> void:
	var offset := walkers.tiles.cell_of(target.global_position) - _cell
	if offset == Vector2i.ZERO:
		return
	turn(Vector2i(signi(offset.x), 0) if absi(offset.x) >= absi(offset.y) else Vector2i(0, signi(offset.y)))


## True if a step in `direction` would start now: free, or a ledge to jump.
func can_step(direction: Vector2i) -> bool:
	return walkers.tiles.can_step(_cell, direction, level, self) or (jumps and _can_jump(direction))


## Starts a step in `direction`, running or not, facing it unless `face` is
## false. A diagonal step goes where either way round the corner is free,
## facing to the side only when it faced the other side, as RPG Maker's.
## Returns false if refused: moving already, a warp under way, or something
## in the way (then `bumped`).
func step(direction: Vector2i, run := false, face := true) -> bool:
	if not _valid(direction, true) or is_moving or walkers.maps.is_changing:
		return false
	if face:
		_face(direction)
	if _is_traveller():
		var door := walkers.door_at(_cell)
		if door != null and door.kind == WgDoor.Kind.EXIT and door.direction == direction:
			walkers.maps.use(door)
			return true
	var config := walkers.movement()
	var base := config.run_pace if run else (pace if pace > 0.0 else config.walk_pace)
	var step_pace := float(walkers.hooks.filter(&"step_pace", base, [self, direction, run]))
	if _start_step(direction, step_pace, run):
		return true
	if _is_traveller() and walkers.events != null:
		walkers.events.call(&"touch_there", self, direction)
	if not _pushing and not _pushed:
		bumped.emit(direction)
	_pushed = true
	return false


func _start_step(direction: Vector2i, pace: float, run: bool) -> bool:
	var tiles := walkers.tiles
	var landing := _cell + direction
	var length := 1
	var next_level := level
	_jump_height = 0.0
	if passes_walls:
		if walkers.maps.map_at(tiles.center_of(landing)) == null:
			return false
	elif direction.x != 0 and direction.y != 0:
		var via := _diagonal_via(direction)
		if via == Vector2i.ZERO:
			return false
		next_level = tiles.level_after(_cell + via, direction - via, tiles.level_after(_cell, via, level))
	elif tiles.can_step(_cell, direction, level, self):
		next_level = tiles.level_after(_cell, direction, level)
	elif jumps and _can_jump(direction):
		landing += direction
		length = 2
		next_level = tiles.level_after(_cell + direction, direction, level)
		pace = walkers.movement().jump_pace
	else:
		return false
	is_moving = true
	step_count += 1
	_entered = false
	walkers.walker_left.emit(self, _cell, direction, run and length == 1)
	is_jumping = length == 2
	is_running = run and not is_jumping
	_length = length
	_pace = pace
	_progress = 0.0
	_heading = direction
	_from = tiles.center_of(_cell)
	_to = tiles.center_of(landing)
	_to_cell = landing
	_to_level = next_level
	walkers.hold(self, landing, next_level)
	if slides and tiles.data(landing, &"ice") == true:
		is_sliding = true
	if is_jumping and _shadow != null and shadow_shown:
		_shadow.show()
	step_started.emit(_cell, landing)
	return true


## A ledge in `direction`: a solid cell jumped that way, and room beyond it.
func _can_jump(direction: Vector2i) -> bool:
	var tiles := walkers.tiles
	var ledge := _cell + direction
	return tiles.data(ledge, &"jump") == direction \
		and tiles.is_solid(ledge, level) \
		and not tiles.has_edge(_cell, direction, level) \
		and tiles.can_step(ledge, direction, level, self)


## Moves the step on by `delta`; returns the time left once it ends, else 0.
func _move(delta: float) -> float:
	_progress += delta * _pace / _length
	if not _entered and _progress >= 1.0 - 0.5 / _length:
		_entered = true
		walkers.walker_entered.emit(self, _to_cell)
	if _progress < 1.0:
		global_position = _from.lerp(_to, _progress)
		_lift()
		return 0.0
	var left := (_progress - 1.0) * _length / _pace
	_finish_step()
	return left


func _finish_step() -> void:
	_cell = _to_cell
	level = _to_level
	z_index = ON_TOP_Z if on_top else level * 2
	global_position = _to
	is_moving = false
	is_jumping = false
	_lift()
	walkers.settle(self, _cell, level)
	if is_sliding and walkers.tiles.data(_cell, &"ice") != true:
		is_sliding = false
	step_finished.emit(_cell)
	if _is_traveller():
		_crossing = true
		walkers.maps.cross()
		_crossing = false
		var door := walkers.door_at(_cell)
		if door != null and door.kind == WgDoor.Kind.CONTACT:
			is_sliding = false
			walkers.maps.use(door)
		elif walkers.events != null and walkers.events.call(&"touch_here", self):
			is_sliding = false
		else:
			walkers.trigger_at(self)
			walkers.encounter_at(self)


## Puts the walker on `at` of the current map's grid, at once, on `on_level`,
## facing `direction` if not zero: a loaded game, a scene.
func place_at(at: Vector2i, on_level := level, direction := Vector2i.ZERO) -> void:
	level = on_level
	global_position = walkers.tiles.center_of(at)
	_settle()
	if direction != Vector2i.ZERO:
		_face(direction)


## Stops any step and takes the cell under the walker, at its centre.
func _settle() -> void:
	is_moving = false
	is_jumping = false
	is_sliding = false
	_lift()
	_cell = walkers.tiles.cell_of(global_position)
	global_position = walkers.tiles.center_of(_cell)
	z_index = ON_TOP_Z if on_top else level * 2
	walkers.settle(self, _cell, level)


func _on_traveller_arrived(direction: Vector2i, _point: Node2D) -> void:
	if not _is_traveller():
		return
	_settle()
	_face(direction)


func _on_map_changed(_map: WgMap) -> void:
	if _is_traveller() and not _crossing:
		_settle()


func _is_traveller() -> bool:
	return walkers.maps.traveller == self


## Jumps by `offset` cells, none for a hop in place, as RPG Maker's jump:
## it faces the way it jumps furthest, and lands on a cell it may stand on,
## else does not jump. `seconds` in the air, `height` px at the top (0: the
## config's). Returns false if it does not jump.
func jump_by(offset: Vector2i, seconds: float, height := 0.0) -> bool:
	if is_moving or walkers.maps.is_changing or seconds <= 0.0:
		return false
	var tiles := walkers.tiles
	var landing := _cell + offset
	if offset != Vector2i.ZERO:
		_face(Vector2i(signi(offset.x), 0) if absi(offset.x) > absi(offset.y) else Vector2i(0, signi(offset.y)))
		if walkers.maps.map_at(tiles.center_of(landing)) == null:
			return false
		if not passes_walls and tiles.is_solid(landing, level):
			return false
		var other := walkers.at(landing, level)
		if not through and other != null and other != self:
			return false
	is_moving = true
	is_jumping = true
	is_running = false
	step_count += 1
	_entered = false
	_length = 1
	_pace = 1.0 / seconds
	_progress = 0.0
	_jump_height = height
	_heading = Vector2i(signi(offset.x), signi(offset.y))
	_from = tiles.center_of(_cell)
	_to = tiles.center_of(landing)
	_to_cell = landing
	_to_level = level
	walkers.hold(self, landing, level)
	if _shadow != null and shadow_shown:
		_shadow.show()
	step_started.emit(_cell, landing)
	return true


func _face(direction: Vector2i) -> void:
	if fixed_direction:
		return
	var way := direction
	if way.x != 0 and way.y != 0:
		if facing == Vector2i(-way.x, 0):
			way = Vector2i(way.x, 0)
		elif facing == Vector2i(0, -way.y):
			way = Vector2i(0, way.y)
		else:
			return
	if facing == way:
		return
	facing = way
	turned.emit(way)


func _valid(direction: Vector2i, diagonal := false) -> bool:
	if DIRECTION_NAMES.has(direction) or (diagonal and absi(direction.x) == 1 and absi(direction.y) == 1):
		return true
	walkers.log.error(&"walking", ("%s is not a step to a cell around" if diagonal else "%s is not up, down, left or right") % direction)
	return false


## The first way round the corner of diagonal `direction` that is free (the
## vertical first, as RPG Maker's), or zero.
func _diagonal_via(direction: Vector2i) -> Vector2i:
	var tiles := walkers.tiles
	for via: Vector2i in [Vector2i(0, direction.y), Vector2i(direction.x, 0)]:
		var rest := direction - via
		if tiles.can_step(_cell, via, level, self) and tiles.can_step(_cell + via, rest, tiles.level_after(_cell, via, level), self):
			return via
	return Vector2i.ZERO


## Raises the sprite along the jump's arc; shows the shadow while in the air.
func _lift() -> void:
	if _sprite != null:
		var height := 0.0
		if is_jumping:
			height = (_jump_height if _jump_height > 0.0 else walkers.movement().jump_height) * 4.0 * _progress * (1.0 - _progress)
		_sprite.position = _sprite_rest + look_offset - Vector2(0.0, height)
	if _shadow != null:
		if _shadow is Node2D:
			(_shadow as Node2D).position = _shadow_rest + shadow_offset
		if not is_jumping or not shadow_shown:
			_shadow.hide()


func _animate() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var state := "idle"
	if is_jumping:
		state = "jump"
	elif is_moving and walk_animation:
		state = "run" if is_running else "walk"
	elif _pushing:
		state = "walk"
	elif _turning:
		state = "turn"
	if always_stepping and state != "jump":
		_turning = false
		state = "walk"
	state = str(walkers.hooks.filter(&"walker_animation", state, [self]))
	var suffix := "_" + DIRECTION_NAMES[facing]
	var frames := _sprite.sprite_frames
	if state == "turn":
		var turn_name := "turn" + suffix
		if frames.has_animation(turn_name) and not (_sprite.animation == turn_name and not _sprite.is_playing()):
			_play(turn_name, 1.0)
			return
		_turning = false
		state = "idle"
	if frames.has_animation(state + suffix):
		var scale := 1.0
		if is_moving and not always_stepping:
			scale = _pace / (walkers.movement().run_pace if state == "run" else walkers.movement().walk_pace)
		_play(state + suffix, scale)
	elif state == "idle":
		if frames.has_animation("walk" + suffix):
			_sprite.animation = "walk" + suffix
			_sprite.frame = 0
			_sprite.pause()
	elif frames.has_animation("walk" + suffix):
		_play("walk" + suffix, _pace / walkers.movement().walk_pace if is_moving and not always_stepping else 1.0)
	if _legs_still():
		_sprite.pause()


## True while its legs stay still: sliding.
func _legs_still() -> bool:
	return is_sliding


func _play(animation_name: String, speed: float) -> void:
	_sprite.speed_scale = speed
	if _sprite.animation != animation_name or not _sprite.is_playing():
		_sprite.play(animation_name)
