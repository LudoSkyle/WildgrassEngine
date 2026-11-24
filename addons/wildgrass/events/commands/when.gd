## The commands run when the choice before it at its indent took `choice`.
class_name WgEventWhen
extends WgEventCommand

@export var choice := 0


func run(running: _Run) -> bool:
	return running.take_answer(choice)
