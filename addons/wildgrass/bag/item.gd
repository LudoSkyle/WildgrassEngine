## An item: what it is called, where it goes in the bag, what it costs, how it
## is used. Its texts may hold placeholders, shown through
## `Wildgrass.texts.format()`.
class_name WgItem
extends Resource

@export var id: StringName = &""
## Items that work alike share one: `constant_heal`, `repel`…
@export var kind: StringName = &""
@export var name := ""
@export_multiline var description := ""
@export var plural := ""
## The id of its pocket.
@export var pocket: StringName = &""
## Its place when a pocket is sorted.
@export var position := 0
@export var price := 0
@export var icon: Texture2D:
	get:
		if icon == null and not icon_path.is_empty():
			icon = _load_icon()
		return icon
## Used up when used; one that is not is kept once, never tossed, shown
## without a count.
@export var consumed := true
## Usable outside battle.
@export var usable := false
## What its kind adds: hp to heal, a catch rate…
@export var data: Dictionary = {}
## Where its icon is, loaded the first time it shows.
var icon_path := ""
## Called with the path of an icon that is missing.
var on_missing_icon := Callable()


## Its name for `count` of it: the plural when more than one, if it has one.
func name_for(count: int) -> String:
	return plural if count > 1 and not plural.is_empty() else name


func _load_icon() -> Texture2D:
	if ResourceLoader.exists(icon_path):
		return load(icon_path) as Texture2D
	if FileAccess.file_exists(icon_path):
		var image := Image.load_from_file(icon_path)
		if image != null:
			return ImageTexture.create_from_image(image)
	if on_missing_icon.is_valid():
		on_missing_icon.call(icon_path)
	icon_path = ""
	return null
