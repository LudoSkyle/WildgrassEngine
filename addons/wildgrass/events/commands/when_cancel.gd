## The commands run when the choice before it at its indent was cancelled
## into its own answer (RPG Maker's 4).
class_name WgEventWhenCancel
extends WgEventCommand

const ANSWER := 4


func run(running: _Run) -> bool:
	return running.take_answer(ANSWER)
