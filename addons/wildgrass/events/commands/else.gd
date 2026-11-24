## The other branch of the condition at the same indent: runs when it did not
## hold, else is skipped.
class_name WgEventElse
extends WgEventCommand


func run(running: _Run) -> bool:
	return running.take_branch(false)
