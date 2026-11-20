## An interactable whose interaction lasts until `release` is emitted.
extends WgInteractable

signal release


func _interact(_walker: WgWalker) -> void:
	await release
