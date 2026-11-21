## The choice of a game: a card per slot, from its summary. On a game,
## Continue or Erase; on a free slot, New game; on a damaged file, Erase. The
## engine's scene uses Godot's default theme; a game points
## `wildgrass/screens/save_slots` to its own.
##
## `Wildgrass.screens.open(&"save_slots")`; arguments: `save`, `dialogue`,
## `texts`, the services (the engine's); `new_game` and `continue`, callables
## given a slot and awaited, true when the game started, in place of the save
## service's (the title's fade).
class_name WgSaveSlotsScreen
extends WgScreen

const Save := preload("res://addons/wildgrass/save/save.gd")
const Dialogue := preload("res://addons/wildgrass/dialogue/dialogue.gd")
const Texts := preload("res://addons/wildgrass/texts/texts.gd")

## What was done: `continue` or `new_game` (the screen then closes), `erase`,
## or `cancel` (slot 0, the screen closes).
signal chosen(slot: int, action: StringName)

@export_group("Nodes")
## The `ScrollContainer` of the cards.
@export var scroll: NodePath = ^"Cards"
## The container the cards are added to.
@export var list: NodePath = ^"Cards/List"

@export_group("Texts")
## A card holding a game: `{slot}`, `{place}`, `{time}`, and what the game
## added to the summary (`{name}`…).
@export_multiline var card_text := "File {slot}\n{place}   {time}"
@export_multiline var empty_card_text := "File {slot}\nNew game"
@export_multiline var damaged_card_text := "File {slot}\nThis file is damaged."
@export var continue_choice := "Continue"
@export var new_game_choice := "New game"
@export var erase_choice := "Erase"
@export var cancel_choice := "Cancel"
@export_multiline var erase_text := "Erase this file?"
@export_multiline var failed_text := "This file could not be loaded."

var save: Save
var dialogue: Dialogue
var texts: Texts
## The slots shown, in order.
var slots: Array[int] = []
## The index of the card under the cursor.
var cursor := 0

var _cards: Array[Button] = []
var _busy := false
var _ended := false
var _new_game: Callable
var _continue: Callable


func _on_open(args: Dictionary) -> void:
	save = _service(args, &"save")
	dialogue = _service(args, &"dialogue")
	texts = _service(args, &"texts")
	_new_game = args.get("new_game", Callable())
	_continue = args.get("continue", Callable())
	if save == null or dialogue == null or texts == null:
		push_error("save slots screen: no save, dialogue or texts service")
		close()
		return
	refresh()
	cursor = maxi(slots.find(save.slot), 0)
	_show_cursor()


func _on_input(event: InputEvent) -> bool:
	if _busy:
		return true
	if dialogue.is_action(event, "cancel"):
		_end(0, &"cancel")
	elif dialogue.is_action(event, "confirm"):
		_act()
	elif dialogue.is_action(event, "up"):
		_move(-1)
	elif dialogue.is_action(event, "down"):
		_move(1)
	else:
		return false
	return true


## The slot under the cursor.
func selected() -> int:
	return slots[cursor] if cursor < slots.size() else 0


## Builds the cards again from the files.
func refresh() -> void:
	slots = save.slots()
	var box := get_node_or_null(list)
	for card in _cards:
		card.queue_free()
		if card.get_parent() != null:
			card.get_parent().remove_child(card)
	_cards.clear()
	for number in slots:
		var card := Button.new()
		card.text = card_of(number)
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.toggle_mode = true
		card.focus_mode = Control.FOCUS_NONE
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_cards.append(card)
		if box != null:
			box.add_child(card)
	cursor = clampi(cursor, 0, maxi(slots.size() - 1, 0))
	_show_cursor()


## The text of a slot's card.
func card_of(number: int) -> String:
	var summary := save.summary(number)
	var values := summary.duplicate()
	values.merge(WgSaveScreen.describe(summary), true)
	values["slot"] = number
	var text := card_text
	if summary.is_empty():
		text = empty_card_text
	elif summary.get("damaged", false):
		text = damaged_card_text
	return texts.label(text, values)


func _move(step: int) -> void:
	cursor = clampi(cursor + step, 0, slots.size() - 1)
	_show_cursor()


func _show_cursor() -> void:
	for index in _cards.size():
		_cards[index].set_pressed_no_signal(index == cursor)
	var container := get_node_or_null(scroll) as ScrollContainer
	if container != null and cursor < _cards.size() and _cards[cursor].is_inside_tree():
		container.ensure_control_visible(_cards[cursor])


func _act() -> void:
	var number := selected()
	if number == 0:
		return
	var summary := save.summary(number)
	_busy = true
	if summary.is_empty():
		var start := await dialogue.ask(card_of(number), [new_game_choice, cancel_choice])
		if start == 0 and await _start_new(number):
			_end(number, &"new_game")
		_busy = false
		return
	var damaged: bool = summary.get("damaged", false)
	var choices: Array = [erase_choice, cancel_choice] if damaged else [continue_choice, erase_choice, cancel_choice]
	var picked := await dialogue.ask(card_of(number), choices)
	var answer: String = choices[picked] if picked >= 0 else cancel_choice
	if answer == continue_choice:
		if await _load(number):
			_busy = false
			_end(number, &"continue")
			return
		await dialogue.say(failed_text)
	elif answer == erase_choice and await dialogue.confirm(erase_text, {"default": 1}):
		save.erase(number)
		refresh()
		chosen.emit(number, &"erase")
	_busy = false


func _start_new(number: int) -> bool:
	if _new_game.is_valid():
		return await _new_game.call(number)
	save.new_game(number)
	return true


func _load(number: int) -> bool:
	if _continue.is_valid():
		return await _continue.call(number)
	return await save.load_game(number)


## Announces what was done, once, and closes: a game started by the title
## closed it already.
func _end(number: int, action: StringName) -> void:
	if _ended:
		return
	_ended = true
	chosen.emit(number, action)
	close()


func _service(args: Dictionary, key: StringName) -> Variant:
	if args.has(key):
		return args[key]
	var engine := get_node_or_null(^"/root/Wildgrass")
	return engine.get(key) if engine != null else null
