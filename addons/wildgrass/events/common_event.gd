## A list of commands any event calls by its number (feature 21), or that
## runs by itself while its switch is on: `res://common_events/<number>.tres`.
class_name WgCommonEvent
extends Resource

enum Trigger { NONE, AUTORUN, PARALLEL }

@export var trigger := Trigger.NONE
## The flag that lets it run by itself (`switch_5`).
@export var switch: StringName = &""
@export var commands: Array[WgEventCommand] = []
