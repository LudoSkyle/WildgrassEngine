## The `bag` config: the pockets, in order, and the limits of the bag.
class_name WgBagConfig
extends WgConfig

## Studio's pockets in Studio's order. `socket` is Studio's pocket number;
## `reveal`: giving one of its items shows it.
const STUDIO_POCKETS: Array[Dictionary] = [
	{"id": "items", "name": "{text:100015:4|Other Items}", "socket": 1},
	{"id": "balls", "name": "{text:100015:1|Poké Balls}", "socket": 2},
	{"id": "medicine", "name": "{text:100015:0|Medicine}", "socket": 6},
	{"id": "tms", "name": "{text:100015:5|TMs}", "socket": 3},
	{"id": "key_items", "name": "{text:100015:8|Key Items}", "socket": 5, "reveal": true},
	{"id": "berries", "name": "{text:100015:3|Berries}", "socket": 4},
]

## Each `{"id", "name", "socket", "reveal"}`, in the order shown.
@export var pockets: Array[Dictionary] = STUDIO_POCKETS.duplicate(true)
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


## The pocket of a Studio pocket number; empty if none shows it.
func pocket_of_socket(socket: int) -> StringName:
	for pocket: Dictionary in pockets:
		if pocket.has("socket") and int(pocket["socket"]) == socket:
			return StringName(str(pocket["id"]))
	return &""


func pocket(pocket_id: StringName) -> Dictionary:
	for found: Dictionary in pockets:
		if StringName(str(found["id"])) == pocket_id:
			return found
	return {}
