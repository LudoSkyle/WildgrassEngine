## Reads the Ruby condition of a Studio conditional branch (`player_spotted?(3)
## && gs[12]`) as the engine's `WgEventIf`: `&&`, `||`, `!`, parentheses,
## comparisons, and the parts the engine has a condition for. Any other part
## is an `UNSUPPORTED` term naming its method; the reader runs nothing.
extends RefCounted

## The facings RPG Maker numbers.
const DIRECTIONS: Dictionary[int, Vector2i] = {2: Vector2i.DOWN, 4: Vector2i.LEFT, 6: Vector2i.RIGHT, 8: Vector2i.UP}
const SYMBOL_DIRECTIONS: Dictionary[String, Vector2i] = {"down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT, "up": Vector2i.UP}
const COMPARISONS: Dictionary[String, WgEventIf.Comparison] = {
	"==": WgEventIf.Comparison.EQUAL, "!=": WgEventIf.Comparison.NOT_EQUAL, ">=": WgEventIf.Comparison.AT_LEAST,
	"<=": WgEventIf.Comparison.AT_MOST, ">": WgEventIf.Comparison.MORE, "<": WgEventIf.Comparison.LESS,
}
## The common event a player seen in a band starts, as Studio's.
const APPEARANCE := 2

## Studio's map ids and their dbSymbols, for a local switch of another map.
var map_symbols: Dictionary[int, StringName] = {}
## The methods a script condition calls, as `script_method` names them.
var method_of := Callable()

var _tokens: Array[String] = []
var _at := 0
var _text := ""
var _scanner := RegEx.create_from_string("\\s*(&&|\\|\\||==|!=|>=|<=|::|[A-Za-z_$@][\\w]*[?!]?|:[A-Za-z_]\\w*|\\d+|'[^']*'|\"[^\"]*\"|\\S)")


## `text` as a condition; an `UNSUPPORTED` one naming its method if it is
## not one the engine reads at all.
func read(text: String) -> WgEventIf:
	_text = text
	_tokens.clear()
	_at = 0
	var position := 0
	while position < text.length():
		var found := _scanner.search(text, position)
		if found == null or found.get_end() == position:
			break
		_tokens.append(found.get_string(1))
		position = found.get_end()
	var made := _or()
	if made == null or _at < _tokens.size():
		return unsupported(text)
	return made


## A part the engine cannot read: false, named by the method it calls.
func unsupported(part: String) -> WgEventIf:
	var made := WgEventIf.new()
	made.kind = WgEventIf.Kind.UNSUPPORTED
	made.about = "script %s" % (method_of.call(part) if method_of.is_valid() else part)
	return made


func _peek(offset := 0) -> String:
	return _tokens[_at + offset] if _at + offset < _tokens.size() else ""


func _take(token: String) -> bool:
	if _peek() == token:
		_at += 1
		return true
	return false


func _or() -> WgEventIf:
	return _chain(&"_and", ["||", "or"], WgEventIf.Kind.ANY)


func _and() -> WgEventIf:
	return _chain(&"_not", ["&&", "and"], WgEventIf.Kind.ALL)


func _chain(next: StringName, operators: Array, kind: WgEventIf.Kind) -> WgEventIf:
	var first: WgEventIf = call(next)
	if first == null or not _peek() in operators:
		return first
	var made := WgEventIf.new()
	made.kind = kind
	made.terms.append(first)
	while _peek() in operators:
		_at += 1
		var term: WgEventIf = call(next)
		if term == null:
			return null
		made.terms.append(term)
	return made


func _not() -> WgEventIf:
	if _take("!") or _take("not"):
		var made := _not()
		if made != null:
			made.negate = not made.negate
		return made
	return _comparison()


## A part, compared or not: `gv[3] >= 2`, `gp.direction == 6`, `gs[4]`.
func _comparison() -> WgEventIf:
	var start := _at
	var left: Variant = _operand()
	if left is WgEventIf:
		if _peek() in ["==", "!="] and _peek(1) in ["true", "false"]:
			var flips := (_peek() == "!=") != (_peek(1) == "false")
			_at += 2
			if flips:
				(left as WgEventIf).negate = not (left as WgEventIf).negate
		return left
	if left == null:
		return _skip_part(start)
	if not _peek() in COMPARISONS:
		return _skip_part(start)
	var comparison := COMPARISONS[_tokens[_at]]
	_at += 1
	var right: Variant = _operand()
	var made := _compare(left, comparison, right)
	return made if made != null else _skip_part(start)


## The part from `start` to the next `&&`, `||` or closing parenthesis, as
## a term the engine cannot read.
func _skip_part(start: int) -> WgEventIf:
	_at = start
	var depth := 0
	var words: Array[String] = []
	while _at < _tokens.size():
		var token := _tokens[_at]
		if depth == 0 and (token in ["&&", "||", "and", "or"] or token == ")"):
			break
		if token in ["(", "[", "{"]:
			depth += 1
		elif token in [")", "]", "}"]:
			depth -= 1
		words.append(token)
		_at += 1
	return unsupported("".join(words)) if not words.is_empty() else null


## A value: an int, `true`, a variable, a switch, a character's facing or
## cell; a condition in parentheses or a call the engine reads; else null.
func _operand() -> Variant:
	var token := _peek()
	if token == "(":
		_at += 1
		var inner := _or()
		return inner if inner != null and _take(")") else null
	if token.is_valid_int():
		_at += 1
		return int(token)
	if token in ["gv", "$game_variables", "gs", "$game_switches"]:
		var index := _index()
		if index < 0:
			return null
		if token in ["gv", "$game_variables"]:
			return {"variable": index}
		var made := WgEventIf.new()
		made.kind = WgEventIf.Kind.SWITCH
		made.number = index
		return made
	var character: Variant = _character()
	if character != null:
		return character
	return _call()


## `[n]` after a name; -1 if it is not one.
func _index() -> int:
	if _peek(1) == "[" and _peek(2).is_valid_int() and _peek(3) == "]":
		var index := int(_peek(2))
		_at += 4
		return index
	return -1


## `gp.direction`, `ge.x`, `get_character(3).y`, `$game_map.events[3].x`:
## the character and what of it; null if not one.
func _character() -> Variant:
	var number := 0
	var start := _at
	match _peek():
		"gp", "$game_player":
			number = -1
			_at += 1
		"ge":
			number = 0
			_at += 1
			if _take("("):
				if not _peek().is_valid_int():
					_at = start
					return null
				number = int(_tokens[_at])
				_at += 1
				if not _take(")"):
					_at = start
					return null
		"get_character":
			if _peek(1) != "(" or not _peek(2).is_valid_int() or _peek(3) != ")":
				return null
			number = int(_peek(2))
			_at += 4
		"$game_map":
			if _peek(1) != "." or _peek(2) != "events" or _peek(3) != "[" or not _peek(4).is_valid_int() or _peek(5) != "]":
				return null
			number = int(_peek(4))
			_at += 6
		_:
			return null
	if _peek() == "." and _peek(1) in ["direction", "x", "y"]:
		var what := _peek(1)
		_at += 2
		return {"character": number, "what": what}
	_at = start
	return null


## A call the engine reads, as a condition; null if not one.
func _call() -> WgEventIf:
	var name := _peek()
	if _peek(1) != "(":
		return null
	var start := _at
	_at += 2
	var arguments: Array = []
	var named := {}
	while _peek() != ")":
		if _peek() == "":
			_at = start
			return null
		if _peek(1) == ":" and _peek().is_valid_identifier():
			var key := _peek()
			_at += 2
			named[key] = _argument()
		elif _peek().begins_with(":") or _peek().is_valid_int() or _peek().begins_with("'") or _peek().begins_with("\""):
			arguments.append(_argument())
		else:
			_at = start
			return null
		if _peek() == "map_id" and _peek(1) == "=":
			_at += 2
			arguments.append(_argument())
		_take(",")
	_at += 1
	var made := _built(name, arguments, named)
	if made == null:
		_at = start
	return made


func _argument() -> Variant:
	var token := _peek()
	_at += 1
	if token.is_valid_int():
		return int(token)
	if token.begins_with(":"):
		return token.substr(1)
	if token.begins_with("'") or token.begins_with("\""):
		return token.substr(1, token.length() - 2)
	return null


func _built(name: String, arguments: Array, named: Dictionary) -> WgEventIf:
	var made := WgEventIf.new()
	made.number = 0
	match name:
		"player_spotted?", "trainer_spotted":
			if arguments.size() != 1 or not arguments[0] is int:
				return null
			made.kind = WgEventIf.Kind.PLAYER_SEEN
			made.reach = arguments[0]
		"player_spotted_rect?", "trainer_spotted_rect":
			if arguments.size() != 2 or not arguments[0] is int or not arguments[1] is int:
				return null
			made.kind = WgEventIf.Kind.PLAYER_SEEN
			made.reach = arguments[0]
			made.side = arguments[1]
			made.then_common = APPEARANCE
		"player_spotted_directional?":
			for key: String in named:
				if not key in SYMBOL_DIRECTIONS or not named[key] is int:
					return null
			if not arguments.is_empty():
				return null
			made.kind = WgEventIf.Kind.PLAYER_SEEN
			# Each facing's own reach, else the others' in Studio's order.
			var orders := {"down": ["down", "up", "left", "right"], "left": ["left", "right", "up", "down"], "right": ["right", "left", "up", "down"], "up": ["up", "down", "left", "right"]}
			var reaches: Array[int] = []
			for facing: String in ["down", "left", "right", "up"]:
				var reach := 1
				for key: String in orders[facing]:
					if named.has(key):
						reach = named[key]
						break
				reaches.append(reach)
			made.reaches = reaches
		"detect_player":
			if arguments.size() != 2 or not arguments[0] is int:
				return null
			# A direction Studio does not name is up, as its own reading.
			var way := Vector2i.UP
			if arguments[1] is String:
				if not SYMBOL_DIRECTIONS.has(arguments[1]):
					return null
				way = SYMBOL_DIRECTIONS[arguments[1]]
			elif arguments[1] is int and DIRECTIONS.has(arguments[1]):
				way = DIRECTIONS[arguments[1]]
			made.kind = WgEventIf.Kind.PLAYER_IN_LINE
			made.reach = arguments[0]
			made.direction = way
		"detect_player_rect":
			if arguments.size() != 2 or not arguments[0] is int or not arguments[1] is int:
				return null
			made.kind = WgEventIf.Kind.PLAYER_IN_RECT
			made.size = Vector2i(arguments[0], arguments[1])
		"detect_player_circle":
			if arguments.size() != 1 or not arguments[0] is int:
				return null
			made.kind = WgEventIf.Kind.PLAYER_IN_CIRCLE
			made.value = arguments[0]
		"get_self_switch":
			if arguments.is_empty() or not arguments[0] is String or arguments.size() > 3:
				return null
			made.kind = WgEventIf.Kind.LOCAL_SWITCH
			made.letter = arguments[0]
			if arguments.size() >= 2:
				if not arguments[1] is int:
					return null
				made.event = arguments[1]
			if arguments.size() == 3:
				if not arguments[2] is int or not map_symbols.has(arguments[2]):
					return null
				made.map = map_symbols[arguments[2]]
		_:
			return null
	return made


## `left comparison right` as a condition; null if the engine has none.
func _compare(left: Variant, comparison: WgEventIf.Comparison, right: Variant) -> WgEventIf:
	var made := WgEventIf.new()
	made.comparison = comparison
	if left is Dictionary and left.has("variable") and (right is int or (right is Dictionary and right.has("variable"))):
		made.kind = WgEventIf.Kind.VARIABLE
		made.number = left["variable"]
		made.against_variable = right is Dictionary
		made.value = right["variable"] if right is Dictionary else right
		return made
	if left is Dictionary and left.has("character") and right is int:
		made.number = left["character"]
		if left["what"] == "direction":
			if not DIRECTIONS.has(right) or not comparison in [WgEventIf.Comparison.EQUAL, WgEventIf.Comparison.NOT_EQUAL]:
				return null
			made.kind = WgEventIf.Kind.FACING
			made.direction = DIRECTIONS[right]
			made.negate = comparison == WgEventIf.Comparison.NOT_EQUAL
			made.comparison = WgEventIf.Comparison.EQUAL
			return made
		made.kind = WgEventIf.Kind.CELL
		made.axis = 0 if left["what"] == "x" else 1
		made.value = right
		return made
	return null
