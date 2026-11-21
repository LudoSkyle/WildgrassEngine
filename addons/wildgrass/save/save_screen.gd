## Saves the game, asking in the message box: which file (when the config
## lets the game write in any), whether to save, whether to overwrite a game
## already there. A summary of the game shows in a corner meanwhile. The
## engine's scene uses Godot's default theme; a game points
## `wildgrass/screens/save` to its own.
##
## `Wildgrass.screens.open(&"save")`; arguments: `save`, `dialogue`, `texts`,
## the services (the engine's).
class_name WgSaveScreen
extends WgScreen

const Save := preload("res://addons/wildgrass/save/save.gd")
const Dialogue := preload("res://addons/wildgrass/dialogue/dialogue.gd")
const Texts := preload("res://addons/wildgrass/texts/texts.gd")

## Emitted once, before the screen closes: true if the game was written.
signal done(saved: bool)

@export_group("Nodes")
## The `Label` of where the game is: its zone, else its map.
@export var place: NodePath = ^"Summary/Margin/Box/Place"
## The `Label` of the play time.
@export var time: NodePath = ^"Summary/Margin/Box/Time"

@export_group("Texts")
@export_multiline var save_text := "Would you like to save the game?"
@export_multiline var overwrite_text := "There is already a saved file. Is it OK to overwrite it?"
@export_multiline var saved_text := "The game was saved."
@export_multiline var failed_text := "The game could not be saved."
## Asked when the game may be written in any file.
@export_multiline var file_text := "Save in which file?"
## A file holding a game; `{slot}`, `{place}`, `{time}`.
@export var file_choice := "File {slot}: {place}, {time}"
## A free file; `{slot}`.
@export var new_file_choice := "File {slot}: new"
@export var cancel_choice := "Cancel"
## Seconds the saved text stays, then the screen closes by itself.
@export var saved_seconds := 1.0

var save: Save
var dialogue: Dialogue
var texts: Texts


func _on_open(args: Dictionary) -> void:
	save = _service(args, &"save")
	dialogue = _service(args, &"dialogue")
	texts = _service(args, &"texts")
	if save == null or dialogue == null or texts == null:
		push_error("save screen: no save, dialogue or texts service")
		close()
		return
	var summary: Variant = save.summary_now()
	_show_summary(summary if summary is Dictionary else {})
	_run.call_deferred()


## Where a game is and how long it was played, as a card shows them.
static func describe(summary: Dictionary) -> Dictionary:
	var where := str(summary.get("zone", ""))
	if where.is_empty():
		where = str(summary.get("map", ""))
	var seconds := int(float(summary.get("seconds", 0.0)))
	return {"place": where, "time": "%d:%02d" % [seconds / 3600, (seconds / 60) % 60]}


func _run() -> void:
	if is_closed():
		return
	var target := save.slot if save.slot > 0 else save.first_empty()
	if save.config().save_anywhere:
		target = await _ask_file(target)
		if target <= 0:
			_end(false)
			return
	if not await dialogue.confirm(save_text):
		_end(false)
		return
	if save.has(target) and not await dialogue.confirm(overwrite_text):
		_end(false)
		return
	var written := save.write(target)
	await dialogue.say(saved_text if written else failed_text, {"locked": written, "auto": saved_seconds if written else 0.0})
	_end(written)


## The file chosen, 0 if cancelled.
func _ask_file(current: int) -> int:
	var shown := save.slots()
	var choices: Array = []
	for number in shown:
		var summary := save.summary(number)
		var values := describe(summary)
		values["slot"] = number
		choices.append(texts.format(new_file_choice if summary.is_empty() or summary.has("damaged") else file_choice, false, values))
	choices.append(cancel_choice)
	var picked := await dialogue.ask(file_text, choices, {"default": maxi(shown.find(current), 0)})
	return shown[picked] if picked >= 0 and picked < shown.size() else 0


func _show_summary(summary: Dictionary) -> void:
	var shown := describe(summary)
	var place_label := get_node_or_null(place) as Label
	if place_label != null:
		place_label.text = shown["place"]
	var time_label := get_node_or_null(time) as Label
	if time_label != null:
		time_label.text = shown["time"]


func _end(saved: bool) -> void:
	if is_closed():
		return
	done.emit(saved)
	close()


func _service(args: Dictionary, key: StringName) -> Variant:
	if args.has(key):
		return args[key]
	var engine := get_node_or_null(^"/root/Wildgrass")
	return engine.get(key) if engine != null else null
