## Keeps its parent on the map only if `condition` holds when the map is
## built, before it enters the tree: a character that is not there holds no
## cell, blocks nothing, says nothing.
class_name WgShowIf
extends Node

## A story condition: `bell_told, !bell_hung`.
@export var condition := ""
