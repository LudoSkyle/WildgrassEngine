## The pause menu: its entries, in order, each shown while its story condition
## holds, and the `menu` screen that lists them.
extends RefCounted

const Log := preload("res://addons/wildgrass/core/log/log.gd")
const ScreenRegistry := preload("res://addons/wildgrass/core/screens/screen_registry.gd")
const Story := preload("res://addons/wildgrass/story/story.gd")

@warning_ignore("shadowed_global_identifier")
var log: Log
## False keeps the menu shut: a scene sets it back. Not saved.
var enabled := true
## The entry under the cursor, kept from one opening to the next.
var cursor: StringName = &""
## What the screens the menu opens are given: the services, by name.
var services := {}
## The menu's screen while it is open.
var screen: WgScreen

var _screens: ScreenRegistry
var _story: Story
## Each {"id", "text", "callable", "condition"}, in order.
var _entries: Array[Dictionary] = []


func _init(logger: Log, screen_registry: ScreenRegistry, story: Story) -> void:
	log = logger
	_screens = screen_registry
	_story = story


## Adds an entry before `before` (the last one if it is not there). Its
## callable is awaited and returns true to close the menu. An id taken
## again replaces that entry where it stands.
func add_entry(id: StringName, text: String, callable: Callable, condition := "", before: StringName = &"exit") -> void:
	var entry := {"id": id, "text": text, "callable": callable, "condition": condition}
	var at := _index(id)
	if at >= 0:
		_entries[at] = entry
		return
	var place := _index(before)
	if place < 0:
		_entries.append(entry)
	else:
		_entries.insert(place, entry)


func remove_entry(id: StringName) -> bool:
	var at := _index(id)
	if at < 0:
		return false
	_entries.remove_at(at)
	return true


## Every entry's id, in order.
func entries() -> Array[StringName]:
	var ids: Array[StringName] = []
	for entry: Dictionary in _entries:
		ids.append(entry["id"])
	return ids


## The entries whose condition holds now, in order.
func shown() -> Array[Dictionary]:
	return _entries.filter(func(entry: Dictionary) -> bool: return _story.check(entry["condition"]))


## Opens the `menu` screen, unless it is shut or a screen is open. Null if not.
func open() -> WgScreen:
	if not enabled or not _screens.stack().is_empty():
		return null
	var args := services.duplicate()
	args["menu"] = self
	screen = _screens.open(&"menu", args)
	return screen


## Opens a screen with the services, the menu hidden beneath it, and waits
## until it closes: an entry's work.
func show_screen(screen_name: StringName, args := {}) -> WgScreen:
	var given := services.duplicate()
	given.merge(args, true)
	var opened := _screens.open(screen_name, given)
	await _while_open(opened)
	return opened


## Hides the menu while `opened` shows.
func _while_open(opened: WgScreen) -> void:
	if opened == null or opened.is_closed():
		return
	var menu_screen := screen if is_instance_valid(screen) else null
	if menu_screen != null:
		menu_screen.visible = false
	await opened.closed
	if is_instance_valid(menu_screen):
		menu_screen.visible = true


func _index(id: StringName) -> int:
	for index in _entries.size():
		if _entries[index]["id"] == id:
			return index
	return -1


## The engine's entries.
func open_bag() -> bool:
	await show_screen(&"bag")
	return false


func open_options() -> bool:
	await show_screen(&"options")
	return false


func open_save() -> bool:
	var saved := [false]
	var opened := _screens.open(&"save", services)
	if opened == null:
		return false
	opened.done.connect(func(written: bool) -> void: saved[0] = written)
	await _while_open(opened)
	return saved[0]


func exit() -> bool:
	return true
