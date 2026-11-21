## The `studio` config: what a Studio project needs that Studio does not say.
class_name WgStudioConfig
extends WgConfig

## The column of Studio's text files for a Godot locale, where they differ
## (`{"ja": "kana"}`).
@export var columns: Dictionary[String, String] = {}
