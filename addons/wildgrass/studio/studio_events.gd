## A Studio map's events (feature 10 quater): read from its RPG Maker map
## file, sorted into the forms the engine's own nodes say (a door, a
## character, a sign, an item found, a still sprite), and every other one
## told with why, to be rewritten by hand.
extends RefCounted

const _Reader := preload("res://addons/wildgrass/studio/marshal_reader.gd")

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
## Commands that only show or sound something, or wait: a door keeps going
## without them. Comments, a list's end and the lines that continue a
## command (401, 408, 509, 655) go with them.
const COSMETIC: Array[int] = [0, 106, 108, 408, 209, 509, 210, 221, 222, 223, 224, 225, 241, 242, 245, 246, 249, 250, 251]
## Commands that change the game's state: noted when a door drops them.
const STATE: Array[int] = [117, 121, 122, 123]
## Studio's scripts that only show something, by their method's name.
const COSMETIC_SCRIPTS: Array[String] = ["smart_disable", "smart_enable", "leave_cycling_state", "enter_in_walking_state", "animate_from_charset"]
## Scripts that change the game's state, noted when a door drops them.
const STATE_SCRIPTS: Array[String] = ["set_self_switch"]
## Scripts that give an item found.
const ITEM_SCRIPTS: Array[String] = ["pick_item", "give_item"]
const WORDS: Array[int] = [0, 101, 401, 108, 408]
## RPG Maker's triggers.
const ACTION := 0
const AUTORUN := 3
## Event name tags.
const NO_SPRITE := "[sprite=off]"
const INVISIBLE := "invisible_"

## The forms, and the step of the importer that writes each.
const FORMS: Dictionary[String, String] = {
	"door": "doors", "character": "characters and signs", "sign": "characters and signs",
	"still": "characters and signs", "item": "items found", "nothing": "",
}

## Problems met: a map file unread.
var problems: Array[String] = []
## The Studio project's `Data` folder.
var data_folder := ""

var _reader := _Reader.new()
var _script_method := RegEx.create_from_string("^\\s*(?:[A-Za-z_][\\w]*::)*(?:[$@]?[A-Za-z_]\\w*(?:\\([^()]*\\))?\\.)*([A-Za-z_]\\w*[?!]?)")


func _init(data: String) -> void:
	data_folder = data


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


## The method a Studio script line calls, its receiver and modules dropped:
## `ge(2).animate_from_charset([0,1],20)` is `animate_from_charset`.
func script_method(line: String) -> String:
	var found := _script_method.search(line)
	return found.get_string(1) if found != null else ""


## What an event is: {form, notes, reason}. `form` is one of FORMS, or "" when
## it is left to be rewritten by hand, `reason` saying why; `notes` what the
## form leaves out. `blocked`: whether its cell's passages block every side.
func classify(event: Dictionary, blocked: bool) -> Dictionary:
	var pages: Array = event.get("pages", [])
	if pages.is_empty():
		return {"form": "nothing", "notes": [], "reason": ""}
	var name := str(event.get("name", ""))
	var first: Dictionary = pages[0]
	var door := _door(event, blocked)
	if not door.is_empty():
		return door
	if pages.size() > 1:
		return _by_hand("%d pages" % pages.size())
	if _has_condition(first):
		return _by_hand("a page condition")
	var codes := _codes(first)
	var graphic := _has_graphic(first) and not name.contains(NO_SPRITE)
	if codes.all(func(code: int) -> bool: return code in [0, 108, 408]):
		return {"form": "still" if graphic else "nothing", "notes": [], "reason": ""}
	if int(first.get("trigger", ACTION)) != ACTION:
		return _by_hand("its trigger (%s)" % _trigger_name(int(first.get("trigger", ACTION))))
	if codes.all(func(code: int) -> bool: return code in WORDS):
		return {"form": "character" if graphic else "sign", "notes": [], "reason": ""}
	var methods := _scripts(first)
	if not methods.is_empty() and methods.all(func(method: String) -> bool: return method in ITEM_SCRIPTS) \
			and codes.all(func(code: int) -> bool: return code in WORDS or code == 355 or code == 655):
		return {"form": "item", "notes": [], "reason": ""}
	return _by_hand(_first_unknown(first, WORDS, []))


## The event as a door, or {}: one page that moves the player to a map (its
## other pages only playing its arrival), and nothing else than showing,
## sounding, waiting and moving; what changes the game's state is noted.
func _door(event: Dictionary, blocked: bool) -> Dictionary:
	var pages: Array = event.get("pages", [])
	var first: Dictionary = pages[0]
	var transfers := (first.get("list", []) as Array).filter(func(command: Dictionary) -> bool: return command.get("code") == 201)
	if transfers.size() != 1 or _has_condition(first) or int(first.get("trigger", ACTION)) in [AUTORUN, 4]:
		return {}
	if int(first.get("trigger", ACTION)) == ACTION:
		return _by_hand("a transfer on the action key")
	var parameters: Array = transfers[0].get("parameters", [])
	if parameters.size() < 6 or int(parameters[0]) != 0:
		return _by_hand("a transfer to a place held in variables") if parameters.size() >= 6 else {}
	var notes: Array[String] = []
	var unknown := _first_unknown(first, COSMETIC + STATE + [201], COSMETIC_SCRIPTS + STATE_SCRIPTS)
	if not unknown.is_empty():
		return _by_hand("a transfer, and %s" % unknown)
	notes.append_array(_state_notes(first))
	for index in range(1, pages.size()):
		var page: Dictionary = pages[index]
		var condition: Dictionary = page.get("condition", {})
		var arrival: bool = int(page.get("trigger", ACTION)) == AUTORUN and condition.get("self_switch_valid", false) \
			and not condition.get("switch1_valid", false) and not condition.get("switch2_valid", false) \
			and not condition.get("variable_valid", false) \
			and _first_unknown(page, COSMETIC + [123], COSMETIC_SCRIPTS).is_empty()
		if not arrival:
			return _by_hand("a transfer, and a page %d that is not its arrival" % (index + 1))
		notes.append("its arrival page %d" % (index + 1))
	var graphic := _has_graphic(first) and not str(event.get("name", "")).contains(NO_SPRITE)
	var bumped: bool = (graphic and not first.get("through", false)) or str(event.get("name", "")).contains(INVISIBLE) or blocked
	return {"form": "door", "notes": notes, "reason": "", "map": int(parameters[1]), "cell": Vector2i(int(parameters[2]), int(parameters[3])),
		"direction": int(parameters[4]), "bumped": bumped, "graphic": graphic}


func _state_notes(page: Dictionary) -> Array[String]:
	var notes: Array[String] = []
	for command: Dictionary in page.get("list", []):
		var code := int(command.get("code", 0))
		var parameters: Array = command.get("parameters", [])
		match code:
			117:
				notes.append("calls common event %d" % int(parameters[0]))
			121:
				notes.append("sets switch %s" % _range(parameters))
			122:
				notes.append("sets variable %s" % _range(parameters))
			123:
				notes.append("sets its self switch %s" % str(parameters[0]))
			355, 655:
				if script_method(str(parameters[0])) in STATE_SCRIPTS:
					notes.append("sets another event's self switch")
	var once: Array[String] = []
	for note in notes:
		if not note in once:
			once.append(note)
	return once


static func _range(parameters: Array) -> String:
	return str(parameters[0]) if parameters[0] == parameters[1] else "%s to %s" % [parameters[0], parameters[1]]


## The first command of `page` neither in `codes` nor a script whose method
## is in `methods`, named; "" if none.
func _first_unknown(page: Dictionary, codes: Array, methods: Array) -> String:
	for command: Dictionary in page.get("list", []):
		var code := int(command.get("code", 0))
		if code == 355 or code == 655:
			var method := script_method(str((command.get("parameters", [""]) as Array)[0]))
			if not method in methods:
				return "a script (%s)" % method if not method.is_empty() else "a script"
		elif code in [401, 408, 509]:
			continue
		elif not code in codes:
			return "a command %d (%s)" % [code, COMMANDS.get(code, "unknown")]
	return ""


func _scripts(page: Dictionary) -> Array[String]:
	var methods: Array[String] = []
	for command: Dictionary in page.get("list", []):
		if int(command.get("code", 0)) == 355:
			methods.append(script_method(str((command.get("parameters", [""]) as Array)[0])))
	return methods


static func _codes(page: Dictionary) -> Array:
	return (page.get("list", []) as Array).map(func(command: Dictionary) -> int: return int(command.get("code", 0)))


static func _has_condition(page: Dictionary) -> bool:
	var condition: Dictionary = page.get("condition", {})
	for key: String in ["switch1_valid", "switch2_valid", "variable_valid", "self_switch_valid"]:
		if condition.get(key, false):
			return true
	return false


static func _has_graphic(page: Dictionary) -> bool:
	var graphic: Dictionary = page.get("graphic", {})
	return not str(graphic.get("character_name", "")).is_empty() or int(graphic.get("tile_id", 0)) > 0


static func _trigger_name(trigger: int) -> String:
	return ["action", "player touch", "event touch", "autorun", "parallel"][trigger] if trigger >= 0 and trigger <= 4 else str(trigger)


static func _by_hand(reason: String) -> Dictionary:
	return {"form": "", "notes": [], "reason": reason}
