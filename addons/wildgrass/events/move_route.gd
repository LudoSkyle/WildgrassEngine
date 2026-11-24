## A route a walker follows (feature 21): steps, turns, waits and changes of
## look, one after the other, as RPG Maker's move routes. An event's page
## follows its own; a command imposes one on any walker for a while.
class_name WgMoveRoute
extends Resource

@export var steps: Array[WgMoveStep] = []
## Starts over once it ends.
@export var repeat := false
## A step blocked is skipped; else it is tried again until it goes.
@export var skippable := false
