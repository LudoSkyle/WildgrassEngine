## Moves one walker as RPG Maker moves a character (feature 21): a route a
## command imposes, else the way its event's page moves by itself (at
## random, toward the player, along its own route), at RPG Maker's pace of
## 60 ticks a second, counted from the time that passes. The events service
## owns it and has the walkers service drive the walker through it.
extends RefCounted

## One of RPG Maker's frames.
const TICK := 1.0 / 60.0
## The directions RPG Maker turns through.
const RIGHT_OF: Dictionary[Vector2i, Vector2i] = {Vector2i.DOWN: Vector2i.LEFT, Vector2i.LEFT: Vector2i.UP, Vector2i.UP: Vector2i.RIGHT, Vector2i.RIGHT: Vector2i.DOWN}
const DIRECTIONS: Array[Vector2i] = [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]
const STEPS: Dictionary[int, Vector2i] = {
	WgMoveStep.Kind.MOVE_DOWN: Vector2i.DOWN, WgMoveStep.Kind.MOVE_LEFT: Vector2i.LEFT,
	WgMoveStep.Kind.MOVE_RIGHT: Vector2i.RIGHT, WgMoveStep.Kind.MOVE_UP: Vector2i.UP,
	WgMoveStep.Kind.MOVE_LOWER_LEFT: Vector2i(-1, 1), WgMoveStep.Kind.MOVE_LOWER_RIGHT: Vector2i(1, 1),
	WgMoveStep.Kind.MOVE_UPPER_LEFT: Vector2i(-1, -1), WgMoveStep.Kind.MOVE_UPPER_RIGHT: Vector2i(1, -1),
}
const TURNS: Dictionary[int, Vector2i] = {
	WgMoveStep.Kind.TURN_DOWN: Vector2i.DOWN, WgMoveStep.Kind.TURN_LEFT: Vector2i.LEFT,
	WgMoveStep.Kind.TURN_RIGHT: Vector2i.RIGHT, WgMoveStep.Kind.TURN_UP: Vector2i.UP,
}

var walker: WgWalker
## The page's own way of moving.
var move_type := WgEventPage.MoveType.FIXED
var page_route: WgMoveRoute
var page_index := 0
## RPG Maker's speed and frequency, 1 to 6.
var speed := 3
var frequency := 3
## The route a command imposed, or null.
var forced: WgMoveRoute
var forced_index := 0

var _events: WeakRef
var _wait_ticks := 0
var _stop_ticks := 0
var _time := 0.0


## `service`'s walkers, not the walker's: on a map just built, it has none yet.
func _init(service: Object, moved: WgWalker) -> void:
	_events = weakref(service)
	walker = moved
	var walkers: Object = service.get(&"walkers")
	speed = speed_of(walker.pace if walker.pace > 0.0 else walkers.call(&"movement").walk_pace)


## Cells a second at RPG Maker's speed `value`.
static func pace_of(value: int) -> float:
	return 60.0 * pow(2.0, clampi(value, 1, 6)) / 128.0


## RPG Maker's speed nearest `pace` cells a second.
static func speed_of(pace: float) -> int:
	return clampi(roundi(log(pace * 128.0 / 60.0) / log(2.0)), 1, 6)


## Ticks it stands between moves of its own at RPG Maker's frequency `value`.
static func stop_ticks_of(value: int) -> int:
	return (40 - value * 2) * (6 - value)


## Takes the way `page` moves by itself; a route imposed ends.
func set_page(page: WgEventPage) -> void:
	forced = null
	move_type = page.move_type if page != null else WgEventPage.MoveType.FIXED
	page_route = page.move_route if page != null else null
	page_index = 0
	speed = page.move_speed if page != null else 3
	frequency = page.move_frequency if page != null else 3
	walker.pace = pace_of(speed)
	_wait_ticks = 0


## Follows `route` now, its own way of moving waiting until it ends.
func force(route: WgMoveRoute) -> void:
	forced = route
	forced_index = 0
	_wait_ticks = 0


## True while it needs driving: a route imposed, or a page moving by itself.
func is_needed() -> bool:
	return forced != null or move_type != WgEventPage.MoveType.FIXED


## Asked by the walkers service each time the walker is free to step.
func drive(_walker: WgWalker, delta: float) -> void:
	_time += delta
	while _time >= TICK * 0.999 and not walker.is_moving:
		_time -= TICK
		_tick()
	if walker.is_moving:
		_time = 0.0


func _tick() -> void:
	_stop_ticks += 1
	if _wait_ticks > 0:
		_wait_ticks -= 1
		return
	if forced != null:
		_custom(true)
		return
	if not _may_move_by_itself() or _stop_ticks <= stop_ticks_of(frequency):
		return
	match move_type:
		WgEventPage.MoveType.RANDOM:
			match randi() % 6:
				4:
					_forward()
				5:
					_stop_ticks = 0
				_:
					_step(DIRECTIONS[randi() % 4], false)
		WgEventPage.MoveType.APPROACH:
			var player := _player()
			if player == null:
				return
			var away := walker.cell - player.cell
			if absi(away.x) + absi(away.y) >= 20:
				_step(DIRECTIONS[randi() % 4], false)
				return
			match randi() % 6:
				4:
					_step(DIRECTIONS[randi() % 4], false)
				5:
					_forward()
				_:
					_toward(player.cell, 1)
		WgEventPage.MoveType.ROUTE:
			_custom(false)


## An event moves by itself unless it runs its list for the player, or a
## warp or a screen other than a message holds the game.
func _may_move_by_itself() -> bool:
	if walker is WgEvent and ((walker as WgEvent).starting or (walker as WgEvent).is_locked()):
		return false
	var walkers := walker.walkers
	if walkers.maps.is_changing:
		return false
	for screen: Node in walkers.screens.stack():
		if not screen is WgMessageBox:
			return false
	return true


## Runs the route's commands until one takes the tick.
func _custom(imposed: bool) -> void:
	var route := forced if imposed else page_route
	if route == null:
		return
	while true:
		var index := forced_index if imposed else page_index
		if index >= route.steps.size():
			_end(route, imposed)
			return
		var command := route.steps[index]
		var advance := true
		var takes_tick := true
		if STEPS.has(command.kind) or command.kind <= WgMoveStep.Kind.JUMP:
			_move(command)
			advance = route.skippable or walker.is_moving
		elif command.kind == WgMoveStep.Kind.WAIT:
			_wait_ticks = command.value * 2 - 1
		elif command.kind <= WgMoveStep.Kind.TURN_AWAY_FROM_PLAYER:
			_turn(command.kind)
		else:
			takes_tick = false
			_special(command)
		if advance:
			if imposed:
				forced_index += 1
			else:
				page_index += 1
		if takes_tick:
			return


func _end(route: WgMoveRoute, imposed: bool) -> void:
	if route.repeat:
		if imposed:
			forced_index = 0
		else:
			page_index = 0
		return
	if imposed:
		forced = null
		var events: Object = _events.get_ref()
		if events != null:
			events.call(&"route_ended", walker)
	_stop_ticks = 0


func _move(command: WgMoveStep) -> void:
	match command.kind:
		WgMoveStep.Kind.MOVE_RANDOM:
			_step(DIRECTIONS[randi() % 4], false)
		WgMoveStep.Kind.MOVE_TOWARD_PLAYER:
			var player := _player()
			if player != null:
				_toward(player.cell, 1)
		WgMoveStep.Kind.MOVE_AWAY_FROM_PLAYER:
			var player := _player()
			if player != null:
				_toward(player.cell, -1)
		WgMoveStep.Kind.MOVE_FORWARD:
			_forward()
		WgMoveStep.Kind.MOVE_BACKWARD:
			var kept := walker.fixed_direction
			walker.fixed_direction = true
			_step(-walker.facing, false)
			walker.fixed_direction = kept
		WgMoveStep.Kind.JUMP:
			var length := roundi(Vector2(command.offset).length())
			var peak := maxi(1, 10 + length - speed)
			if walker.jump_by(command.offset, peak * 2 * TICK, peak * peak / 4.0):
				_stop_ticks = 0
		_:
			_step(STEPS[command.kind], true)


## A step `direction`; `turn`: facing it even if it does not go.
func _step(direction: Vector2i, turn: bool) -> bool:
	var went := false
	if turn or walker.passes_walls or direction.x != 0 and direction.y != 0:
		went = walker.step(direction)
	elif walker.can_step(direction):
		went = walker.step(direction)
	if went:
		_stop_ticks = 0
	else:
		var events: Object = _events.get_ref()
		if events != null:
			events.call(&"bumped", walker, direction)
	return went


func _forward() -> void:
	_step(walker.facing, false)


## A step toward `target` (`way_sign` 1), or away from it (-1), along its longer
## way first, the other if that one is blocked, as RPG Maker's.
func _toward(target: Vector2i, way_sign: int) -> void:
	var off := walker.cell - target
	if off == Vector2i.ZERO:
		return
	var across := absi(off.x)
	var along := absi(off.y)
	if across == along:
		if randi() % 2 == 0:
			across += 1
		else:
			along += 1
	var horizontal := Vector2i(-signi(off.x) * way_sign, 0)
	var vertical := Vector2i(0, -signi(off.y) * way_sign)
	if across > along:
		_step(horizontal, true)
		if not walker.is_moving and off.y != 0:
			_step(vertical, true)
	else:
		_step(vertical, true)
		if not walker.is_moving and off.x != 0:
			_step(horizontal, true)


func _turn(kind: int) -> void:
	var facing := walker.facing
	var way := facing
	match kind:
		WgMoveStep.Kind.TURN_RIGHT_90:
			way = RIGHT_OF[facing]
		WgMoveStep.Kind.TURN_LEFT_90:
			way = -RIGHT_OF[facing]
		WgMoveStep.Kind.TURN_180:
			way = -facing
		WgMoveStep.Kind.TURN_RIGHT_OR_LEFT_90:
			way = RIGHT_OF[facing] if randi() % 2 == 0 else -RIGHT_OF[facing]
		WgMoveStep.Kind.TURN_RANDOM:
			way = DIRECTIONS[randi() % 4]
		WgMoveStep.Kind.TURN_TOWARD_PLAYER, WgMoveStep.Kind.TURN_AWAY_FROM_PLAYER:
			var player := _player()
			if player == null:
				return
			var off := player.cell - walker.cell
			if off == Vector2i.ZERO:
				return
			way = Vector2i(signi(off.x), 0) if absi(off.x) > absi(off.y) else Vector2i(0, signi(off.y))
			if kind == WgMoveStep.Kind.TURN_AWAY_FROM_PLAYER:
				way = -way
		_:
			way = TURNS[kind]
	walker.turn(way)


func _special(command: WgMoveStep) -> void:
	var events: Object = _events.get_ref()
	match command.kind:
		WgMoveStep.Kind.SWITCH_ON, WgMoveStep.Kind.SWITCH_OFF:
			var story: Object = events.get(&"story") if events != null else null
			if story != null:
				var flag := StringName("switch_%d" % command.value)
				story.call(&"set_flag" if command.kind == WgMoveStep.Kind.SWITCH_ON else &"clear_flag", flag)
		WgMoveStep.Kind.SPEED:
			speed = clampi(command.value, 1, 6)
			walker.pace = pace_of(speed)
		WgMoveStep.Kind.FREQUENCY:
			frequency = clampi(command.value, 1, 6)
		WgMoveStep.Kind.WALK_ANIMATION_ON, WgMoveStep.Kind.WALK_ANIMATION_OFF:
			walker.walk_animation = command.kind == WgMoveStep.Kind.WALK_ANIMATION_ON
		WgMoveStep.Kind.STEP_ANIMATION_ON, WgMoveStep.Kind.STEP_ANIMATION_OFF:
			walker.always_stepping = command.kind == WgMoveStep.Kind.STEP_ANIMATION_ON
		WgMoveStep.Kind.FIXED_DIRECTION_ON, WgMoveStep.Kind.FIXED_DIRECTION_OFF:
			walker.fixed_direction = command.kind == WgMoveStep.Kind.FIXED_DIRECTION_ON
		WgMoveStep.Kind.THROUGH_ON, WgMoveStep.Kind.THROUGH_OFF:
			walker.through = command.kind == WgMoveStep.Kind.THROUGH_ON
			walker.passes_walls = walker.through
		WgMoveStep.Kind.ON_TOP_ON, WgMoveStep.Kind.ON_TOP_OFF:
			walker.on_top = command.kind == WgMoveStep.Kind.ON_TOP_ON
		WgMoveStep.Kind.GRAPHIC:
			if walker is WgEvent:
				(walker as WgEvent).show_graphic(command.sheet, command.direction, command.pattern)
			else:
				var sprite := walker.get_node_or_null(walker.sprite)
				if sprite is WgCharacterSprite:
					(sprite as WgCharacterSprite).sheet = command.sheet
				if sprite is CanvasItem:
					(sprite as CanvasItem).visible = command.sheet != null
				walker.facing = command.direction
		WgMoveStep.Kind.OPACITY:
			var sprite := walker.get_node_or_null(walker.sprite)
			if sprite is CanvasItem:
				(sprite as CanvasItem).modulate.a = clampi(command.value, 0, 255) / 255.0
		WgMoveStep.Kind.SOUND:
			var audio: Object = events.get(&"audio") if events != null else null
			if audio != null and not command.sound.is_empty():
				audio.call(&"effect", command.sound, command.volume / 100.0, command.pitch / 100.0)
		WgMoveStep.Kind.BLENDING:
			if events != null:
				events.call(&"report_unsupported", "a route's blending")
		WgMoveStep.Kind.CALL:
			if events != null:
				events.call(&"report_unsupported", "a route's call")


func _player() -> WgWalker:
	return walker.walkers.maps.traveller as WgWalker
