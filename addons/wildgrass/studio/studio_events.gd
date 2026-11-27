## A Studio map's events (feature 10 quater): read from its RPG Maker map
## file and written as the engine's events (feature 21), one to one: every
## page, its condition, look and trigger, and every command, as the class
## the engine has for it, or kept raw until it has one.
extends RefCounted

const _Reader := preload("res://addons/wildgrass/studio/marshal_reader.gd")
const _StudioMessages := preload("res://addons/wildgrass/studio/studio_messages.gd")
const _StudioRuby := preload("res://addons/wildgrass/studio/studio_ruby.gd")
const _Studio := preload("res://addons/wildgrass/studio/studio.gd")

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
## The sound commands: the engine's kind, its folder, Studio's folder.
const EVENT_SOUNDS: Dictionary[int, Array] = {
	241: [WgEventSound.Kind.MUSIC, "music", "bgm"], 245: [WgEventSound.Kind.AMBIENCE, "ambience", "bgs"],
	249: [WgEventSound.Kind.JINGLE, "jingles", "me"], 250: [WgEventSound.Kind.EFFECT, "effects", "se"],
}
## RPG Maker's weathers by number.
const WEATHERS: Array[StringName] = [&"none", &"rain", &"storm", &"snow"]
## RPG Maker's directions.
const DIRECTIONS: Dictionary[int, Vector2i] = {2: Vector2i.DOWN, 4: Vector2i.LEFT, 6: Vector2i.RIGHT, 8: Vector2i.UP}
## RPG Maker's buttons, as Godot's input actions.
const BUTTONS: Dictionary[int, StringName] = {2: &"ui_down", 4: &"ui_left", 6: &"ui_right", 8: &"ui_up", 11: &"ui_accept", 12: &"ui_cancel", 13: &"ui_accept"}
## Event name tags.
const INVISIBLE := "invisible_"
## The extensions Studio tries, in order, for a sound named without one.
const STUDIO_SOUND_FORMATS: Array[String] = ["ogg", "mp3", "wav", "mid", "aac", "wma", "it", "xm", "mod", "s3m", "midi", "flac"]
## Those Godot plays.
const PLAYED_FORMATS: Array[String] = ["ogg", "mp3", "wav"]

## Problems met: a map file unread.
var problems: Array[String] = []
## The Studio project's `Data` folder.
var data_folder := ""
## Gives the texture of a character sheet, by its Godot path. Default: load().
var texture_of := Callable()
## Where character sheets go in the game.
var sheets_folder := "res://graphics/characters"
## Where the pictures and transition pictures the events show go.
var pictures_folder := "res://graphics/pictures"
var transitions_folder := "res://graphics/transitions"
## The commands kept raw, by what they are: "Show Text", "script give_item".
var raw_counts: Dictionary[String, int] = {}
## The words of messages and choices.
var messages: _StudioMessages
## The project's translations of Studio's Ruby scripts (feature 22): one
## `<hash>.gd` each; those still to translate in `to_translate/`. Empty:
## none read, none written.
var scripts_folder := ""
## The scripts not translated, by their hash: their files to translate.
var to_translate: Dictionary[String, bool] = {}

## A script's `ext_text(file, line)`.
var _ext_text := RegEx.create_from_string("ext_text\\((\\d+), *(\\d+)\\)")
## A script's text naming a line of Studio's files: `"19, 168 …"`.
var _text_reference := RegEx.create_from_string("\"([0-9]+),( |)([0-9]+)")
## Each Studio map's id (its RPG Maker number) and its dbSymbol, the engine's
## map id: where a transfer goes.
var map_symbols: Dictionary[int, StringName] = {}

var _reader := _Reader.new()
var _ruby := _StudioRuby.new()
var _script_method := RegEx.create_from_string("^\\s*(?:[A-Za-z_][\\w]*::)*(?:[$@]?[A-Za-z_]\\w*(?:\\([^()]*\\))?\\.)*([A-Za-z_]\\w*[?!]?)")
var _items: Dictionary[int, StringName] = {}


func _init(data: String) -> void:
	data_folder = data
	_ruby.method_of = script_method
	_ruby.use_words_of(load(_Studio.SCRIPT_CONTEXT) as Script)
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


## The names of the character sheets the events of `events` show, their
## pages and the routes in their lists; and those `lists` name in routes.
static func sheets_of(events: Array[Dictionary], lists: Array = []) -> Array[String]:
	var found: Array[String] = []
	var all_lists: Array = lists.duplicate()
	for event in events:
		for page: Dictionary in event.get("pages", []):
			var name := str((page.get("graphic", {}) as Dictionary).get("character_name", ""))
			if not name.is_empty() and not name in found:
				found.append(name)
			all_lists.append(page.get("list", []))
			all_lists.append([{"code": 209, "parameters": [0, page.get("move_route", {})]}])
	for step in _route_steps(all_lists, 41):
		var name := str((step.get("parameters", [""]) as Array)[0])
		if not name.is_empty() and not name in found:
			found.append(name)
	return found


## The names of the sound effects the routes of `lists` play.
static func effects_of(lists: Array) -> Array[String]:
	var found: Array[String] = []
	for step in _route_steps(lists, 44):
		var sound: Variant = (step.get("parameters", [{}]) as Array)[0]
		var name := str((sound as Dictionary).get("name", "")) if sound is Dictionary else ""
		if not name.is_empty() and not name in found:
			found.append(name)
	return found


## The sounds the sound commands of `lists` play: `[Studio's folder, name]`
## each, once.
static func event_sounds_of(lists: Array) -> Array[Array]:
	var found: Array[Array] = []
	for list: Variant in lists:
		for command: Variant in list if list is Array else []:
			if command is Dictionary and EVENT_SOUNDS.has(int(command.get("code", 0))):
				var sound: Variant = (command.get("parameters", [{}]) as Array)[0]
				var name := str((sound as Dictionary).get("name", "")) if sound is Dictionary else ""
				var entry := [EVENT_SOUNDS[int(command["code"])][2], name]
				if not name.is_empty() and not entry in found:
					found.append(entry)
	return found


## The pictures (231) and transition pictures (222) the commands of `lists`
## show: `[kind, name]` each (`pictures`, `transitions`), once.
static func pictures_of(lists: Array) -> Array[Array]:
	var found: Array[Array] = []
	for list: Variant in lists:
		for command: Variant in list if list is Array else []:
			if not command is Dictionary or int(command.get("code", 0)) not in [222, 231]:
				continue
			var p: Array = command.get("parameters", [])
			var entry := ["transitions" if int(command["code"]) == 222 else "pictures", str(p[0] if int(command["code"]) == 222 else p[1])]
			if not entry[1].is_empty() and not entry in found:
				found.append(entry)
	return found


## The route commands of `code` in the routes the commands of `lists` set.
static func _route_steps(lists: Array, code: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for list: Variant in lists:
		for command: Variant in list if list is Array else []:
			if command is Dictionary and int(command.get("code", 0)) == 209:
				var route: Variant = (command.get("parameters", [0, {}]) as Array)[1]
				for step: Variant in (route as Dictionary).get("list", []) if route is Dictionary else []:
					if step is Dictionary and int(step.get("code", 0)) == code:
						found.append(step)
	return found


## The file of Studio's sound `name` in its `audio/<folder>`, found as Studio
## finds it: the name as given or in lower case, then with each extension it
## knows. "" if none.
static func sound_file(data: String, folder: String, name: String) -> String:
	var path := data.path_join("../audio").simplify_path().path_join(folder)
	var files: Dictionary[String, String] = {}
	for file in DirAccess.get_files_at(path) if DirAccess.dir_exists_absolute(path) else PackedStringArray():
		files[file.to_lower()] = file
	for candidate: String in [name] + STUDIO_SOUND_FORMATS.map(func(format: String) -> String: return name + "." + format):
		if files.has(candidate.to_lower()):
			return path.path_join(files[candidate.to_lower()])
	return ""


## Picture `name` of `kind` (`pictures`, `transitions`) where the game has
## it; null, reported, if it has none.
func _picture(kind: String, name: String) -> Texture2D:
	var path := (pictures_folder if kind == "pictures" else transitions_folder).path_join(name + ".png")
	var found: Texture2D = texture_of.call(path) if texture_of.is_valid() else null
	if found == null:
		problems.append("no picture %s" % path)
	return found


## A picture command (231 to 235) as `WgEventPicture`.
func _picture_command(code: int, p: Array) -> WgEventPicture:
	var made := WgEventPicture.new()
	made.number = clampi(int(p[0]), 1, 50)
	match code:
		231, 232:
			made.action = WgEventPicture.Action.SHOW if code == 231 else WgEventPicture.Action.MOVE
			if code == 231:
				made.texture = _picture("pictures", str(p[1])) if not str(p[1]).is_empty() else null
			else:
				made.seconds = int(p[1]) / 30.0
			made.origin = clampi(int(p[2]), 0, 1) as WgEventPicture._Screen.Origin
			made.by_variables = int(p[3]) != 0
			if made.by_variables:
				made.x_variable = int(p[4])
				made.y_variable = int(p[5])
			else:
				made.position = Vector2(float(p[4]), float(p[5]))
			made.zoom = Vector2(float(p[6]), float(p[7]))
			made.opacity = float(p[8])
			made.blend = clampi(int(p[9]), 0, 2) as WgEventPicture._Screen.Blend
		233:
			made.action = WgEventPicture.Action.ROTATE
			made.speed = float(p[1])
		234:
			made.action = WgEventPicture.Action.TONE
			var tone := _four(p[1])
			made.tone = Vector4(tone[0], tone[1], tone[2], tone[3])
			made.seconds = int(p[2]) / 30.0
		235:
			made.action = WgEventPicture.Action.ERASE
	return made


## A sound command as `WgEventSound`, its file as the game has it; null
## (the command kept raw, counted) if no file Godot plays has its name.
func _sound_command(code: int, sound: Dictionary) -> WgEventSound:
	var made := WgEventSound.new()
	made.kind = EVENT_SOUNDS[code][0]
	made.volume = int(sound.get("volume", 100)) / 100.0
	made.pitch = int(sound.get("pitch", 100)) / 100.0
	var name := str(sound.get("name", ""))
	if name.is_empty():
		return made
	var source := sound_file(data_folder, EVENT_SOUNDS[code][2], name)
	if source.is_empty() or source.get_extension().to_lower() not in PLAYED_FORMATS:
		var what := "%s: a sound with no file Godot plays" % COMMANDS[code]
		raw_counts[what] = raw_counts.get(what, 0) + 1
		return null
	made.sound = StringName(source.get_file())
	return made


## RPG Maker's tone or colour: its four numbers (red, green, blue, gray or
## alpha), as Studio keeps them.
static func _four(value: Variant) -> Array[float]:
	var data: Variant = (value as Dictionary).get("data") if value is Dictionary else null
	if data is PackedByteArray and (data as PackedByteArray).size() >= 32:
		return [data.decode_double(0), data.decode_double(8), data.decode_double(16), data.decode_double(24)]
	return [0.0, 0.0, 0.0, 0.0]


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
	made.move_type = clampi(int(page.get("move_type", 0)), 0, 3) as WgEventPage.MoveType
	made.move_speed = clampi(int(page.get("move_speed", 3)), 1, 6)
	made.move_frequency = clampi(int(page.get("move_frequency", 3)), 1, 6)
	if made.move_type == WgEventPage.MoveType.ROUTE and page.get("move_route") is Dictionary:
		made.move_route = build_route(page["move_route"])
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
		# A route's lines repeat its steps for the editor: the route has them.
		if not command is Dictionary or int(command.get("code", 0)) == 509:
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
		elif int(command.get("code", 0)) == 355:
			var lines := [str((command.get("parameters", [""]) as Array)[0])]
			var next := at
			while next < list.size() and list[next] is Dictionary and int(list[next].get("code", 0)) == 655:
				lines.append(str((list[next].get("parameters", [""]) as Array)[0]))
				next += 1
			var source := translated("\n".join(lines), false)
			if source.is_empty():
				made = build_command(command)
			else:
				var script := WgEventScript.new()
				script.source = source
				made = script
				at = next
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
		209:
			var move := WgEventMoveRoute.new()
			move.character = int(p[0])
			move.route = build_route(p[1] if p[1] is Dictionary else {})
			return move
		210:
			return WgEventWaitForMoves.new()
		201:
			var transfer := _transfer(p)
			if transfer != null:
				return transfer
		202:
			var place := WgEventSetEventLocation.new()
			place.character = int(p[0])
			place.mode = clampi(int(p[1]), 0, 2) as WgEventSetEventLocation.Mode
			match place.mode:
				WgEventSetEventLocation.Mode.CELL:
					place.cell = Vector2i(int(p[2]), int(p[3]))
				WgEventSetEventLocation.Mode.VARIABLES:
					place.x_variable = int(p[2])
					place.y_variable = int(p[3])
				WgEventSetEventLocation.Mode.SWAP:
					place.other = int(p[2])
			place.direction = DIRECTIONS.get(int(p[4]), Vector2i.ZERO)
			return place
		203:
			var scrolled := WgEventScrollMap.new()
			scrolled.direction = DIRECTIONS.get(int(p[0]), Vector2i.DOWN)
			scrolled.cells = int(p[1])
			scrolled.speed = clampi(int(p[2]), 1, 6)
			return scrolled
		221:
			return WgEventFreezeScreen.new()
		222:
			var shown := WgEventScreenTransition.new()
			if not str(p[0]).is_empty():
				shown.texture = _picture("transitions", str(p[0]))
			return shown
		223:
			var toned := WgEventScreenTone.new()
			var tone := _four(p[0])
			toned.tone = Vector4(tone[0], tone[1], tone[2], tone[3])
			toned.seconds = int(p[1]) / 30.0
			return toned
		224:
			var flashed := WgEventScreenFlash.new()
			var color := _four(p[0])
			flashed.color = Color(color[0] / 255.0, color[1] / 255.0, color[2] / 255.0, color[3] / 255.0)
			flashed.seconds = int(p[1]) / 30.0
			return flashed
		225:
			var shaken := WgEventScreenShake.new()
			shaken.power = clampi(int(p[0]), 1, 9)
			shaken.speed = clampi(int(p[1]), 1, 9)
			shaken.seconds = int(p[2]) / 30.0
			return shaken
		231, 232, 233, 234, 235:
			return _picture_command(code, p)
		236:
			var weather := WgEventWeather.new()
			weather.weather = WEATHERS[clampi(int(p[0]), 0, WEATHERS.size() - 1)]
			weather.power = int(p[1])
			weather.seconds = int(p[2]) / 30.0
			return weather
		241, 245, 249, 250:
			var sound := _sound_command(code, p[0] if p[0] is Dictionary else {})
			if sound != null:
				return sound
			# Counted by what it lacks.
			var kept := WgEventRaw.new()
			kept.code = code
			kept.parameters = p
			return kept
		242, 246:
			var faded := WgEventFadeSound.new()
			faded.kind = WgEventFadeSound.Kind.MUSIC if code == 242 else WgEventFadeSound.Kind.AMBIENCE
			faded.seconds = float(p[0])
			return faded
		247:
			return WgEventMemorizeSound.new()
		248:
			return WgEventRestoreSound.new()
		251:
			return WgEventStopEffects.new()
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


## Transfer Player: to a map by its id, or by variables; null (kept raw) for a
## map the project does not have.
func _transfer(p: Array) -> WgEventTransfer:
	var made := WgEventTransfer.new()
	if int(p[0]) == 0:
		made.map = map_symbols.get(int(p[1]), &"")
		if made.map.is_empty():
			raw_counts["Transfer Player to a map not in the project"] = raw_counts.get("Transfer Player to a map not in the project", 0) + 1
			return null
		made.cell = Vector2i(int(p[2]), int(p[3]))
	else:
		made.by_variables = true
		made.map_variable = int(p[1])
		made.x_variable = int(p[2])
		made.y_variable = int(p[3])
	made.direction = DIRECTIONS.get(int(p[4]), Vector2i.ZERO)
	made.transition = &"dissolve" if int(p[5]) == 0 else &"none"
	return made


## The GDScript of Studio's Ruby `ruby`, a condition's (`condition`) or
## a script's lines: the project's translation, else the importer's own; ""
## if neither, its file to translate written.
func translated(ruby: String, condition: bool) -> String:
	var name := hash_of(ruby)
	var own := scripts_folder.path_join(name + ".gd")
	if not scripts_folder.is_empty() and FileAccess.file_exists(own):
		var body := body_of(FileAccess.get_file_as_string(own), condition)
		if not body.is_empty():
			_keep_texts_of(body)
			return body
		problems.append("%s: no %s() to take" % [own, "check" if condition else "run"])
	var made := _ruby.condition(ruby) if condition else _ruby.statements(ruby)
	if not made.is_empty():
		_keep_texts_of(made)
		return made
	_write_to_translate(name, ruby, condition)
	return ""


## Gives each `ext_text(file, line)` of `script`, and each of its texts
## naming a line of Studio's files (`"19, 168 …"`), its key in the messages'
## words.
func _keep_texts_of(script: String) -> void:
	for found in _ext_text.search_all(script):
		messages.text_key(found.get_string(1).to_int(), found.get_string(2).to_int())
	for found in _text_reference.search_all(script):
		messages.text_key(found.get_string(1).to_int(), found.get_string(3).to_int())


## The name of the translation of `ruby`: the first 12 hex of its SHA-1.
static func hash_of(ruby: String) -> String:
	return ruby.sha1_text().substr(0, 12)


## The body of `func run()` (or, `condition`, the expression `func check()`
## returns) in a translation's text; "" if it has none.
static func body_of(text: String, condition: bool) -> String:
	var lines := text.split("\n")
	var start := -1
	for index in lines.size():
		if lines[index].begins_with("func check(" if condition else "func run("):
			start = index + 1
			break
	if start < 0:
		return ""
	var body: Array[String] = []
	for index in range(start, lines.size()):
		var line := lines[index]
		if not line.is_empty() and not line.begins_with("\t"):
			break
		body.append(line.trim_prefix("\t"))
	while not body.is_empty() and body[-1].strip_edges().is_empty():
		body.pop_back()
	var joined := "\n".join(body)
	if condition:
		return joined.trim_prefix("return ").strip_edges() if joined.begins_with("return ") else ""
	return joined


func _write_to_translate(name: String, ruby: String, condition: bool) -> void:
	to_translate[name] = true
	if scripts_folder.is_empty():
		return
	var folder := scripts_folder.path_join("to_translate")
	var path := folder.path_join(name + ".gd")
	if FileAccess.file_exists(path):
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var text := "extends \"%s\"\n# Studio's script, in Ruby, to translate: write its GDScript below with\n# Studio's words, then move this file up a folder.\n#\n" % _Studio.SCRIPT_CONTEXT
	for line in ruby.split("\n"):
		text += ("#   " + line).strip_edges(false, true) + "\n"
	text += "\n\nfunc check():\n\treturn false\n" if condition else "\n\nfunc run() -> void:\n\tpass\n"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)


## RPG Maker's move route as the engine's: each step but the end marker.
func build_route(route: Dictionary) -> WgMoveRoute:
	var made := WgMoveRoute.new()
	made.repeat = bool(route.get("repeat", false))
	made.skippable = bool(route.get("skippable", false))
	for command: Variant in route.get("list", []):
		if not command is Dictionary or int(command.get("code", 0)) <= 0 or int(command.get("code", 0)) > WgMoveStep.Kind.CALL:
			continue
		var step := WgMoveStep.new()
		step.kind = int(command["code"]) as WgMoveStep.Kind
		var p: Array = command.get("parameters", [])
		match step.kind:
			WgMoveStep.Kind.JUMP:
				step.offset = Vector2i(int(p[0]), int(p[1]))
			WgMoveStep.Kind.WAIT, WgMoveStep.Kind.SWITCH_ON, WgMoveStep.Kind.SWITCH_OFF, WgMoveStep.Kind.SPEED, \
					WgMoveStep.Kind.FREQUENCY, WgMoveStep.Kind.OPACITY, WgMoveStep.Kind.BLENDING:
				step.value = int(p[0])
			WgMoveStep.Kind.GRAPHIC:
				var sheet := str(p[0])
				step.sheet = texture_of.call(sheet_path(sheet)) if not sheet.is_empty() else null
				step.direction = DIRECTIONS.get(int(p[2]), Vector2i.DOWN)
				step.pattern = int(p[3])
			WgMoveStep.Kind.SOUND:
				var sound: Dictionary = p[0] if p[0] is Dictionary else {}
				var source := sound_file(data_folder, "se", str(sound.get("name", "")))
				if source.is_empty() or source.get_extension().to_lower() not in PLAYED_FORMATS:
					raw_counts["route: a sound with no file Godot plays"] = raw_counts.get("route: a sound with no file Godot plays", 0) + 1
				else:
					step.sound = StringName(source.get_file())
				step.volume = int(sound.get("volume", 100))
				step.pitch = int(sound.get("pitch", 100))
			WgMoveStep.Kind.CALL:
				step.call = translated(str(p[0]), false)
				if step.call.is_empty():
					step.original = str(p[0])
					var what := "route script %s" % script_method(step.original)
					raw_counts[what] = raw_counts.get(what, 0) + 1
		made.steps.append(step)
	return made


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
		12:
			var source := translated(str(p[1]), true)
			if source.is_empty():
				made.kind = WgEventIf.Kind.UNSUPPORTED
				made.about = "script %s" % script_method(str(p[1]))
				raw_counts["condition: " + made.about] = raw_counts.get("condition: " + made.about, 0) + 1
			else:
				made.kind = WgEventIf.Kind.SCRIPT
				made.source = source
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
