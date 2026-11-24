## Asks a number of `digits` digits, from 0, into variable `variable`; the
## cancel action does nothing, as RPG Maker's.
class_name WgEventInputNumber
extends WgEventCommand

@export var variable := 1
@export var digits := 1


func run(running: _Run) -> bool:
	if running.message_busy():
		return false
	ask(running, "")
	return true


func ask(running: _Run, question: String) -> void:
	running.ask_number(question, variable, int(pow(10, clampi(digits, 1, 9))) - 1)
