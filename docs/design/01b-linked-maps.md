# Feature 1b — Linked maps

Status: implemented.

A map can be linked to others on its four sides. Linked maps are shown around
the current one, and walking across the seam changes the current map with no
transition. Unlinked edges stay closed; doors still lead anywhere.

## Declaring links

On the `WgMap`, in the inspector:

| `WgMap` field | Default | |
|---|---|---|
| `size` | `(0, 0)` | width and height in tiles; required when `links` is not empty |
| `links` | `[]` | `WgMapLink` resources |

| `WgMapLink` field | |
|---|---|
| `side` | `north`, `east`, `south` or `west` |
| `map` | id of the linked map |
| `offset` | tiles the linked map is shifted right (north, south) or down (east, west) |

```
route_1 (size 40×30)
  links: south → start_island, offset -6
start_island (size 52×40)
  links: north → route_1, offset 6
```

Each map declares its own links: the reverse link is never guessed.

## Layout

- Maps live in one world. A warp puts the new current map at the origin; a
  crossing moves nothing, so the current map can sit anywhere.
- The neighbours of the current map are instanced and placed against it. Only
  one ring: the neighbours of a neighbour are not shown.
- Neighbours are full maps: they process, their entities move.
- `Wildgrass.maps.rect(map)`: the map's global rectangle, from `size`. The
  camera (feature 3) uses it.
- Each map sorts its own entities; between maps, the one whose origin is
  lower draws on top: the default host is y-sorted.
- **Ground layers need a negative `z_index`.** Maps draw one after the other:
  at `z_index` 0, a neighbour's ground covers half of whoever walks across the
  seam.

## Crossing

```gdscript
Wildgrass.maps.map_at(global_position)  # WgMap shown there, or null
Wildgrass.maps.cross()                  # call after each step
Wildgrass.maps.neighbours               # Array[WgMap]
```

Feature 3 reads tiles through `map_at()` (null: outside every map, blocked; a
map with no size covers everything) and calls `cross()` when the traveller
lands on a tile. If the traveller now stands in a neighbour:

1. the neighbour becomes `current`; the traveller moves into its `entities`,
   keeping its global position and facing; it leaves and re-enters the tree,
   but cameras under it keep their view; `neighbours` lists the maps already
   shown that the new map links to;
2. signal `zone_changed(old, new)` if the zone differs;
3. signal `map_changed(map)`;
4. the other maps are freed; missing neighbours load in the background, each
   added as soon as it is ready; `is_loading_neighbours` is true until signal
   `neighbours_loaded`.

No transition, no `traveller_arrived`. `cross()` does nothing during a warp.
A warp during background loading drops it.

Warps, reloads and hooks with neighbours: see feature 1.

## Errors

| Case | Result |
|---|---|
| links without `size` | error; the map shows alone |
| unknown linked map | error; that side stays closed |
| a linked map without `size` | error; that side stays closed |
| an empty link, or a map linked to itself | error; link ignored |
| the same map linked twice | error; first link kept |
| no reverse link, or a mismatched offset | warning; shown anyway |
| two neighbours overlapping | warning; `map_at()` returns the first |

## Tests

Linked maps are built by the tests in `user://`. Covered: placement on each
side with offsets, `map_at()` inside, on the edges and outside, crossing and
crossing back, signal order, the traveller re-entering the tree, the camera
after a crossing, neighbours processing, kept and freed neighbours, background
loading and `neighbours_loaded`, hooks for neighbours, warps to a neighbour,
reloads away from the origin, a warp or a freed host during loading, every
error above. The ground rule is checked in a window: it cannot be seen without
one.
