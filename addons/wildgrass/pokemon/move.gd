## A move: what it is in battle, what it does on the map and in contests.
## Its texts are labels, shown through `Wildgrass.texts.label()`.
class_name WgMove
extends Resource

## What it hits with.
enum Category { PHYSICAL, SPECIAL, STATUS }

## The flags a move can have:
## `contact` (touches its target), `charge` (a turn to charge),
## `recharge` (a turn to rest after), `protectable` (stopped by a
## protection), `snatchable`, `mirrorable` (can be copied back),
## `reflectable` (can be sent back), `punch`, `bite`, `pulse`, `slicing`,
## `sound`, `wind`, `dance`, `powder`, `ballistic`, `mental`, `heal`,
## `gravity` (unusable under gravity), `thaws` (usable frozen, and thaws
## its user), `distance` (reaches any target), `bypasses_substitute`,
## `non_sky_battle`, `flinch_item` (a held item can make its target flinch).
const FLAGS: Array[StringName] = [
	&"contact", &"charge", &"recharge", &"protectable", &"snatchable", &"mirrorable", &"reflectable",
	&"punch", &"bite", &"pulse", &"slicing", &"sound", &"wind", &"dance", &"powder", &"ballistic",
	&"mental", &"heal", &"gravity", &"thaws", &"distance", &"bypasses_substitute", &"non_sky_battle",
	&"flinch_item",
]

@export var id: StringName = &""
## Its number, which its texts follow.
@export var number := 0
@export var name := ""
@export_multiline var description := ""
@export_multiline var contest_description := ""
## A type id.
@export var type: StringName = &""
@export var category := Category.PHYSICAL
## 0: none, or not fixed.
@export var power := 0
## Percent; 0: never misses.
@export var accuracy := 0
@export var pp := 0
## -7 to 7: the higher acts first.
@export var priority := 0
## 0: never critical; 1: 1 in 16, 2: 1 in 8, 3: 1 in 4, 4: 1 in 3, 5: 1
## in 2, 6: always.
@export var critical_rate := 1
## Whom it aims: `user`, `adjacent_pokemon`, `adjacent_foe`,
## `adjacent_all_foe`, `adjacent_all_pokemon`, `adjacent_ally`,
## `user_or_adjacent_ally`, `all_ally`, `all_foe`, `all_pokemon`,
## `any_other_pokemon`, `random_foe`.
@export var target: StringName = &"adjacent_pokemon"
## Among `FLAGS`.
@export var flags: Array[StringName] = []
## The battle procedure it runs; empty: plain damage.
@export var effect: StringName = &""
## Percent chance of its added effect.
@export var effect_chance := 0
## `[{stat, stages}]`: `stat` among `attack`, `defense`, `speed`,
## `special_attack`, `special_defense`, `evasion`, `accuracy`.
@export var stat_changes: Array[Dictionary] = []
## `[{status, chance}]`: `status` among `poison`, `toxic`, `burn`,
## `paralysis`, `sleep`, `freeze`, `confusion`, `flinch`; `chance` percent.
@export var statuses: Array[Dictionary] = []
## The common event it runs used on the map; 0: none.
@export var map_use := 0
## `cool`, `beautiful`, `cute`, `clever` or `tough`.
@export var contest_condition: StringName = &""
@export var appeal := 0
@export var jam := 0
## The moves it combines with in contests.
@export var combo_moves: Array[StringName] = []
## What it does in contests.
@export var contest_effects: Array[StringName] = []


func has_flag(flag: StringName) -> bool:
	return flag in flags
