## A condition: the commands after it, at a greater indent, run when it
## holds; a `WgEventElse` at its indent runs otherwise. `negate` turns it
## over; `ALL` and `ANY` hold several. A part the engine cannot read yet
## makes the whole false.
class_name WgEventIf
extends WgEventCommand

enum Kind {
	## Switch `number` is on (`on`) or off.
	SWITCH,
	## Variable `number` compares to `value`, or to variable `value`.
	VARIABLE,
	## Local switch `letter` is on (`on`) or off: of the event, or of event
	## `event` of `map` (empty: the map the list started on).
	LOCAL_SWITCH,
	## The timer shows at least (`on`) or at most `value` seconds.
	TIMER,
	## Character `number` (-1 the player, 0 this event) faces `direction`.
	FACING,
	## The money is at least (`on`) or at most `value`.
	MONEY,
	## The bag holds the item `item`.
	ITEM,
	## The input action `action` is held.
	KEY,
	## A story condition, `condition` (feature 7).
	STORY,
	## A condition the engine cannot read yet (`about` says which): false.
	UNSUPPORTED,
	## Character `number` sees the player within `reach` cells ahead (or the
	## reach of its facing in `reaches`: down, left, right, up), nothing
	## between them; with `side`, in a band that wide on each side. Then
	## common event `then_common` starts, if any.
	PLAYER_SEEN,
	## The player on the line `direction` from character `number`, at most
	## `reach` cells, whatever stands between.
	PLAYER_IN_LINE,
	## The player at most `size.x` cells across and `size.y` along from
	## character `number`.
	PLAYER_IN_RECT,
	## The player's distance to character `number`, squared, at most `value`.
	PLAYER_IN_CIRCLE,
	## Character `number`'s cell from its map's origin, along `axis` (0: x,
	## 1: y), compares to `value`.
	CELL,
	## Each of `terms` holds.
	ALL,
	## One of `terms` holds.
	ANY,
}
enum Comparison { EQUAL, AT_LEAST, AT_MOST, MORE, LESS, NOT_EQUAL }

## The facings `reaches` follows.
const DIRECTIONS: Array[Vector2i] = [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]

@export var kind := Kind.SWITCH
@export var number := 1
@export var on := true
@export var comparison := Comparison.EQUAL
@export var value := 0
## VARIABLE: `value` is a variable's number.
@export var against_variable := false
@export var letter := "A"
@export var direction := Vector2i.DOWN
@export var item: StringName = &""
@export var action: StringName = &""
@export var condition := ""
@export var about := ""
@export var negate := false
## `ALL`, `ANY`: the conditions (`WgEventIf`), typed by their base: a script
## holding an array of its own type is never freed.
@export var terms: Array[WgEventCommand] = []
@export var reach := 1
@export var reaches: Array[int] = []
@export var side := 0
@export var size := Vector2i.ZERO
@export var axis := 0
@export var event := 0
@export var map: StringName = &""
@export var then_common := 0


func run(running: _Run) -> bool:
	return running.branch(holds(running))


func holds(running: _Run) -> bool:
	var unread := _unread()
	if unread != null:
		running.unsupported("condition %s" % unread.about)
		return false
	return _holds(running) != negate


## The first part the engine cannot read, or null.
func _unread() -> WgEventIf:
	if kind == Kind.UNSUPPORTED:
		return self
	for term: WgEventCommand in terms if kind in [Kind.ALL, Kind.ANY] else []:
		var unread := (term as WgEventIf)._unread() if term is WgEventIf else null
		if unread != null:
			return unread
	return null


func _holds(running: _Run) -> bool:
	var story := running.story
	match kind:
		Kind.SWITCH:
			return story.has(StringName("switch_%d" % number)) == on
		Kind.VARIABLE:
			var left := int(story.value(StringName("variable_%d" % number)))
			var right := int(story.value(StringName("variable_%d" % value))) if against_variable else value
			return _compare(left, right)
		Kind.LOCAL_SWITCH:
			var flag := running.local_switch(letter, event, map)
			return not flag.is_empty() and story.has(flag) == on
		Kind.TIMER:
			var seconds: Variant = running.events.call(&"timer_seconds")
			if seconds == null:
				return false
			return int(seconds) >= value if on else int(seconds) <= value
		Kind.FACING:
			var walker := running.character(number)
			return walker != null and walker.facing == direction
		Kind.MONEY:
			var money := int(running.events.call(&"money"))
			return money >= value if on else money <= value
		Kind.ITEM:
			return bool(running.events.call(&"has_item", item))
		Kind.KEY:
			return InputMap.has_action(action) and Input.is_action_pressed(action)
		Kind.STORY:
			return story.check(condition, running.event)
		Kind.PLAYER_SEEN:
			var watcher := running.character(number)
			if watcher == null:
				return false
			var seen: bool = running.events.call(&"sees_player", watcher, reaches[DIRECTIONS.find(watcher.facing)] if reaches.size() == 4 else reach, side)
			if seen and then_common > 0:
				running.events.call(&"start_common", then_common)
			return seen
		Kind.PLAYER_IN_LINE, Kind.PLAYER_IN_RECT, Kind.PLAYER_IN_CIRCLE:
			var watcher := running.character(number)
			var player := running.character(-1)
			if watcher == null or player == null:
				return false
			var off := player.cell - watcher.cell
			match kind:
				Kind.PLAYER_IN_LINE:
					var along := off.x * direction.x + off.y * direction.y
					return off - direction * along == Vector2i.ZERO and along >= 0 and along <= reach
				Kind.PLAYER_IN_RECT:
					return absi(off.x) <= size.x and absi(off.y) <= size.y
			return off.x * off.x + off.y * off.y <= value
		Kind.CELL:
			var walker := running.character(number)
			if walker == null:
				return false
			var at := walker.cell - Vector2i(running.events.call(&"map_origin_of", walker))
			return _compare(at.x if axis == 0 else at.y, value)
		Kind.ALL:
			return terms.all(func(term: WgEventCommand) -> bool: return term is WgEventIf and (term as WgEventIf).holds(running))
		Kind.ANY:
			return terms.any(func(term: WgEventCommand) -> bool: return term is WgEventIf and (term as WgEventIf).holds(running))
	return false


func _compare(left: int, right: int) -> bool:
	match comparison:
		Comparison.EQUAL:
			return left == right
		Comparison.AT_LEAST:
			return left >= right
		Comparison.AT_MOST:
			return left <= right
		Comparison.MORE:
			return left > right
		Comparison.LESS:
			return left < right
	return left != right
