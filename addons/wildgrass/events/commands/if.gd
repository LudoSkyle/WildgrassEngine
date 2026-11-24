## A condition: the commands after it, at a greater indent, run when it
## holds; a `WgEventElse` at its indent runs otherwise.
class_name WgEventIf
extends WgEventCommand

enum Kind {
	## Switch `number` is on (`on`) or off.
	SWITCH,
	## Variable `number` compares to `value`, or to variable `value`.
	VARIABLE,
	## The event's local switch `letter` is on (`on`) or off.
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
}
enum Comparison { EQUAL, AT_LEAST, AT_MOST, MORE, LESS, NOT_EQUAL }

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


func run(running: _Run) -> bool:
	return running.branch(holds(running))


func holds(running: _Run) -> bool:
	var story := running.story
	match kind:
		Kind.SWITCH:
			return story.has(StringName("switch_%d" % number)) == on
		Kind.VARIABLE:
			var left := int(story.value(StringName("variable_%d" % number)))
			var right := int(story.value(StringName("variable_%d" % value))) if against_variable else value
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
		Kind.LOCAL_SWITCH:
			return running.event != null and story.has(story.local(running.event, StringName(letter))) == on
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
	running.unsupported("condition %s" % about)
	return false
