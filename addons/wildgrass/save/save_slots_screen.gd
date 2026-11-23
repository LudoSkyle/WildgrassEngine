## The choice of a game: a card per slot, from its summary. On a game,
## Continue or Erase; on a free slot, New game; on a damaged file, Erase. The
## engine's scene uses Godot's default theme; a game's scene extends it and
## changes how it looks, not what it does: its layout settings, its cards
## (`_make_card()`, `_show_selected()`), its questions (`_ask_…()`). It points
## `wildgrass/screens/save_slots` to it.
##
## `Wildgrass.screens.open(&"save_slots")`; arguments: `save`, `dialogue`,
## `texts`, the services (the engine's); `new_game` and `continue`, callables
## given a slot and awaited, true when the game started, in place of the save
## service's (the title's fade); `open_options`, a callable awaited, for the
## Options card.
class_name WgSaveSlotsScreen
extends WgScreen

const _Save := preload("res://addons/wildgrass/save/save.gd")
const _Dialogue := preload("res://addons/wildgrass/dialogue/dialogue.gd")
const _Texts := preload("res://addons/wildgrass/texts/texts.gd")

## The slot of the Options card.
const OPTIONS_CARD := -1

## What was done: `continue` or `new_game` (the screen then closes), `erase`,
## or `cancel` (slot 0, the screen closes).
signal chosen(slot: int, action: StringName)

@export_group("Layout")
## True: left and right move along a row; false: up and down.
@export var horizontal := false
## True: from the last card, the first.
@export var wrap := false
## `each_free`: a card per free slot, in the slots' order. `first_free`: the
## games, then one card for the first free slot, gone when every slot is
## taken.
@export_enum("each_free", "first_free") var new_game_card := "each_free"
## True, with `open_options` given: an Options card, last; back from it, the
## cards are written again, in the language chosen.
@export var options_card := false

@export_group("Nodes")
## The `ScrollContainer` of the cards.
@export var scroll: NodePath = ^"Cards"
## The container the cards are added to.
@export var list: NodePath = ^"Cards/List"

@export_group("Texts")
## A card holding a game: `{slot}`, `{place}`, `{time}`, and what the game
## added to the summary (`{name}`…).
@export_multiline var card_text := "wg.slots.card"
@export_multiline var empty_card_text := "wg.slots.empty_card"
@export_multiline var damaged_card_text := "wg.slots.damaged_card"
@export var options_card_text := "wg.slots.options"
@export var continue_choice := "wg.slots.continue"
@export var new_game_choice := "wg.slots.new_game"
@export var erase_choice := "wg.slots.erase"
@export var cancel_choice := "wg.cancel"
## `{slot}`: the file's.
@export_multiline var erase_text := "wg.slots.erase_question"
@export_multiline var failed_text := "wg.slots.load_failed"

var save: _Save
var dialogue: _Dialogue
var texts: _Texts
## The slots of the cards, in order; `OPTIONS_CARD` for the Options card.
var slots: Array[int] = []
## The index of the card under the cursor.
var cursor := 0

var _cards: Array[Control] = []
var _busy := false
var _ended := false
var _new_game: Callable
var _continue: Callable
var _open_options: Callable


func _on_open(args: Dictionary) -> void:
	save = _service(args, &"save")
	dialogue = _service(args, &"dialogue")
	texts = _service(args, &"texts")
	_new_game = args.get("new_game", Callable())
	_continue = args.get("continue", Callable())
	_open_options = args.get("open_options", Callable())
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
	elif dialogue.is_action(event, "left" if horizontal else "up"):
		_move(-1)
	elif dialogue.is_action(event, "right" if horizontal else "down"):
		_move(1)
	else:
		return false
	return true


## The slot under the cursor; `OPTIONS_CARD` on the Options card.
func selected() -> int:
	return slots[cursor] if cursor < slots.size() else 0


## Builds the cards again from the files.
func refresh() -> void:
	slots = _card_slots()
	var box := get_node_or_null(list)
	for card in _cards:
		card.queue_free()
		if card.get_parent() != null:
			card.get_parent().remove_child(card)
	_cards.clear()
	for number in slots:
		var card := _make_card(number, {} if number == OPTIONS_CARD else save.summary(number))
		_cards.append(card)
		if box != null:
			box.add_child(card)
	cursor = clampi(cursor, 0, maxi(slots.size() - 1, 0))
	_show_cursor()


## The text of a slot's card.
func card_of(number: int) -> String:
	if number == OPTIONS_CARD:
		return texts.label(options_card_text)
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


## The card of a slot: `summary` is `{}` for a free slot, `{"damaged": true}`
## for a file that cannot be read; `OPTIONS_CARD` is the Options card. The
## engine's is a button with `card_of()`.
func _make_card(number: int, _summary: Dictionary) -> Control:
	var card := Button.new()
	card.text = card_of(number)
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.toggle_mode = true
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return card


## Shows `card` under the cursor or not; the engine's presses its button.
func _show_selected(card: Control, is_selected: bool) -> void:
	if card is Button:
		(card as Button).set_pressed_no_signal(is_selected)


## Asked on a free slot: true starts a new game there.
func _ask_new_game(number: int) -> bool:
	return await dialogue.ask(card_of(number), [new_game_choice, cancel_choice]) == 0


## Asked on a game: `continue`, `erase` or `cancel`; a damaged file may only
## be erased.
func _ask_action(number: int) -> StringName:
	var damaged: bool = save.summary(number).get("damaged", false)
	var actions: Array[StringName] = [&"erase", &"cancel"]
	if not damaged:
		actions.push_front(&"continue")
	var labels := {&"continue": continue_choice, &"erase": erase_choice, &"cancel": cancel_choice}
	var picked := await dialogue.ask(card_of(number), actions.map(func(action: StringName) -> String: return labels[action]))
	return actions[picked] if picked >= 0 else &"cancel"


## Asked before erasing a game, No under the cursor: true erases it.
func _ask_erase(number: int) -> bool:
	return await dialogue.confirm(erase_text, {"default": 1, "values": {"slot": str(number)}})


## The slots to show cards for, as the settings say.
func _card_slots() -> Array[int]:
	var shown: Array[int] = []
	var free := 0
	for number in save.slots():
		if save.has(number) or new_game_card == "each_free":
			shown.append(number)
		elif free == 0:
			free = number
	if free > 0 and new_game_card == "first_free":
		shown.append(free)
	if options_card and _open_options.is_valid():
		shown.append(OPTIONS_CARD)
	return shown


func _move(step: int) -> void:
	if slots.is_empty():
		return
	cursor = wrapi(cursor + step, 0, slots.size()) if wrap else clampi(cursor + step, 0, slots.size() - 1)
	_show_cursor()


func _show_cursor() -> void:
	for index in _cards.size():
		_show_selected(_cards[index], index == cursor)
	var container := get_node_or_null(scroll) as ScrollContainer
	if container != null and cursor < _cards.size() and _cards[cursor].is_inside_tree():
		container.ensure_control_visible(_cards[cursor])


func _act() -> void:
	var number := selected()
	if number == 0:
		return
	_busy = true
	if number == OPTIONS_CARD:
		await _open_options.call()
		if not is_closed():
			refresh()
		_busy = false
		return
	if save.summary(number).is_empty():
		if await _ask_new_game(number) and await _start_new(number):
			_end(number, &"new_game")
		_busy = false
		return
	match await _ask_action(number):
		&"continue":
			if await _load(number):
				_busy = false
				_end(number, &"continue")
				return
			await dialogue.say(failed_text)
		&"erase":
			if await _ask_erase(number):
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
