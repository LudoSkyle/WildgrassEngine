## Sets variables `first` to `last` (values `variable_<n>`) by an operation
## on an operand. Values stay whole numbers between -99999999 and 99999999;
## dividing floors, as RPG Maker's.
class_name WgEventSetVariables
extends WgEventCommand

enum Operation { SET, ADD, SUBTRACT, MULTIPLY, DIVIDE, MODULO }
enum Operand {
	## `value`.
	CONSTANT,
	## Variable `value`.
	VARIABLE,
	## A whole number from `value` to `value_max`.
	RANDOM,
	## How many of the item `item` the bag holds.
	ITEM,
	## Of character `value` (-1 the player, 0 this event): `about`.
	CHARACTER,
	## Of the game: `about`.
	GAME,
	## An operand the engine cannot read yet (`about` says which): 0.
	UNSUPPORTED,
}
## CHARACTER: what is read.
enum Of { X, Y, FACING, SCREEN_X, SCREEN_Y, TERRAIN_TAG }
## GAME: what is read.
enum Game { MAP_ID, PARTY_SIZE, MONEY, STEPS, PLAY_TIME, TIMER, SAVE_COUNT }

const LIMIT := 99999999
## RPG Maker's numbers of the directions.
const FACINGS: Dictionary[Vector2i, int] = {Vector2i.DOWN: 2, Vector2i.LEFT: 4, Vector2i.RIGHT: 6, Vector2i.UP: 8}

@export var first := 1
@export var last := 1
@export var operation := Operation.SET
@export var operand := Operand.CONSTANT
@export var value := 0
@export var value_max := 0
@export var item: StringName = &""
@export var character_value := Of.X
@export var game_value := Game.MAP_ID
@export var about := ""


func run(running: _Run) -> bool:
	var amount := operand_value(running)
	for number in range(first, last + 1):
		var key := StringName("variable_%d" % number)
		var current := int(running.story.value(key))
		match operation:
			Operation.SET:
				current = amount
			Operation.ADD:
				current += amount
			Operation.SUBTRACT:
				current -= amount
			Operation.MULTIPLY:
				current *= amount
			Operation.DIVIDE:
				if amount != 0:
					current = floori(float(current) / float(amount))
			Operation.MODULO:
				if amount != 0:
					current = current - amount * floori(float(current) / float(amount))
		running.story.set_value(key, clampi(current, -LIMIT, LIMIT))
	return true


func operand_value(running: _Run) -> int:
	match operand:
		Operand.CONSTANT:
			return value
		Operand.VARIABLE:
			return int(running.story.value(StringName("variable_%d" % value)))
		Operand.RANDOM:
			return randi_range(value, value_max)
		Operand.ITEM:
			return int(running.events.call(&"item_count", item))
		Operand.CHARACTER:
			var walker := running.character(value)
			if walker == null:
				return 0
			match character_value:
				Of.X:
					return walker.cell.x - int(running.events.call(&"map_origin_of", walker).x)
				Of.Y:
					return walker.cell.y - int(running.events.call(&"map_origin_of", walker).y)
				Of.FACING:
					return FACINGS.get(walker.facing, 2)
				Of.TERRAIN_TAG:
					return int(running.events.call(&"terrain_tag", walker))
			var screen: Vector2 = walker.get_global_transform_with_canvas().origin
			return int(screen.x if character_value == Of.SCREEN_X else screen.y)
		Operand.GAME:
			return int(running.events.call(&"game_value", game_value))
	running.unsupported("operand %s" % about)
	return 0
