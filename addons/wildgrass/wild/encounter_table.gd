## Who lives on a terrain: wild Pokémon drawn by weight, each between two
## levels, on the tiles whose `encounter` data is `terrain`.
class_name WgEncounterTable
extends Resource

@export var id: StringName = &""
## The tiles it is drawn on: their `encounter` and `encounter_area` data.
@export var terrain: StringName = &"grass"
@export var area := 0
## Empty: a step; else what brings them out (`old_rod`, `rock_smash`…).
@export var tool: StringName = &""
## A story condition; empty: always.
@export var condition := ""
## Its own chance per step, in percent; 0: the map's.
@export var rate := 0.0
## Two at once, for battles.
@export var double := false
## `[{species, form, min_level, max_level, weight, shiny_rate}]`; `shiny_rate`
## 0: the config's.
@export var pokemon: Array[Dictionary] = []


## True if it is drawn on `on_terrain`, `on_area`, with `with_tool`.
func fits(on_terrain: StringName, with_tool: StringName, on_area: int) -> bool:
	return terrain == on_terrain and tool == with_tool and area == on_area
