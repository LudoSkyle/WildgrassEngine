## A Studio project's quests (`Data/Studio/quests/*.json`), read as they are:
## a source of the quests service. A quest's name and description are Studio
## texts, `{text:file:line}`.
extends RefCounted

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")

## The quest files, inside the data folder.
const FOLDER := "Studio/quests/"
## Studio texts of quest names and descriptions.
const NAME_TEXTS := 100045
const DESCRIPTION_TEXTS := 100046
## Where each kind of objective writes its target and its amount: [index of
## the target or -1, index of the amount or -1].
const ARGS: Dictionary[String, Array] = {
	"speak_to": [0, -1], "obtain_item": [0, 1], "see_pokemon": [0, -1], "beat_pokemon": [0, 1],
	"catch_pokemon": [-1, 1], "beat_npc": [0, 2], "obtain_egg": [-1, 0], "hatch_egg": [-1, 1],
	"custom": [0, -1],
}

@warning_ignore("shadowed_global_identifier")
var log: Log

var _paths: Paths


func _init(paths: Paths, logger: Log) -> void:
	_paths = paths
	log = logger


## Every quest of the project, by file name.
func read_all() -> Array:
	var found := []
	var folder := _paths.resolve(&"data", FOLDER)
	if not DirAccess.dir_exists_absolute(folder):
		return found
	var files := Array(DirAccess.get_files_at(folder)).filter(func(file: String) -> bool: return file.get_extension() == "json")
	files.sort()
	for file: String in files:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder + file))
		if not data is Dictionary or not data.has("dbSymbol"):
			log.error(&"studio", "%s: not a Studio quest" % (folder + file))
			continue
		found.append(_quest(data))
	return found


func _quest(data: Dictionary) -> WgQuest:
	var built := WgQuest.new()
	built.id = StringName(str(data["dbSymbol"]))
	var number := int(data.get("id", 0))
	built.name = "{text:%d:%d}" % [NAME_TEXTS, number]
	built.description = "{text:%d:%d}" % [DESCRIPTION_TEXTS, number]
	built.primary = bool(data.get("isPrimary", true))
	for written: Variant in data.get("objectives", []):
		var objective := WgQuestObjective.new()
		var kind := str(written.get("objectiveMethodName", "")).trim_prefix("objective_")
		objective.kind = StringName(kind)
		objective.args = written.get("objectiveMethodArgs", [])
		objective.hidden = bool(written.get("hiddenByDefault", false))
		var places: Array = ARGS.get(kind, [0, -1])
		if not ARGS.has(kind):
			log.warn(&"studio", "%s: unknown objective kind '%s'" % [built.id, kind])
		if places[0] >= 0 and places[0] < objective.args.size() and objective.args[places[0]] != null:
			var target: Variant = objective.args[places[0]]
			objective.target = str(int(target)) if target is float and target == floorf(target) else str(target)
		if places[1] >= 0 and places[1] < objective.args.size() and objective.args[places[1]] != null:
			objective.amount = maxi(int(objective.args[places[1]]), 1)
		built.objectives.append(objective)
	for written: Variant in data.get("earnings", []):
		var earning := WgQuestEarning.new()
		earning.kind = StringName(str(written.get("earningMethodName", "")).trim_prefix("earning_"))
		earning.args = written.get("earningArgs", [])
		built.earnings.append(earning)
	return built
