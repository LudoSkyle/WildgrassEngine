# Feature 14 — Wild encounters

Status: implemented.

A step in tall grass may bring out a wild Pokémon: where it can happen, how
often, who comes out, at which level, and what the engine does with it until
battles exist. It reads the species (feature 12) and records what is seen
in the Pokédex (feature 13).

## Where and how often

```gdscript
# A map scene: a WgEncounters node, anywhere in it.
#   rate 3, run_rate 5, tables [route_1_grass]
Wildgrass.encounters.forced = 1     # always (tests, debug); 0 never; -1 chance
```

- **The terrain** is tile data (feature 2): `encounter` names it on the tiles
  where Pokémon live (`grass`, `tall_grass`, `cave`, `water`…, open to any
  name), and `encounter_area` (0 by default) tells apart two parts of a map
  of the same terrain. A tile without `encounter` brings no one.
- **A map's encounters** are a `WgEncounters` node in its scene: `rate`, the
  chance per step walked, in percent; `run_rate`, per step run (-1: as
  walked); `tables`, its encounter tables, as resources or by id.
- **When**: the traveller settles on a cell after its own step, the cell's
  terrain has a table, nothing else came first (a contact door, a trigger),
  no screen is open and the map is not changing. Never mid-step, on arriving
  on a map, turning on the spot, or for another walker.
- `forced`: -1, the chance; 1, every step that can; 0, never. `seed(n)`
  makes the chance repeatable.

## Encounter tables

`WgEncounterTable` (`Resource`):

| Field | |
|---|---|
| `id` | |
| `terrain`, `area` | the tiles it is drawn on: `encounter` and `encounter_area` |
| `tool` | empty: a step; else what brings it out (`old_rod`, `rock_smash`…), for the features that use one |
| `condition` | a story condition (feature 7); empty: always |
| `rate` | its own chance per step, in percent; 0: the map's |
| `double` | two at once, for battles |
| `pokemon` | `[{species, form, min_level, max_level, weight, shiny_rate}]` |

- A step draws among the entries of every table of the map that fits the
  cell (terrain, area, no tool, condition holding), by `weight`; the level is
  drawn between `min_level` and `max_level`; shiny once in `shiny_rate` (0:
  the config's, 4096; -1: never).
- Tables are a map's own resources, or found by id: registered, else
  `res://encounters/<id>.tres` (paths, `encounters`), else a source, as
  species are.
- A wrong entry (an unknown species, levels the wrong way round, no weight)
  is logged once and left out; the table keeps the others.
- `Wildgrass.encounters.draw(terrain, tool = &"", area = 0)`: a wild Pokémon
  of the current map's tables, or `{}`: for the features with a tool
  (fishing, smashing rocks). `tables_for()` gives the tables that fit,
  `map_node()` the map's `WgEncounters`, `roll(walker)` what a step brings,
  `meet(pokemon)` what follows.

## A wild Pokémon

A Dictionary: `{species, form, level, shiny, table}`.

1. The filter hook `wild_encounter(pokemon)` may change it, or return `{}` to
   cancel it (a repel, later).
2. `count` goes up, `last` keeps it, signal `encountered(pokemon)`; the
   Pokédex records it as seen (its form).
3. `Wildgrass.encounters.start` (a callable, awaited) does what follows: the
   engine's says "A wild {name} appeared!" in the message box, the player
   held until it closes. Battles replace it.

## The `encounters` config

`config/encounters.json`: `shiny_rate` (4096).

## A Studio project

Studio's groups (`Data/Studio/groups/<dbSymbol>.json`) become tables, found
by id; a Studio project's maps name them in their `WgEncounters` node until
the map importer reads which zones hold which groups:

| Studio | Engine |
|---|---|
| `dbSymbol` | `id` |
| `systemTag` (`Grass`, `TallGrass`, `Cave`, `Pond`, `Ocean`, `Sand`…), `terrainTag` | `terrain` in snake case (`tall_grass`), `area` |
| `tool` (`OldRod`, `GoodRod`, `SuperRod`, `RockSmash`; none) | `tool` (`old_rod`…; empty) |
| `stepsAverage` (0: the map's) | `rate`: 100 / steps |
| `vsType` `double` | `double` |
| `customConditions`: `enabledSwitch` | `condition`: the story flag `switch_<n>`, all of them (`AND`; an `OR` is logged once and read as `AND`); `mapId` is the map choosing the table; another kind is logged once and ignored |
| `encounters[]`: `specie`, `form`, `levelSetup` (`minmax`, `fixed`), `randomEncounterChance`, `shinySetup` (`automatic`: the config's; `rate`, a chance: once in 1 / chance, 0 never) | `pokemon`: `species`, `form`, `min_level`, `max_level`, `weight`, `shiny_rate` |

The engine's terrain names are Studio's system tags in snake case: the tile
importer, later, writes them as tile data.

## Pokémon Mirage, step by step

| In Pokémon Mirage | In the engine |
|---|---|
| the tiles of the `Background/Grass` layer | tile data `encounter: grass` on those tiles of `level.tres` |
| the map's `encounter_rate` 3, `encounter_rate_run` 5 | the map's `WgEncounters`: `rate` 3, `run_rate` 5 |
| `metadata/wild = "mulotin:2-4*50 \| …"` | a table: `pokemon` with `min_level`, `max_level`, `weight`; real species of the region, the made-up ones gone |
| when the player settles after a step; a gate or a door of the same step first; no box, no hold, no map changing | the same |
| "Un Mulotin sauvage apparaît !", the player held | the engine's `start` |
| the Pokédex records it as seen | the same |
| `WildEncounters.count`, `last`, `forced`, the seed | `count`, `last`, `forced`, `seed()` |
| a wrong entry logged and left out | the same |

## Later

- Battles: `start` replaced, `double` read.
- Repels, abilities changing the rate, roaming Pokémon, fishing and smashing
  rocks: with their features, through the hook and `draw()`.
- Studio's zones choosing groups, and its other conditions: with the map
  importer.

## Tests

Species, maps, tiles, tables and Studio files are built by the tests; steps
are advanced by hand, the chance seeded.
Covered: a draw by weight and a level between the two, the seed repeating
it, only the tables fitting the terrain, area, tool and condition, every
table that fits drawn from, tables found by id and an unknown one logged,
wrong entries left out and logged once, shiny by its rate or the config's,
a map without encounters, a bad config. A step in grass bringing one out,
counted, seen in the Pokédex, said, the player held until the box closes;
off the grass, turning, another walker bring no one; the chance walked or
run, forced always or never, about half the steps at 50, a table's own rate
winning; a trigger or a screen coming first; the hook changing or
cancelling, `start` replaced; the tile's area choosing its tables. Studio's
groups as tables with every field, fixed levels, never-shiny, unknown
conditions and OR logged once, a broken file, a map naming a group.
