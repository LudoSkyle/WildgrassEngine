## A nature: the stats it raises and lowers, the flavors it likes and
## dislikes. Its name is a label, shown through `Wildgrass.texts.label()`.
class_name WgNature
extends Resource

## The stats a nature changes.
const STATS: Array[StringName] = [&"attack", &"defense", &"speed", &"special_attack", &"special_defense"]

@export var id: StringName = &""
## Its number: a Pokémon's nature is drawn by number.
@export var number := 0
@export var name := ""
## `{stat: percent}`, the stats of `STATS`: 90, 100 or 110. A stat not
## named: 100.
@export var stats: Dictionary[StringName, int] = {}
## `spicy`, `dry`, `sweet`, `bitter` or `sour`; empty: none.
@export var liked_flavor: StringName = &""
@export var disliked_flavor: StringName = &""


## What it does to `stat`, in percent.
func factor(stat: StringName) -> int:
	return stats.get(stat, 100)
