## The debug tools, in pages: the engine's (page `engine`) and the game's
## (page `game`, where a game's tools go by default), each a line of the
## first page. The pause menu's Debug entry opens them when the `debug`
## config allows.
extends RefCounted

const Log := preload("res://addons/wildgrass/core/log/log.gd")
const ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const ScreenRegistry := preload("res://addons/wildgrass/core/screens/screen_registry.gd")

## The first page: the lines leading to the engine's and the game's.
const FIRST := &"first"
const ENGINE := &"engine"
const GAME := &"game"

@warning_ignore("shadowed_global_identifier")
var log: Log
## Given to the `debug` screen and to what it opens: the services, by name.
var services := {}

var _config: ConfigRegistry
var _screens: ScreenRegistry
## Each {"id", "page", "label", "action", "shown", "opens", "lines"}, in
## order; a page's line has `opens`, the page it leads to.
var _entries: Array[Dictionary] = []
## What runs once the tools and the pause menu are closed: a tool's message.
var _pending: Array[Callable] = []


func _init(logger: Log, config_registry: ConfigRegistry, screen_registry: ScreenRegistry) -> void:
	log = logger
	_config = config_registry
	_screens = screen_registry
	_entries.append(_entry(ENGINE, "Engine", Callable(), {"page": FIRST}, ENGINE))
	_entries.append(_entry(GAME, "Game", Callable(), {"page": FIRST, "shown": _has_game_tools}, GAME))


func config() -> WgDebugConfig:
	return _config.get_config(&"debug") as WgDebugConfig


## True if the Debug entry shows: the config's `enabled`, `auto` meaning a
## debug build.
func is_enabled() -> bool:
	match config().enabled:
		"true":
			return true
		"false":
			return false
	return _is_debug_build()


## A tool: `label` a text (translated) or a callable giving it (shown as
## given), `action` awaited, returning true to keep the page open. Options:
## `page` (`game` by default), `before` (a tool of that page), `shown` (a
## callable; false hides the line). An id taken again replaces that tool.
func add_tool(id: StringName, label: Variant, action: Callable, options := {}) -> void:
	_add(_entry(id, label, action, options))


## A page, and its line in `page` (options as a tool's): its tools, then
## `lines` if given, a callable returning `[{label, action}]` or
## `[{label, lines}]` when the page opens.
func add_page(id: StringName, label: Variant, options := {}) -> void:
	if id in [FIRST, ENGINE, GAME]:
		log.error(&"debug", "'%s' is the engine's page" % id)
		return
	_add(_entry(id, label, Callable(), options, id))


## Takes a tool or a page away; false if there was none.
func remove_tool(id: StringName) -> bool:
	for index in _entries.size():
		if _entries[index]["id"] == id and id not in [ENGINE, GAME]:
			_entries.remove_at(index)
			return true
	return false


func has_tool(id: StringName) -> bool:
	return _entries.any(func(entry: Dictionary) -> bool: return entry["id"] == id)


## The lines `page` shows now: its tools and pages shown, then the lines its
## `lines` callable makes. Each {"id", "label", "action"} or with "opens"
## (a page) or "lines" (a page made when it opens).
func lines(page: StringName) -> Array[Dictionary]:
	var shown: Array[Dictionary] = []
	for entry in _entries:
		if entry["page"] != page:
			continue
		var visible: Callable = entry["shown"]
		if visible.is_valid() and not bool(visible.call()):
			continue
		shown.append(entry)
	for entry in _entries:
		if entry["opens"] == page and (entry["lines"] as Callable).is_valid():
			var made: Variant = (entry["lines"] as Callable).call()
			for line: Variant in made if made is Array else []:
				if line is Dictionary:
					shown.append(line)
	return shown


## What a line shows: a text translated, or what its callable gives.
func label_of(line: Dictionary, texts: Object) -> String:
	var label: Variant = line.get("label", "")
	if label is Callable:
		return str((label as Callable).call())
	return texts.label(str(label)) if texts != null else str(label)


## The page the tools open on: the first, or the engine's while the game has
## none.
func first_page() -> StringName:
	return FIRST if _has_game_tools() else ENGINE


## The title of `page`: its line's label.
func title_of(page: StringName) -> Variant:
	for entry in _entries:
		if entry["opens"] == page:
			return entry["label"]
	return "Debug"


## Runs what follows once the tools are closed: a message, a reload.
func then(callable: Callable) -> void:
	_pending.append(callable)


## Opens the `debug` screen from the pause menu and waits; true if a tool
## closed it, the pause menu closing too, then what tools asked runs.
func open_from_menu(menu: Object) -> bool:
	var args := services.duplicate()
	args["debug"] = self
	var opened: WgScreen = await menu.show_screen(&"debug", args)
	return _after(opened)


## Opens the `debug` screen alone (a game's key), unless it is open; what
## tools asked runs once it closes.
func open() -> WgScreen:
	var args := services.duplicate()
	args["debug"] = self
	if _screens.is_open(&"debug"):
		return null
	var opened := _screens.open(&"debug", args)
	if opened == null:
		return null
	if opened.is_closed():
		_after(opened)
	else:
		opened.closed.connect(_after.bind(opened), CONNECT_ONE_SHOT)
	return opened


func _after(opened: WgScreen) -> bool:
	var by_tool := opened != null and bool(opened.get(&"closed_by_tool"))
	if by_tool:
		_run_pending.call_deferred()
	else:
		_pending.clear()
	return by_tool


func _run_pending() -> void:
	var waiting := _pending.duplicate()
	_pending.clear()
	for callable: Callable in waiting:
		if callable.is_valid():
			await callable.call()


## Seam for the tests: Godot's debug build flag.
func _is_debug_build() -> bool:
	return OS.is_debug_build()


func _has_game_tools() -> bool:
	return _entries.any(func(entry: Dictionary) -> bool: return entry["page"] != FIRST and entry["page"] != ENGINE and _in_game(entry["page"]))


## True if `page` is the game's or below it.
func _in_game(page: StringName) -> bool:
	for _depth in 32:
		if page == GAME:
			return true
		if page == FIRST or page == ENGINE:
			return false
		var parent := FIRST
		for entry in _entries:
			if entry["opens"] == page:
				parent = entry["page"]
				break
		page = parent
	return false


static func _entry(id: StringName, label: Variant, action: Callable, options: Dictionary, opens: StringName = &"") -> Dictionary:
	return {
		"id": id, "label": label, "action": action, "opens": opens,
		"page": StringName(str(options.get("page", GAME))),
		"before": StringName(str(options.get("before", ""))),
		"shown": options.get("shown", Callable()),
		"lines": options.get("lines", Callable()),
	}


func _add(entry: Dictionary) -> void:
	for index in _entries.size():
		if _entries[index]["id"] == entry["id"]:
			_entries[index] = entry
			return
	var before: StringName = entry["before"]
	if not before.is_empty():
		for index in _entries.size():
			if _entries[index]["id"] == before and _entries[index]["page"] == entry["page"]:
				_entries.insert(index, entry)
				return
	_entries.append(entry)
