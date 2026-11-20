## One objective of a quest: done once `amount` of `kind` toward `target`
## have been recorded.
class_name WgQuestObjective
extends Resource

## What is counted: `speak_to`, `obtain_item`, `catch_pokemon`, `custom`…
@export var kind: StringName = &""
## What it is counted toward: an item, a character's index…; empty: anything.
@export var target := ""
## How many make it done.
@export var amount := 1
## Counts for nothing until revealed.
@export var hidden := false
## Its arguments as written, for the game's quest book.
@export var args: Array = []
