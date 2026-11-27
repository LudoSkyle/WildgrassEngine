## Translates the Ruby of Studio's scripts into GDScript in Studio's words
## (feature 22), running nothing: a condition into an expression, a
## script's lines into statements, by fixed rules (see the design), or not
## at all if a part is not one Studio's context has. The output is written
## one way only, so that it can be read back and compared:
## - GDScript's precedences (`or` 1, `and` 2, `not` 3, comparisons 4, `+ -` 5,
##   `* / %` 6, unary `-` 7, a value 8); parentheses only where they are
##   needed: a left operand of lower precedence, a right one of lower or the
##   same, either side of a comparison of the same;
## - one space around an operator, `name(a, b)`, `[a, b]`, keyword arguments
##   as a Dictionary last, `{key = value}`;
## - `gv[n]` as `gv(n)`, `@x` read as `memory.get("x")`, written
##   `memory["x"] = …`, `:name` as `&"name"`, strings in double quotes.
extends RefCounted

const PRECEDENCE: Dictionary[String, int] = {
	"or": 1, "and": 2, "not": 3, "==": 4, "!=": 4, "<": 4, ">": 4, "<=": 4, ">=": 4,
	"+": 5, "-": 5, "*": 6, "/": 6, "%": 6, "neg": 7, "value": 8,
}
## The members of what Studio's words give: a character, the text variables.
const CHARACTER_MEMBERS: Array[String] = [
	"x", "y", "direction", "offset_screen_x", "offset_screen_y", "offset_shadow_screen_x", "offset_shadow_screen_y", "shadow_disabled",
]
const CHARACTER_WRITTEN: Array[String] = [
	"direction", "offset_screen_x", "offset_screen_y", "offset_shadow_screen_x", "offset_shadow_screen_y", "shadow_disabled",
]
const CHARACTER_METHODS: Array[String] = ["moveto", "reset_follower", "leave_cycling_state"]
## The map's view's (`gm`) and the followers' line's (`follow_me`), called.
const MAP_METHODS: Array[String] = ["scroll_up", "scroll_down", "scroll_left", "scroll_right"]
const FOLLOW_ME_METHODS: Array[String] = ["smart_disable", "smart_enable", "update", "reset_position"]
## A module's last name, in snake_case, Studio's context has as a word.
const MODULES: Array[String] = ["follow_me"]
const TEXT_METHODS: Array[String] = ["set_variable", "unset_variable", "reset_variables"]
## A Pokémon's (`$actors[i]`, `pokemon_from_hash(…)`): read, written, called.
const POKEMON_MEMBERS: Array[String] = ["id", "db_symbol", "form", "level", "loyalty", "shiny", "hp", "max_hp", "given_name", "name"]
const POKEMON_WRITTEN: Array[String] = ["form", "loyalty", "given_name", "hp"]
const POKEMON_METHODS: Array[String] = ["egg", "dead", "cure"]
## `$actors`'s and `$pokemon_party`'s, called.
const ACTORS_METHODS: Array[String] = ["empty", "size"]
const PARTY_METHODS: Array[String] = ["heal_party", "pokemon_alive", "size", "empty", "full"]
## Studio's globals and modules, as Studio's words name them.
const CHARACTERS: Array[String] = ["gp", "$game_player"]
const VARIABLES: Array[String] = ["gv", "$game_variables"]
const SWITCHES: Array[String] = ["gs", "$game_switches"]
const TEXT_MODULE := "PFM::Text"
const ACTORS := "$actors"
const PARTY := "$pokemon_party"

## The methods of the words (a method of the script context, with its
## inherited ones): a call to any other is not translated.
var words: Dictionary[String, bool] = {}
## The first part not translated, its method as `method_of` names it.
var unread := ""
## Names a script's method (the importer's report).
var method_of := Callable()

var _tokens: Array[String] = []
var _at := 0
var _failed := false
var _scanner := RegEx.create_from_string("[ \\t\\r]*(\\n|;|&&|\\|\\||==|!=|>=|<=|\\+=|-=|::|[A-Za-z_$@][\\w]*[?!]?|:[A-Za-z_]\\w*[?!]?|\\d+\\.\\d+|\\d+|'(?:[^'\\\\]|\\\\.)*'|\"(?:[^\"\\\\]|\\\\.)*\"|\\S)")


## Reads the words of `context` (a script extending `WgScriptContext`).
func use_words_of(context: Script) -> void:
	words.clear()
	for method: Dictionary in context.get_script_method_list():
		if not String(method["name"]).begins_with("_"):
			words[method["name"]] = true


## `ruby`, a condition, as a GDScript expression; "" if not translated
## (`unread` says what).
func condition(ruby: String) -> String:
	if not _start(ruby):
		return ""
	var made := _expression(0)
	if _failed or _at < _tokens.size():
		return _fail(ruby)
	return made[0]


## `ruby`, a script's lines, as GDScript statements; "" if not translated.
func statements(ruby: String) -> String:
	if not _start(ruby):
		return ""
	var lines: Array[String] = []
	while _at < _tokens.size():
		if _peek() in ["\n", ";"]:
			_at += 1
			continue
		var line := _statement()
		if _failed:
			return _fail(ruby)
		if not _peek() in ["\n", ";", ""]:
			return _fail(ruby)
		lines.append(line)
	if lines.is_empty():
		return _fail(ruby)
	return "\n".join(lines)


func _start(ruby: String) -> bool:
	_tokens.clear()
	_at = 0
	_failed = false
	unread = ""
	var depth := 0
	var position := 0
	while position < ruby.length():
		var found := _scanner.search(ruby, position)
		if found == null or found.get_end() == position:
			break
		var token := found.get_string(1)
		position = found.get_end()
		if token in ["(", "[", "{"]:
			depth += 1
		elif token in [")", "]", "}"]:
			depth -= 1
		# A line goes on inside brackets.
		if token == "\n" and depth > 0:
			continue
		_tokens.append(token)
	if ruby.contains("#{"):
		_fail(ruby)
		return false
	return true


func _fail(part: String) -> String:
	_failed = true
	if unread.is_empty():
		unread = str(method_of.call(part)) if method_of.is_valid() else part
	return ""


func _peek(offset := 0) -> String:
	return _tokens[_at + offset] if _at + offset < _tokens.size() else ""


func _take(token: String) -> bool:
	if _peek() == token:
		_at += 1
		return true
	return false


## One statement: a call, or an assignment to a variable, a switch, a
## character's direction, the memory.
func _statement() -> String:
	var start := _at
	var target := _peek()
	if target in VARIABLES + SWITCHES and _peek(1) == "[":
		_at += 2
		var index := _expression(0)
		if _failed or not _take("]"):
			return _fail(target)
		var operator := _peek()
		if not operator in ["=", "+=", "-="] or (operator != "=" and target in SWITCHES):
			_at = start
		else:
			_at += 1
			var right := _expression(0)
			if _failed:
				return ""
			var setter := "set_gv" if target in VARIABLES else "set_gs"
			if operator == "=":
				return "%s(%s, %s)" % [setter, index[0], right[0]]
			var read := ["gv(%s)" % index[0], PRECEDENCE["value"]]
			var sum := _binary(read, operator.substr(0, 1), right)
			return "%s(%s, %s)" % [setter, index[0], sum[0]]
	if target.begins_with("@") and _peek(1) == "=":
		_at += 2
		var value := _expression(0)
		return "memory[\"%s\"] = %s" % [target.substr(1), value[0]] if not _failed else ""
	_at = start
	var made := _expression(0)
	if _failed:
		return ""
	if _peek() in ["=", "+=", "-="] and _writable(made[0]):
		return _assign(made[0])
	if not made[0].ends_with(")"):
		return _fail(made[0])
	return made[0]


## `target`, a member written, then its operator and value at the cursor;
## Ruby's `a = b = value` as `b = value`, then `a = b`.
func _assign(target: String) -> String:
	var operator := _peek()
	_at += 1
	var value := _expression(0)
	if _failed:
		return ""
	if operator == "=" and _peek() == "=" and _writable(value[0]):
		var inner := _assign(value[0])
		return "%s\n%s = %s" % [inner, target, value[0]] if not _failed else ""
	return "%s %s %s" % [target, operator, value[0]]


## True if `text` is a member Studio's scripts write: a character's, a
## Pokémon's.
func _writable(text: String) -> bool:
	var dot := text.rfind(".")
	if dot <= 0:
		return false
	var base := text.substr(0, dot)
	var member := text.substr(dot + 1)
	return _is_character(base) and member in CHARACTER_WRITTEN or _is_pokemon_member(text, POKEMON_WRITTEN)


## True if `text` is a character of Studio's words: `gp`, `ge(…)`,
## `get_character(…)`, nothing after it.
func _is_character(text: String) -> bool:
	if text == "gp":
		return true
	for start: String in ["ge(", "get_character("]:
		if text.begins_with(start) and text.ends_with(")") and _closes_at_end(text, start.length() - 1):
			return true
	return false


## An expression whose precedence is above `floor`: [text, precedence].
func _expression(floor: int) -> Array:
	var left := _unary()
	while not _failed:
		var operator := _operator()
		if operator.is_empty() or PRECEDENCE[operator] <= floor:
			break
		_at += 1
		var right := _expression(PRECEDENCE[operator])
		if _failed:
			break
		if PRECEDENCE[operator] == 4 and _operator() != "" and PRECEDENCE[_operator()] == 4:
			_fail("a chained comparison")
			break
		left = _binary(left, operator, right)
	return left


## The operator at the cursor, as GDScript writes it; "" if none.
func _operator() -> String:
	var token := _peek()
	match token:
		"&&", "and":
			return "and"
		"||", "or":
			return "or"
		"==", "!=", "<", ">", "<=", ">=", "+", "-", "*", "/", "%":
			return token
	return ""


func _binary(left: Array, operator: String, right: Array) -> Array:
	var level: int = PRECEDENCE[operator]
	var left_text: String = left[0]
	var right_text: String = right[0]
	if left[1] < level or (level == 4 and left[1] == 4):
		left_text = "(%s)" % left_text
	if right[1] <= level:
		right_text = "(%s)" % right_text
	return ["%s %s %s" % [left_text, operator, right_text], level]


func _unary() -> Array:
	if _take("!"):
		var inner := _unary()
		return ["not " + (("(%s)" % inner[0]) if inner[1] < 3 else inner[0]), 3]
	if _take("not"):
		var inner := _expression(3)
		return ["not " + (("(%s)" % inner[0]) if inner[1] < 3 else inner[0]), 3]
	if _take("-"):
		var inner := _unary()
		return ["-" + (("(%s)" % inner[0]) if inner[1] < 7 else inner[0]), 7]
	return _postfix(_primary())


## A value: a literal, a word's call, a variable, a switch, a character, the
## memory, a group.
func _primary() -> Array:
	var token := _peek()
	if token == "":
		_fail("an expression cut short")
		return ["", 8]
	_at += 1
	if token == "(":
		var inner := _expression(0)
		if not _take(")"):
			_fail("(")
		return inner
	if token == "[":
		var items := _arguments("]")
		return ["[%s]" % ", ".join(items), 8]
	if token.is_valid_int() or token.is_valid_float():
		return [str(int(token)) if token.is_valid_int() else str(float(token)), 8]
	if token.begins_with("'") or token.begins_with("\""):
		return [quoted(_unquoted(token)), 8]
	if token.begins_with(":") and token.length() > 1:
		if token.ends_with("?") or token.ends_with("!"):
			_fail(token)
		return ["&\"%s\"" % token.substr(1), 8]
	match token:
		"true", "false":
			return [token, 8]
		"nil":
			return ["null", 8]
	if token in VARIABLES + SWITCHES:
		if not _take("["):
			_fail(token)
			return ["", 8]
		var index := _expression(0)
		if not _take("]"):
			_fail(token)
		return ["%s(%s)" % ["gv" if token in VARIABLES else "gs", index[0]], 8]
	if token in CHARACTERS:
		return ["gp", 8]
	if token == "$game_map" and _peek() == "." and _peek(1) == "events" and _peek(2) == "[":
		_at += 3
		var index := _expression(0)
		if not _take("]"):
			_fail(token)
		return ["get_character(%s)" % index[0], 8]
	if token in ["$game_map", "gm"]:
		return ["gm", 8]
	if token.begins_with("@"):
		return ["memory.get(\"%s\")" % token.substr(1), 8]
	if token == "PFM" and _peek() == "::" and _peek(1) == "Text":
		_at += 2
		return ["text", 8]
	if token == "PFM" and _peek() == "::" and _peek(1) == "Pokemon" and _peek(2) == "." and _peek(3) == "generate_from_hash" and _peek(4) == "(":
		_at += 5
		return ["pokemon_from_hash(%s)" % ", ".join(_arguments(")")), 8]
	if token[0] == token[0].to_upper() and token[0] != token[0].to_lower() and _peek() == "::":
		var last := token
		while _take("::"):
			last = _peek()
			_at += 1
		var word := last.to_snake_case()
		if word in MODULES:
			return [word, 8]
		_fail(token)
		return ["", 8]
	if token == ACTORS:
		if not _take("["):
			return ["actors", 8]
		var index := _expression(0)
		if not _take("]"):
			_fail(token)
		return ["actors.at(%s)" % index[0], 8]
	if token == PARTY:
		return ["pokemon_party", 8]
	return _call(token)


## A word's call: `name`, `name(arguments)`; Ruby's final `?` dropped.
func _call(token: String) -> Array:
	var name := token.trim_suffix("?")
	if token.ends_with("!") or not words.has(name):
		_fail(token)
		return ["", 8]
	if not _take("("):
		return ["%s()" % name, 8]
	return ["%s(%s)" % [name, ", ".join(_arguments(")"))], 8]


## The arguments up to `closing`, keyword ones as a Dictionary last.
func _arguments(closing: String) -> Array[String]:
	var listed: Array[String] = []
	var named: Array[String] = []
	while not _failed and not _take(closing):
		if _peek() == "":
			_fail("an argument list cut short")
			break
		# `map_id = 21` in Ruby's arguments is an assignment: its value.
		if _peek(1) == "=" and _peek().is_valid_identifier():
			_at += 2
		if _peek(1) == ":" and _peek().is_valid_identifier():
			var key := _peek()
			_at += 2
			named.append("%s = %s" % [key, _expression(0)[0]])
		else:
			if not named.is_empty():
				_fail("an argument after a keyword one")
				break
			listed.append(_expression(0)[0])
		if not _take(",") and _peek() != closing:
			_fail("an argument list")
			break
	if not named.is_empty():
		listed.append("{%s}" % ", ".join(named))
	return listed


## `.member` and `.method(…)` after a value: a character's, the texts'.
func _postfix(value: Array) -> Array:
	while not _failed and _peek() == ".":
		var member := _peek(1).trim_suffix("?")
		_at += 2
		var is_text: bool = value[0] == "text"
		var is_character := _is_character(value[0])
		var is_pokemon := _is_pokemon(value[0])
		if is_text and member in TEXT_METHODS or is_character and member in CHARACTER_METHODS \
				or is_pokemon and member in POKEMON_METHODS or value[0] == "actors" and member in ACTORS_METHODS \
				or value[0] == "pokemon_party" and member in PARTY_METHODS or value[0] == "gm" and member in MAP_METHODS \
				or value[0] == "follow_me" and member in FOLLOW_ME_METHODS:
			var listed: Array[String] = []
			if _take("("):
				listed = _arguments(")")
			value = ["%s.%s(%s)" % [value[0], member, ", ".join(listed)], 8]
		elif is_character and member in CHARACTER_MEMBERS or is_pokemon and member in POKEMON_MEMBERS:
			value = ["%s.%s" % [value[0], member], 8]
		else:
			_fail("%s.%s" % [value[0], member])
	return value


## True if `text` is a Pokémon of Studio's words: `actors.at(…)`,
## `pokemon_from_hash(…)`, nothing after the call.
func _is_pokemon(text: String) -> bool:
	for start: String in ["actors.at(", "pokemon_from_hash("]:
		if text.begins_with(start) and text.ends_with(")") and _closes_at_end(text, start.length() - 1):
			return true
	return false


## True if `text` is a Pokémon's member among `members`.
func _is_pokemon_member(text: String, members: Array[String]) -> bool:
	var dot := text.rfind(".")
	return dot > 0 and text.substr(dot + 1) in members and _is_pokemon(text.substr(0, dot))


## True if the bracket opening at `open` closes at the end of `text`.
static func _closes_at_end(text: String, open: int) -> bool:
	var depth := 0
	var quoted := false
	var escaped := false
	for index in range(open, text.length()):
		var letter := text[index]
		if quoted:
			if escaped:
				escaped = false
			elif letter == "\\":
				escaped = true
			elif letter == "\"":
				quoted = false
		elif letter == "\"":
			quoted = true
		elif letter in ["(", "[", "{"]:
			depth += 1
		elif letter in [")", "]", "}"]:
			depth -= 1
			if depth == 0:
				return index == text.length() - 1
	return false


## A Ruby string's text: single quotes keep all but `\\` and `\'`.
func _unquoted(token: String) -> String:
	var inner := token.substr(1, token.length() - 2)
	if token.begins_with("'"):
		return inner.replace("\\\\", "\u0001").replace("\\'", "'").replace("\u0001", "\\")
	return inner.c_unescape()


## `text` as a GDScript string: double quotes, `\\`, `\"`, `\n`, `\t`.
static func quoted(text: String) -> String:
	return "\"%s\"" % text.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\t", "\\t")
