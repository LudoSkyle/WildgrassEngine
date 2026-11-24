## Shows a message (a text, or a key the game's translations give), and
## waits until it is read. Followed at once by a `WgEventChoices` or a
## `WgEventInputNumber`, it is their question. One message at a time: while
## another list's message is under way, it waits its turn.
class_name WgEventSay
extends WgEventCommand

@export_multiline var text := ""


func run(running: _Run) -> bool:
	if running.message_busy():
		return false
	var next: WgEventCommand = running.list[running.index + 1] if running.index + 1 < running.list.size() else null
	if next is WgEventChoices:
		running.index += 1
		(next as WgEventChoices).ask(running, text)
	elif next is WgEventInputNumber:
		running.index += 1
		(next as WgEventInputNumber).ask(running, text)
	else:
		running.say(text)
	return true
