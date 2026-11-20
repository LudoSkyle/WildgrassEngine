## What the player carries: items, in the order received, and money.
extends RefCounted

const Log := preload("res://addons/wildgrass/core/log/log.gd")
const Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")
const Items := preload("res://addons/wildgrass/bag/items.gd")
const Quests := preload("res://addons/wildgrass/story/quests.gd")

## The count of an item changed.
signal changed(id: StringName, count: int)
signal money_changed(money: int)
## An item was given to the player: by a message, a ball on a map, a quest.
signal given(id: StringName, count: int)

@warning_ignore("shadowed_global_identifier")
var log: Log
var money: int:
	get:
		return _money

var _hooks: Hooks
var _items: Items
var _quests: Quests
var _counts: Dictionary[StringName, int] = {}
## Every item held, in the order received.
var _order: Array[StringName] = []
var _money := 0


func _init(logger: Log, hook_registry: Hooks, items_service: Items, quests: Quests) -> void:
	log = logger
	_hooks = hook_registry
	_items = items_service
	_quests = quests
	_hooks.add(&"story_term", &"wildgrass_bag", _read_term)
	quests.add_earning(&"money", _give_money, _can_give_money)
	quests.add_earning(&"item", _give_item, _can_give_item)


## True if `count` of `id` would fit: a known item, not past `maxCount`, nor
## past 1 for an item not consumed.
func can_add(id: StringName, count := 1) -> bool:
	var found := _items.item(id)
	if found == null or count <= 0:
		return false
	var after: int = _counts.get(id, 0) + count
	if not found.consumed:
		return after <= 1
	var limit := _items.bag_config().max_count
	return limit == 0 or after <= limit


## Adds `count` of `id`, all or nothing; false if it would not fit.
func add(id: StringName, count := 1) -> bool:
	if not can_add(id, count):
		return false
	if not _counts.has(id):
		_order.append(id)
	_counts[id] = _counts.get(id, 0) + count
	changed.emit(id, _counts[id])
	_quests.record(&"obtain_item", id, count)
	return true


## Adds as a gift (`given`), logging a refusal.
func give(id: StringName, count := 1) -> bool:
	if not add(id, count):
		log.warn(&"bag", "%s x%d does not fit in the bag" % [id, count])
		return false
	given.emit(id, count)
	return true


## Removes `count` of `id`; false, removing nothing, if there are fewer.
func remove(id: StringName, count := 1) -> bool:
	if count <= 0 or self.count(id) < count:
		return false
	_counts[id] -= count
	if _counts[id] == 0:
		_counts.erase(id)
		_order.erase(id)
	changed.emit(id, self.count(id))
	return true


func count(id: StringName) -> int:
	return _counts.get(id, 0)


func has(id: StringName, at_least := 1) -> bool:
	return count(id) >= at_least


## The items held in a pocket, in the order received or sorted.
func items(pocket: StringName) -> Array[StringName]:
	var found: Array[StringName] = []
	for id in _order:
		var item := _items.item(id)
		if item != null and item.pocket == pocket:
			found.append(id)
	return found


## Sorts a pocket by the items' positions, ties in the order received.
func sort(pocket: StringName) -> void:
	var sorted := items(pocket)
	var received := sorted.duplicate()
	sorted.sort_custom(func(a: StringName, b: StringName) -> bool:
		var left := _items.item(a).position
		var right := _items.item(b).position
		return left < right or (left == right and received.find(a) < received.find(b)))
	var slots: Array[int] = []
	for index in _order.size():
		if _order[index] in sorted:
			slots.append(index)
	for index in slots.size():
		_order[slots[index]] = sorted[index]


## Uses an item: what `Wildgrass.items.add_use()` says, awaited; a consumed
## item used up is removed. False if not used.
func use(id: StringName) -> bool:
	var found := _items.item(id)
	if found == null or not has(id) or not found.usable:
		return false
	var use_it := _items.use_of(found)
	if not use_it.is_valid():
		return false
	var result: Variant = await use_it.call(id)
	if result is bool and not result:
		return false
	if found.consumed:
		remove(id)
	return true


func add_money(amount: int) -> void:
	_set_money(_money + amount)


## Spends `amount`; false, spending nothing, if there is not enough.
func spend(amount: int) -> bool:
	if amount < 0 or amount > _money:
		return false
	_set_money(_money - amount)
	return true


## Everything, as a dictionary JSON can hold.
func state() -> Dictionary:
	var held := []
	for id in _order:
		held.append([str(id), _counts[id]])
	return {"items": held, "money": _money}


func restore(saved: Dictionary) -> void:
	_counts.clear()
	_order.clear()
	for entry: Variant in saved.get("items", []):
		if entry is Array and entry.size() == 2:
			var id := StringName(str(entry[0]))
			_order.append(id)
			_counts[id] = int(entry[1])
	_money = int(saved.get("money", 0))


func reset() -> void:
	_counts.clear()
	_order.clear()
	_money = 0


func _set_money(value: int) -> void:
	var kept := clampi(value, 0, _items.bag_config().max_money)
	if kept != _money:
		_money = kept
		money_changed.emit(_money)


func _give_money(amount: Variant) -> void:
	add_money(int(amount))


func _can_give_money(_amount: Variant) -> bool:
	return true


func _give_item(id: Variant, count: Variant = 1) -> void:
	give(StringName(str(id)), int(count))


func _can_give_item(id: Variant, count: Variant = 1) -> bool:
	return can_add(StringName(str(id)), int(count))


## `has:potion`, `has:potion*3`, `money:500`: at least.
func _read_term(read: Variant, term: String, _node: Node) -> Variant:
	if term.begins_with("has:"):
		var parts := term.substr(4).split("*")
		return has(StringName(parts[0]), int(parts[1]) if parts.size() > 1 else 1)
	if term.begins_with("money:"):
		return _money >= term.substr(6).to_int()
	return read
