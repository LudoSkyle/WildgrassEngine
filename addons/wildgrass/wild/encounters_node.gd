## A map's wild encounters: put one anywhere in a map scene. Its tables are
## drawn on the tiles whose `encounter` data they name.
class_name WgEncounters
extends Node

## The chance per step walked, in percent.
@export var rate := 0.0
## The chance per step run; -1: as walked.
@export var run_rate := -1.0
## The map's own tables.
@export var tables: Array[WgEncounterTable] = []
## Tables found by id (`Wildgrass.encounters.find()`).
@export var table_ids: Array[StringName] = []


## The chance of a step, in percent.
func chance(running: bool) -> float:
	return run_rate if running and run_rate >= 0.0 else rate
