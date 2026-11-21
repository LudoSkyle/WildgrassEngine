## Quests: started, counted toward, finished the moment their last objective
## is done, failed, claimed. Those the game registers, then its resources
## (`res://quests/*.tres`), then what sources give.
extends RefCounted

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")
const Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")

signal started(id: StringName)
signal objective_done(id: StringName, index: int)
signal finished(id: StringName)
signal failed(id: StringName)

const ACTIVE := "active"
const FINISHED := "finished"
const FAILED := "failed"

@warning_ignore("shadowed_global_identifier")
var log: Log

var _hooks: Hooks
var _paths: Paths
var _read := false
var _sources: Array[Callable] = []
var _quests: Dictionary[StringName, WgQuest] = {}
var _givers: Dictionary[StringName, Callable] = {}
var _checks: Dictionary[StringName, Callable] = {}
## Id -> {"state", "progress": Array[int], "revealed": Array[bool], "claimed"}.
var _progress: Dictionary[StringName, Dictionary] = {}


func _init(logger: Log, hook_registry: Hooks, paths: Paths) -> void:
	log = logger
	_hooks = hook_registry
	_paths = paths
	_hooks.add(&"story_term", &"wildgrass_quests", _read_term)


## Makes `quest` known, by its id.
func register(quest: WgQuest) -> void:
	if quest.id.is_empty():
		log.error(&"quests", "a quest needs an id")
		return
	_quests[quest.id] = quest


## Adds an origin of quests: `source` returns an array of `WgQuest`, asked
## once, before any quest is asked for.
func add_source(source: Callable) -> void:
	_sources.append(source)


func quest(id: StringName) -> WgQuest:
	_read_all()
	return _quests.get(id)


## Starts a known quest that is neither active nor finished; a failed one
## starts again from nothing.
func start(id: StringName) -> bool:
	var found := _known(id)
	if found == null or is_active(id) or is_finished(id):
		return false
	var revealed: Array[bool] = []
	var counted: Array[int] = []
	for objective in found.objectives:
		revealed.append(not objective.hidden)
		counted.append(0)
	_progress[id] = {"state": ACTIVE, "progress": counted, "revealed": revealed, "claimed": false}
	started.emit(id)
	_check_finished(id)
	return true


## Objective `index` of an active quest is done.
func complete(id: StringName, index: int) -> void:
	var objective := _objective(id, index)
	if objective != null:
		add(id, index, objective.amount)


## Counts `amount` toward objective `index` of an active quest.
func add(id: StringName, index: int, amount := 1) -> void:
	if _objective(id, index) == null or not is_active(id):
		return
	if not is_revealed(id, index):
		log.warn(&"quests", "%s: objective %d is hidden" % [id, index])
		return
	_count(id, index, amount)


## Counts `amount` of `kind` toward `target` for every active quest's
## revealed objectives that match.
func record(kind: StringName, target: Variant, amount := 1) -> void:
	for id: StringName in _progress.keys():
		if not is_active(id):
			continue
		var objectives := _quests[id].objectives
		for index in objectives.size():
			var objective := objectives[index]
			if objective.kind == kind and is_revealed(id, index) and _matches(objective, target):
				_count(id, index, amount)
				if not is_active(id):
					break


## Objective `index` counts from now on.
func reveal(id: StringName, index: int) -> void:
	if _objective(id, index) != null and _progress.has(id):
		_progress[id]["revealed"][index] = true


func fail(id: StringName) -> bool:
	if not is_active(id):
		return false
	_progress[id]["state"] = FAILED
	failed.emit(id)
	return true


func is_active(id: StringName) -> bool:
	return _state(id) == ACTIVE


func is_finished(id: StringName) -> bool:
	return _state(id) == FINISHED


func is_failed(id: StringName) -> bool:
	return _state(id) == FAILED


func progress(id: StringName, index: int) -> int:
	return _progress[id]["progress"][index] if _progress.has(id) and _objective(id, index) != null else 0


func is_done(id: StringName, index: int) -> bool:
	var objective := _objective(id, index)
	return objective != null and progress(id, index) >= objective.amount


func is_revealed(id: StringName, index: int) -> bool:
	return _progress.has(id) and _progress[id]["revealed"][index]


## Gives the earnings of a finished quest, once: true the first time. Nothing
## is given, and it stays to claim, while an earning would not fit. A kind
## nobody gives is logged, the others given.
func claim(id: StringName) -> bool:
	if not is_finished(id) or _progress[id]["claimed"]:
		return false
	for earning in _quests[id].earnings:
		if _checks.has(earning.kind) and not _checks[earning.kind].callv(earning.args):
			return false
	_progress[id]["claimed"] = true
	for earning in _quests[id].earnings:
		if _givers.has(earning.kind):
			_givers[earning.kind].callv(earning.args)
		else:
			log.error(&"quests", "%s: nobody gives the earning '%s'" % [id, earning.kind])
	return true


## `giver` is called with an earning's arguments when a quest of that kind of
## earning is claimed; `check`, with the same, says whether it would fit.
func add_earning(kind: StringName, giver: Callable, check := Callable()) -> void:
	_givers[kind] = giver
	if check.is_valid():
		_checks[kind] = check
	else:
		_checks.erase(kind)


## Every quest's progress, as a dictionary JSON can hold.
func state() -> Dictionary:
	var saved := {}
	for id: StringName in _progress:
		saved[str(id)] = _progress[id].duplicate(true)
	return saved


func restore(saved: Dictionary) -> void:
	_progress.clear()
	for id: Variant in saved:
		var entry: Dictionary = saved[id]
		var counted: Array[int] = []
		for value: Variant in entry.get("progress", []):
			counted.append(int(value))
		var revealed: Array[bool] = []
		for value: Variant in entry.get("revealed", []):
			revealed.append(bool(value))
		_progress[StringName(str(id))] = {"state": str(entry.get("state", ACTIVE)), "progress": counted, "revealed": revealed, "claimed": bool(entry.get("claimed", false))}


func reset() -> void:
	_progress.clear()


## Reads the folder's quests and the sources', once, before any quest is
## asked for; the first to name an id keeps it.
func _read_all() -> void:
	if _read:
		return
	_read = true
	for found: WgQuest in _from_folder():
		_add_once(found)
	for source in _sources:
		var given: Variant = source.call()
		for found: Variant in given if given is Array else []:
			if found is WgQuest:
				_add_once(found)


func _add_once(found: WgQuest) -> void:
	if not found.id.is_empty() and not _quests.has(found.id):
		_quests[found.id] = found


func _from_folder() -> Array[WgQuest]:
	var found: Array[WgQuest] = []
	var folder := _paths.resolve(&"quests", "")
	if not DirAccess.dir_exists_absolute(folder):
		return found
	var files := Array(DirAccess.get_files_at(folder)).filter(func(file: String) -> bool: return file.get_extension() == "tres")
	files.sort()
	for file: String in files:
		var quest := load(folder + file) as WgQuest
		if quest == null:
			log.error(&"quests", "%s: not a WgQuest" % file)
		else:
			found.append(quest)
	return found


func _count(id: StringName, index: int, amount: int) -> void:
	var objective := _quests[id].objectives[index]
	var before: int = _progress[id]["progress"][index]
	var after := mini(before + amount, objective.amount)
	_progress[id]["progress"][index] = after
	if before < objective.amount and after >= objective.amount:
		objective_done.emit(id, index)
	_check_finished(id)


func _check_finished(id: StringName) -> void:
	if not is_active(id):
		return
	for index in _quests[id].objectives.size():
		if not is_done(id, index):
			return
	_progress[id]["state"] = FINISHED
	finished.emit(id)


func _matches(objective: WgQuestObjective, target: Variant) -> bool:
	var matches := objective.target.is_empty() or objective.target == str(target)
	return bool(_hooks.filter(&"quest_match", matches, [objective, target]))


func _known(id: StringName) -> WgQuest:
	_read_all()
	if not _quests.has(id):
		log.error(&"quests", "unknown quest '%s'" % id)
		return null
	return _quests[id]


func _objective(id: StringName, index: int) -> WgQuestObjective:
	var found := _known(id)
	if found == null:
		return null
	if index < 0 or index >= found.objectives.size():
		log.error(&"quests", "%s has no objective %d" % [id, index])
		return null
	return found.objectives[index]


func _state(id: StringName) -> String:
	return _progress[id]["state"] if _progress.has(id) else ""


func _read_term(read: Variant, term: String, _node: Node) -> Variant:
	for prefix: String in ["quest:", "quest_active:", "quest_failed:"]:
		if term.begins_with(prefix):
			var id := StringName(term.substr(prefix.length()))
			match prefix:
				"quest:": return is_finished(id)
				"quest_active:": return is_active(id)
				_: return is_failed(id)
	return read
