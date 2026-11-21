## The `bag` config: the pockets, in order, and the limits of the bag.
class_name WgBagConfig
extends WgConfig

## The engine's pockets; `reveal`: giving one of its items shows it.
const POCKETS: Array[Dictionary] = [
	{"id": "items", "name": "Items"},
	{"id": "medicine", "name": "Medicine"},
	{"id": "balls", "name": "Poké Balls"},
	{"id": "tms", "name": "TMs"},
	{"id": "berries", "name": "Berries"},
	{"id": "key_items", "name": "Key Items", "reveal": true},
]

## Each `{"id", "name", "reveal"}`, in the order shown; `name` is a label.
@export var pockets: Array[Dictionary] = POCKETS.duplicate(true)
## The most of one item the bag holds; 0: no limit.
@export var max_count := 99
@export var max_money := 999999
## Seconds an item revealed stays once its message is written.
@export var reveal_seconds := 1.0


func _validate() -> PackedStringArray:
	var problems := PackedStringArray()
	var kept: Array[Dictionary] = []
	for pocket: Dictionary in pockets:
		if str(pocket.get("id", "")).is_empty():
			problems.append("pockets: a pocket needs an id, got %s" % JSON.stringify(pocket))
			continue
		kept.append(pocket)
	pockets = kept
	if max_count < 0:
		problems.append("max_count cannot be negative, got %d; using 99" % max_count)
		max_count = 99
	if max_money < 0:
		problems.append("max_money cannot be negative, got %d; using 999999" % max_money)
		max_money = 999999
	if reveal_seconds < 0.0:
		problems.append("reveal_seconds cannot be negative, got %s; using 1" % reveal_seconds)
		reveal_seconds = 1.0
	return problems


func pocket(pocket_id: StringName) -> Dictionary:
	for found: Dictionary in pockets:
		if StringName(str(found["id"])) == pocket_id:
			return found
	return {}
