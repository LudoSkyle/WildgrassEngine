## Asks a choice; the `WgEventWhen` of the answer at its indent runs. On
## cancel, `cancel` says what it answers, as RPG Maker: 0 nothing, n the
## answer n - 1 (a choice, or 4: the `WgEventWhenCancel`).
class_name WgEventChoices
extends WgEventCommand

@export var choices: Array[String] = []
@export var cancel := 0


func run(running: _Run) -> bool:
	if running.message_busy():
		return false
	ask(running, "")
	return true


## Asks with `question`, the message before it.
func ask(running: _Run, question: String) -> void:
	running.ask(question, choices, cancel - 1, indent)
