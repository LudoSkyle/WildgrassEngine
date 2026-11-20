## A screen that decides in `_on_open` it has nothing to show.
extends WgScreen


func _on_open(_args: Dictionary) -> void:
	close()
