## A quest: objectives to do, earnings to claim.
class_name WgQuest
extends Resource

## Its name in code and conditions (`quest:bell`).
@export var id: StringName = &""
@export var name := ""
@export_multiline var description := ""
## A main quest, not a side one.
@export var primary := true
@export var objectives: Array[WgQuestObjective] = []
@export var earnings: Array[WgQuestEarning] = []
