## A command the engine has no class for yet, kept as RPG Maker holds it:
## its code and parameters. Running it logs it once and goes on.
class_name WgEventRaw
extends WgEventCommand

@export var code := 0
@export var parameters: Array = []


func run(running: _Run) -> bool:
	running.unsupported("command %d" % code)
	return true
