## One command of a `WgMoveRoute`, as RPG Maker numbers them. A step, a turn
## and a wait take their time; the others are done at once, the next one
## with them.
class_name WgMoveStep
extends Resource

enum Kind {
	MOVE_DOWN = 1, MOVE_LEFT, MOVE_RIGHT, MOVE_UP,
	MOVE_LOWER_LEFT, MOVE_LOWER_RIGHT, MOVE_UPPER_LEFT, MOVE_UPPER_RIGHT,
	MOVE_RANDOM, MOVE_TOWARD_PLAYER, MOVE_AWAY_FROM_PLAYER, MOVE_FORWARD, MOVE_BACKWARD,
	## By `offset` cells; none: a hop in place.
	JUMP,
	## `value` of RPG Maker's waits: `value / 30` seconds.
	WAIT,
	TURN_DOWN, TURN_LEFT, TURN_RIGHT, TURN_UP,
	TURN_RIGHT_90, TURN_LEFT_90, TURN_180, TURN_RIGHT_OR_LEFT_90, TURN_RANDOM,
	TURN_TOWARD_PLAYER, TURN_AWAY_FROM_PLAYER,
	## Switch `value` on, off.
	SWITCH_ON, SWITCH_OFF,
	## RPG Maker's speed `value`, 1 to 6: `60 × 2^value / 128` cells a second.
	SPEED,
	## RPG Maker's frequency `value`, 1 to 6: how long it stands between moves.
	FREQUENCY,
	WALK_ANIMATION_ON, WALK_ANIMATION_OFF, STEP_ANIMATION_ON, STEP_ANIMATION_OFF,
	FIXED_DIRECTION_ON, FIXED_DIRECTION_OFF,
	## Through walls and walkers.
	THROUGH_ON, THROUGH_OFF,
	ON_TOP_ON, ON_TOP_OFF,
	## `sheet` (none: nothing shows), facing `direction`, column `pattern`.
	GRAPHIC,
	## `value` from 0 to 255.
	OPACITY,
	## RPG Maker's blending `value`.
	BLENDING,
	## The sound effect `sound`, at `volume` and `pitch` (percent).
	SOUND,
	## A call the engine runs by name (`call`, as written).
	CALL,
}

@export var kind := Kind.MOVE_DOWN
@export var value := 0
@export var offset := Vector2i.ZERO
@export var sheet: Texture2D
@export var direction := Vector2i.DOWN
@export var pattern := 0
@export var sound: StringName = &""
@export var volume := 100
@export var pitch := 100
@export var call := ""
