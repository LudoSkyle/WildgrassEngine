# Feature 1 — Maps and doors

Status: implemented.

Loads maps and moves the traveller (the player) between and within them, with
named, replaceable transitions. Walking, facing and input belong to feature 3;
music, banner, weather to later features, through the hooks and zones below.
Maps linked side by side are feature 1b (`01b-linked-maps.md`).

## Maps

A map is a Godot scene whose root is a `WgMap` (`Node2D`). Maps are found by
id in the `maps` folder: `start_island` → `res://maps/start_island.tscn`
(setting `wildgrass/paths/maps`). Saves and doors store ids, never paths.

```
StartIsland (WgMap)
├── …                 tile layers, decor: anything
├── Entities          y-sorted; the traveller is put here
└── House (WgDoor)    doors and spawn points, anywhere in the tree
```

| `WgMap` field | Default | |
|---|---|---|
| `entities` | `Entities` | where the traveller is put; the map itself if missing |
| `zone` | `&""` | zone id: map-wide data several maps share |

- **The zone carries map-wide data**: name, location panel, fly point,
  weather, wild groups. Several maps share a zone. Features that need it read
  the zone data; a Studio project's zones will come through the Studio layer.
- **Anything a zone does not carry** (music, darkness) is a small node inside
  the map, found with `map.find_part(Type)`. A game adds its own the same way.

## Spawn points and doors

`WgSpawnPoint` (`Marker2D`): a named arrival point with a `direction`.

`WgDoor` (`Area2D`, never blocks) is also an arrival point:

| Field | |
|---|---|
| `target_map` | map id; empty = this map |
| `target_door` | name of a door or spawn point there |
| `kind` | `contact`: used by walking onto it; `exit`: by walking off it in `direction` |
| `direction` | contact: where you arrive and face; exit: the way out |
| `transition` | `&"fade"` by default |

| | Contact | Exit |
|---|---|---|
| Examples | house door, map edge | doormat, stairs |
| You arrive | one tile away, along `direction` | on it |
| You face | `direction` | opposite of `direction` |

A contact door with no direction is logged and uses down: arriving on it would
send you straight back. Feature 3 decides when a door is used and calls
`Wildgrass.maps.use(door)`.

## The maps service

```gdscript
Wildgrass.maps.warp(&"cave", &"Ladder", &"fade", Vector2i(0, 1), Vector2i.DOWN)
Wildgrass.maps.use(door)          # warp to the door's target, by its rules
Wildgrass.maps.go_to(&"start_island", &"Spawn")   # warp with no transition
Wildgrass.maps.go_to_cell(&"town", Vector2i(3, 4), Vector2i.LEFT)   # a loaded game
Wildgrass.maps.has_map(&"town")   # true if its scene exists
Wildgrass.maps.reload()           # same map, traveller stays
Wildgrass.maps.clear()            # no map: back to the title
Wildgrass.maps.current            # WgMap or null
Wildgrass.maps.traveller = player # any Node2D, set by feature 3
```

A warp, in order:

1. ignored while another runs (`is_changing`);
2. the transition covers the screen;
3. hook `map_leaving(map)` and free, for every map on screen; the new map
   at the origin, then its neighbours, each with hook `map_built(map, id)` as
   soon as it is instanced, before the tree (feature 7 frees what the story
   keeps off it), then `map_loaded(map)` so features set it up before it
   shows, even if the target was a neighbour. `id_of(map)` gives the id of
   any map built.
   Skipped when the target is the current map: the traveller only moves;
4. the traveller moves into `entities`, at the point plus the offset; signal
   `traveller_arrived(direction, door)` so feature 3 faces it and blocks the
   way back;
5. signal `zone_changed(old, new)` if the zone differs (the banner shows only
   then);
6. the transition uncovers; signal `map_changed(map)`.

- Unknown map: error logged, nothing changes.
- Unknown point: warning, arrival at the map's first spawn point, else its
  origin. An empty point is that first spawn point, without a warning.
- Maps go under `Wildgrass.maps.host`: a y-sorted engine node by default; a
  game can give its own (inside a `SubViewport`, say).
- `reload()` loads the current map and its neighbours again, in place: the
  maps and the traveller keep their position, the traveller its facing. It
  runs the map hooks, but neither `traveller_arrived` nor `zone_changed`.
- A map's `music` and `ambience` play when it shows (feature 15); one
  `outside` is tinted by the moment of the day, times its `shade` (feature
  16), and shows the weather, its own `weather` if it has one (feature 17). Signal
  `door_used(door)` before a door's warp.
- `clear()` frees every map on screen, hook `map_leaving(map)` for each,
  drops the neighbours loading, takes the traveller out of the tree and
  forgets the zone: the next warp starts afresh. Signal `cleared`; it ends
  every interaction and scripted walk (feature 11).
- Saves store positions local to the current map: it is not always at the
  origin.

## Transitions

Screens named `transition_<name>`, extending `WgTransition` (`cover()`,
`uncover()`, both awaited; `seconds` set from `fade_seconds`). They swallow
input while open. The engine ships `none` and `fade` (to black, texture-free).
A game replaces them or adds its own (`transition_circle`) like any screen. An
unknown transition is logged and the warp happens without one.

`config/map.json`:

```json
{ "tile_size": 16, "fade_seconds": 0.25 }
```

A tile size below 1 or a negative length is logged and reset.

## Tests

Map and door scenes are built by the tests in `user://`: no asset. Covered:
ids, both kinds of door, every arrival rule, offsets, warps within a map,
unknown map or point, a warp during a warp, hook and signal order, zone
changes, reload, named and replaced transitions.
