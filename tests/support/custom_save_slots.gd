## A game's choice of a game: its own cards and questions, recorded.
extends WgSaveSlotsScreen

var made: Array[String] = []
var selections: Array[String] = []
var asked: Array[String] = []
var action := &"cancel"
var erase := false


## Its cards go under the screen itself.
func _on_open(args: Dictionary) -> void:
	list = ^"."
	super(args)


func _make_card(number: int, summary: Dictionary) -> Control:
	made.append("%d %s" % [number, summary.keys()])
	var card := Label.new()
	card.name = "Card%d" % number
	return card


func _show_selected(card: Control, is_selected: bool) -> void:
	if is_selected:
		selections.append(card.name)


func _ask_new_game(number: int) -> bool:
	asked.append("new %d" % number)
	return true


func _ask_action(number: int) -> StringName:
	asked.append("action %d" % number)
	return action


func _ask_erase(number: int) -> bool:
	asked.append("erase %d" % number)
	return erase
