## An item lying on a map. Interacted with, the item goes in the bag, its
## local flag `taken` is set, its text is said, and it is gone, on every load
## too. A visible one blocks its cell; an invisible one shows and blocks
## nothing.
class_name WgItemBall
extends WgInteractable

@export var item: StringName = &""
@export var count := 1
## Said when taken: `{item}` is the item's name, its plural past one,
## `{count}` the count.
@export_multiline var text := "Found {item}!"
## Said when the bag is full; the ball stays.
@export_multiline var full_text := "No room for {item}."
## Nobody sees it: a hidden item.
@export var invisible := false:
	set(value):
		invisible = value
		blocks = not value
		visible = not value


func _init() -> void:
	blocks = true
	var gate := WgShowIf.new()
	gate.condition = "!local:taken"
	# Internal: never saved with the map, so never found twice.
	add_child(gate, false, Node.INTERNAL_MODE_FRONT)


func _interact(walker: WgWalker) -> void:
	var walkers := walker.walkers
	var found: WgItem = walkers.bag.item(item)
	if found == null:
		return
	var values := {"item": found.name_for(count), "count": count}
	if not walkers.bag.give(item, count):
		await walkers.dialogue.say(full_text, {"values": values})
		return
	walkers.story.set_flag(walkers.story.local(self, &"taken"))
	await walkers.dialogue.say(text, {"values": values})
	queue_free()
