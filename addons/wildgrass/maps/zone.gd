## What the maps of a zone share (`WgMap.zone`): its name and its banner.
class_name WgZone
extends Resource

@export var id: StringName = &""
## A label: the place's name the banner shows; empty, no banner.
@export var name := ""
## The banner's style, for a game's banner to draw (wood, metal, cave…).
@export var banner: StringName = &""
