## A Studio map's events (feature 10 quater): read from its RPG Maker map
## file and written as the engine's events (feature 21), one to one: every
## page, its condition, look and trigger, and every command, as the class
## the engine has for it, or kept raw until it has one.
extends RefCounted

const _Reader := preload("res://addons/wildgrass/studio/marshal_reader.gd")
const _StudioMessages := preload("res://addons/wildgrass/studio/studio_messages.gd")

## RPG Maker's commands, by code, as the report names them.
const COMMANDS: Dictionary[int, String] = {
	101: "Show Text", 102: "Show Choices", 103: "Input Number", 104: "Change Text Options", 105: "Button Input",
	106: "Wait", 111: "Conditional Branch", 112: "Loop", 113: "Break Loop", 115: "Exit Event Processing",
	116: "Erase Event", 117: "Call Common Event", 118: "Label", 119: "Jump to Label", 121: "Control Switches",
	122: "Control Variables", 123: "Control Self Switch", 124: "Control Timer", 125: "Change Gold",
	126: "Change Items", 127: "Change Weapons", 128: "Change Armor", 129: "Change Party Member",
	131: "Change Windowskin", 132: "Change Battle BGM", 133: "Change Battle End ME", 134: "Change Save Access",
	135: "Change Menu Access", 136: "Change Encounter", 201: "Transfer Player", 202: "Set Event Location",
	203: "Scroll Map", 204: "Change Map Settings", 205: "Change Fog Color Tone", 206: "Change Fog Opacity",
	207: "Show Animation", 208: "Change Transparent Flag", 209: "Set Move Route", 210: "Wait for Move's Completion",
	221: "Prepare for Transition", 222: "Execute Transition", 223: "Change Screen Color Tone", 224: "Screen Flash",
	225: "Screen Shake", 231: "Show Picture", 232: "Move Picture", 233: "Rotate Picture", 234: "Change Picture Color Tone",
	235: "Erase Picture", 236: "Set Weather Effects", 241: "Play BGM", 242: "Fade Out BGM", 245: "Play BGS",
	246: "Fade Out BGS", 247: "Memorize BGM/BGS", 248: "Restore BGM/BGS", 249: "Play ME", 250: "Play SE", 251: "Stop SE",
	301: "Battle Processing", 302: "Shop Processing", 303: "Name Input Processing", 311: "Change HP", 312: "Change SP",
	313: "Change State", 314: "Recover All", 315: "Change EXP", 316: "Change Level", 317: "Change Parameters",
	318: "Change Skills", 319: "Change Equipment", 320: "Change Actor Name", 321: "Change Actor Class",
	322: "Change Actor Graphic", 340: "Abort Battle", 351: "Call Menu Screen", 352: "Call Save Screen",
	353: "Game Over", 354: "Return to Title Screen", 355: "Script",
}
## The lines that go on a command before them: text, choices' and branches'
## ends, comments, move routes, scripts.
const CONTINUATIONS: Array[int] = [401, 402, 403, 408, 509, 601, 602, 603, 655]
## RPG Maker's directions.
const DIRECTIONS: Dictionary[int, Vector2i] = {2: Vector2i.DOWN, 4: Vector2i.LEFT, 6: Vector2i.RIGHT, 8: Vector2i.UP}
## RPG Maker's buttons, as Godot's input actions.
const BUTTONS: Dictionary[int, StringName] = {2: &"ui_down", 4: &"ui_left", 6: &"ui_right", 8: &"ui_up", 11: &"ui_accept", 12: &"ui_cancel", 13: &"ui_accept"}
## Event name tags.
const INVISIBLE := "invisible_"

## Problems met: a map file unread.
var problems: Array[String] = []
## The Studio project's `Data` folder.
var data_folder := ""
## Gives the texture of a character sheet, by its Godot path. Default: load().
var texture_of := Callable()
## Where character sheets go in the game.
var sheets_folder := "res://graphics/characters"
## The commands kept raw, by what they are: "Show Text", "script give_item".
var raw_counts: Dictionary[String, int] = {}
## The words of messages and choices.
var messages: _StudioMessages

var _reader := _Reader.new()
var _script_method := RegEx.create_from_string("^\\s*(?:[A-Za-z_][\\w]*::)*(?:[$@]?[A-Za-z_]\\w*(?:\\([^()]*\\))?\\.)*([A-Za-z_]\\w*[?!]?)")
var _items: Dictionary[int, StringName] = {}


func _init(data: String) -> void:
	data_folder = data
	messages = _StudioMessages.new(data)
	texture_of = func(path: String) -> Texture2D: return load(path) as Texture2D if ResourceLoader.exists(path) else null


## The events of map `map_id` (Studio's map id, the number of its RPG Maker
## file), sorted by id; [] with a problem if its file cannot be read.
func events_of(map_id: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var path := data_folder.path_join("Map%03d.rxdata" % map_id)
	if not FileAccess.file_exists(path):
		return found
	var map: Variant = _reader.read_file(path)
	if not map is Dictionary or not (map as Dictionary).get("events") is Dictionary:
		problems.append("map %d: its events cannot be read (%s)" % [map_id, _reader.error])
		return found
	var events: Dictionary = map["events"]
	var ids := events.keys()
	ids.sort()
	for id: Variant in ids:
		if events[id] is Dictionary:
			found.append(events[id])
	return found


## The common events, by number; {} if the file cannot be read.
func common_events() -> Dictionary[int, Dictionary]:
	var found: Dictionary[int, Dictionary] = {}
	var path := data_folder.path_join("CommonEvents.rxdata")
	if not FileAccess.file_exists(path):
		return found
	var list: Variant = _reader.read_file(path)
	if not list is Array:
		problems.append("common events cannot be read (%s)" % _reader.error)
		return found
	for entry: Variant in list:
		if entry is Dictionary and int((entry as Dictionary).get("id", 0)) > 0:
			found[int(entry["id"])] = entry
	return found


## The names of the character sheets the events of `events` show.
static func sheets_of(events: Array[Dictionary]) -> Array[String]:
	var found: Array[String] = []
	for event in events:
		for page: Dictionary in event.get("pages", []):
			var name := str((page.get("graphic", {}) as Dictionary).get("character_name", ""))
			if not name.is_empty() and not name in found:
				found.append(name)
	return found


## Where the sheet `name` goes in the game.
func sheet_path(name: String) -> String:
	return sheets_folder.path_join(name + ".png")


## `event` as the engine's event, on the cell it stands on.
func build_event(event: Dictionary, cell_size: int) -> WgEvent:
	var node := WgEvent.new()
	var id := int(event.get("id", 0))
	node.name = "Event%d" % id
	node.event_id = id
	node.position = Vector2(int(event.get("x", 0)) * cell_size + cell_size / 2.0, int(event.get("y", 0)) * cell_size + cell_size / 2.0)
	node.invisible_blocker = str(event.get("name", "")).contains(INVISIBLE)
	var pages: Array[WgEventPage] = []
	for page: Dictionary in event.get("pages", []):
		pages.append(build_page(page))
	node.pages = pages
	var sprite := WgCharacterSprite.new()
	sprite.name = "Sprite"
	node.add_child(sprite)
	return node


func build_page(page: Dictionary) -> WgEventPage:
	var made := WgEventPage.new()
	made.condition = condition_of(page.get("condition", {}))
	var graphic: Dictionary = page.get("graphic", {})
	var sheet := str(graphic.get("character_name", ""))
	if not sheet.is_empty():
		made.sheet = texture_of.call(sheet_path(sheet))
		if made.sheet == null:
			problems.append("no character sheet %s" % sheet_path(sheet))
	made.direction = DIRECTIONS.get(int(graphic.get("direction", 2)), Vector2i.DOWN)
	made.pattern = int(graphic.get("pattern", 0))
	made.opacity = int(graphic.get("opacity", 255)) / 255.0
	made.trigger = clampi(int(page.get("trigger", 0)), 0, 4) as WgEventPage.Trigger
	made.through = bool(page.get("through", false))
	made.always_on_top = bool(page.get("always_on_top", false))
	made.fixed_direction = bool(page.get("direction_fix", false))
	made.walk_animation = bool(page.get("walk_anime", true))
	made.step_animation = bool(page.get("step_anime", false))
	made.commands = build_commands(page.get("list", []))
	return made


## A page's condition as a story condition.
static func condition_of(condition: Dictionary) -> String:
	var terms: Array[String] = []
	for key: String in ["switch1", "switch2"]:
		if condition.get(key + "_valid", false):
			terms.append("switch_%d" % int(condition.get(key + "_id", 0)))
	if condition.get("variable_valid", false):
		terms.append("variable_%d >= %d" % [int(condition.get("variable_id", 0)), int(condition.get("variable_value", 0))])
	if condition.get("self_switch_valid", false):
		terms.append("local:%s" % str(condition.get("self_switch_ch", "A")))
	return ", ".join(terms)


## RPG Maker's list as the engine's commands, one to one; a message takes
## its lines (401) with it.
func build_commands(list: Array) -> Array[WgEventCommand]:
	var built: Array[WgEventCommand] = []
	var at := 0
	while at < list.size():
		var command: Variant = list[at]
		at += 1
		if not command is Dictionary:
			continue
		var made: WgEventCommand
		if int(command.get("code", 0)) == 101:
			var text := str((command.get("parameters", [""]) as Array)[0])
			while at < list.size() and list[at] is Dictionary and int(list[at].get("code", 0)) == 401:
				text += "\n" + str((list[at].get("parameters", [""]) as Array)[0])
				at += 1
			var say := WgEventSay.new()
			say.text = messages.text_of(text)
			made = say
		else:
			made = build_command(command)
		made.indent = int((command as Dictionary).get("indent", 0))
		built.append(made)
	return built


## The text variables (`[POKE]`) scripts set in `lists`, for messages to read.
func gather_text_variables(lists: Array) -> void:
	var set_variable := RegEx.create_from_string("set_variable\\(\\s*[\"'](\\[[A-Za-z0-9_]+\\])[\"']")
	for list: Variant in lists:
		for command: Variant in list if list is Array else []:
			if command is Dictionary and int(command.get("code", 0)) in [355, 655]:
				for found: RegExMatch in set_variable.search_all(str((command.get("parameters", [""]) as Array)[0])):
					if not found.get_string(1) in messages.text_variables:
						messages.text_variables.append(found.get_string(1))


func build_command(command: Dictionary) -> WgEventCommand:
	var code := int(command.get("code", 0))
	var p: Array = command.get("parameters", [])
	match code:
		0, 404, 412, 604:
			return WgEventBlockEnd.new()
		106:
			var wait := WgEventWait.new()
			wait.seconds = int(p[0]) / 30.0
			return wait
		108, 408:
			var comment := WgEventComment.new()
			comment.text = str(p[0]) if not p.is_empty() else ""
			return comment
		111:
			var made := _condition(p)
			if made != null:
				return made
		411:
			return WgEventElse.new()
		112:
			return WgEventLoop.new()
		413:
			return WgEventRepeat.new()
		113:
			return WgEventBreak.new()
		115:
			return WgEventExit.new()
		116:
			return WgEventErase.new()
		117:
			var call := WgEventCallCommon.new()
			call.common_event = int(p[0])
			return call
		118, 119:
			var named: WgEventCommand = WgEventLabel.new() if code == 118 else WgEventJump.new()
			named.set(&"label", str(p[0]))
			return named
		121:
			var switches := WgEventSetSwitches.new()
			switches.first = int(p[0])
			switches.last = int(p[1])
			switches.on = int(p[2]) == 0
			return switches
		122:
			var made := _variables(p)
			if made != null:
				return made
		102:
			var asked := WgEventChoices.new()
			var texts: Array[String] = []
			for choice: Variant in p[0]:
				texts.append(messages.text_of(str(choice)))
			asked.choices = texts
			asked.cancel = int(p[1])
			return asked
		402:
			var when := WgEventWhen.new()
			when.choice = int(p[0])
			return when
		403:
			return WgEventWhenCancel.new()
		103:
			var number := WgEventInputNumber.new()
			number.variable = int(p[0])
			number.digits = int(p[1])
			return number
		104:
			var options := WgEventTextOptions.new()
			options.place = [WgEventTextOptions.Place.TOP, WgEventTextOptions.Place.MIDDLE, WgEventTextOptions.Place.BOTTOM][clampi(int(p[0]), 0, 2)]
			options.frame = int(p[1]) == 0
			return options
		123:
			var local := WgEventSetLocalSwitch.new()
			local.letter = str(p[0])
			local.on = int(p[1]) == 0
			return local
	var raw := WgEventRaw.new()
	raw.code = code
	raw.parameters = p
	_count_raw(code, p)
	return raw


## The method a Studio script line calls, its receiver and modules dropped:
## `ge(2).animate_from_charset([0,1],20)` is `animate_from_charset`.
func script_method(line: String) -> String:
	var found := _script_method.search(line)
	return found.get_string(1) if found != null else ""


func _condition(p: Array) -> WgEventIf:
	var made := WgEventIf.new()
	match int(p[0]):
		0:
			made.kind = WgEventIf.Kind.SWITCH
			made.number = int(p[1])
			made.on = int(p[2]) == 0
		1:
			made.kind = WgEventIf.Kind.VARIABLE
			made.number = int(p[1])
			made.against_variable = int(p[2]) != 0
			made.value = int(p[3])
			made.comparison = clampi(int(p[4]), 0, 5) as WgEventIf.Comparison
		2:
			made.kind = WgEventIf.Kind.LOCAL_SWITCH
			made.letter = str(p[1])
			made.on = int(p[2]) == 0
		3:
			made.kind = WgEventIf.Kind.TIMER
			made.value = int(p[1])
			made.on = int(p[2]) == 0
		6:
			made.kind = WgEventIf.Kind.FACING
			made.number = int(p[1])
			made.direction = DIRECTIONS.get(int(p[2]), Vector2i.DOWN)
		7:
			made.kind = WgEventIf.Kind.MONEY
			made.value = int(p[1])
			made.on = int(p[2]) == 0
		8:
			made.kind = WgEventIf.Kind.ITEM
			made.item = _item(int(p[1]))
		11:
			made.kind = WgEventIf.Kind.KEY
			made.action = BUTTONS.get(int(p[1]), &"ui_accept")
		_:
			var what: String = "script %s" % script_method(str(p[1])) if int(p[0]) == 12 else ["actor", "enemy", "", "", "", "", "weapon", "armor"][clampi(int(p[0]) - 4, 0, 7)] + " condition"
			made.kind = WgEventIf.Kind.UNSUPPORTED
			made.about = what
			raw_counts["condition: " + what] = raw_counts.get("condition: " + what, 0) + 1
	return made


func _variables(p: Array) -> WgEventSetVariables:
	var made := WgEventSetVariables.new()
	made.first = int(p[0])
	made.last = int(p[1])
	made.operation = clampi(int(p[2]), 0, 5) as WgEventSetVariables.Operation
	var Operand := WgEventSetVariables.Operand
	match int(p[3]):
		0:
			made.operand = Operand.CONSTANT
			made.value = int(p[4])
		1:
			made.operand = Operand.VARIABLE
			made.value = int(p[4])
		2:
			made.operand = Operand.RANDOM
			made.value = int(p[4])
			made.value_max = int(p[5])
		3:
			made.operand = Operand.ITEM
			made.item = _item(int(p[4]))
		6:
			made.operand = Operand.CHARACTER
			made.value = int(p[4])
			made.character_value = clampi(int(p[5]), 0, 5) as WgEventSetVariables.Of
		7:
			made.operand = Operand.GAME
			made.game_value = clampi(int(p[4]), 0, 6) as WgEventSetVariables.Game
		_:
			made.operand = Operand.UNSUPPORTED
			made.about = "actor" if int(p[3]) == 4 else "enemy"
			raw_counts["operand: " + made.about] = raw_counts.get("operand: " + made.about, 0) + 1
	return made


## The item numbered `id` in Studio, by its dbSymbol.
func _item(id: int) -> StringName:
	if _items.is_empty():
		var folder := data_folder.path_join("Studio/items")
		for file in DirAccess.get_files_at(folder) if DirAccess.dir_exists_absolute(folder) else PackedStringArray():
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(file))) if file.ends_with(".json") else null
			if parsed is Dictionary and parsed.has("id"):
				_items[int(parsed["id"])] = StringName(str(parsed.get("dbSymbol", "")))
	return _items.get(id, StringName("item_%d" % id))


func _count_raw(code: int, p: Array) -> void:
	if code in CONTINUATIONS:
		return
	var what := str(COMMANDS.get(code, "command %d" % code))
	if code == 355 and not p.is_empty():
		what = "script %s" % script_method(str(p[0]))
	raw_counts[what] = raw_counts.get(what, 0) + 1
