## Runs a script (feature 22): GDScript lines in the project's script words,
## the list waiting until they end (`await` allowed: a message, a choice, a
## walk). One that does not compile is logged and skipped.
class_name WgEventScript
extends WgEventCommand

@export_multiline var source := ""


func run(running: _Run) -> bool:
	running.run_script(source)
	return true
