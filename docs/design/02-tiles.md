# Feature 2 — Tiles

Status: implemented.

What a cell is made of, read from the map's TileSets: what blocks, on which
level, what can't be crossed between two cells, and named tile data (sand,
water, ledge…). Walking (feature 3) and every feature that reacts to the
ground ask here; none reads tiles itself. Everything is set up in Godot's
TileSet editor.

## Cells

Cells are world cells: `floor(global_position / tileSize)`. Linked maps share
them; each question goes to the map shown there (`Wildgrass.maps.map_at()`).
Each tile layer is looked up in its own grid, at the cell's centre.

```gdscript
Wildgrass.tiles.cell_of(global_position)          # Vector2i
Wildgrass.tiles.center_of(cell)                   # Vector2, global
Wildgrass.tiles.is_solid(cell, level)             # a tile blocks the cell
Wildgrass.tiles.has_edge(cell, direction, level)  # a wall between cell and the next
Wildgrass.tiles.can_step(cell, direction, level)  # every rule below
Wildgrass.tiles.level_after(cell, direction, level)  # the walker's level after the step
Wildgrass.tiles.data(cell, &"water")              # tile data, or null
```

`level` defaults to 0, the ground. A direction other than up, down, left or
right, or a level the `map` config does not have, is logged and refused.
Outside every map, a cell is solid.

## What blocks

Collisions are drawn per tile as physics polygons: any shape, tiles of several
cells included, flipped or turned tiles too. To block a tile, never a body
placed on a map by hand.

The engine reads those polygons from the TileSet itself, without the physics
server: the answer is right the moment a map is added, neighbours loaded in
the background included, whatever viewport shows the map. **Every polygon of
every tile layer blocks**, unless the layer is disabled or has collisions
off: what the editor shows is what blocks, exactly where Godot's physics would
block. Under a
bridge or a jetty, the water is an alternative tile without collision.

Each level has two physics layers, named in the `map` config by their layer
numbers (1 to 32, as in Godot's inspector):

| | Asked | Level 0 default |
|---|---|---|
| solid | a point at the cell's centre | layer `1` |
| edges | two points, 2 px each side of the border | layer `4` |

Edges are thin strips along a tile's side: the top of a cliff you can stand
on but not climb, a fence or a railing between two cells.

## Levels and bridges

A walker is on a level: 0 is the ground, 1 a bridge deck, and so on. Feature 3
keeps each walker's level; tiles answer for the level asked.

- **Collisions are per level**: a level only sees its own physics layers. A
  boat under a bridge meets the river banks, not the railings; a walker on the
  bridge meets the railings, not the water.
- **`floor` (int)**: the level of the deck a tile carries. Above the ground,
  a cell exists only where its `floor` is that level: no walking on air.
- **`ramp` (bool)**: the ramp or stairs at a bridge's end, with the deck's
  `floor`. Stepping onto it takes the walker up to that floor, from any side;
  stepping off it onto a cell without that floor takes it back to the ground.
  `level_after()` tells walking the new level.
- Drawing a walker over or under the deck is feature 3's: its `z_index`
  follows its level.

## Tile data

Godot custom data layers, read by name, on every tile layer, from the top
down (highest effective `z_index`, then last in the tree):

- **The first tile that sets the data decides.** "Sets" means a value other
  than the layer's default (`false`, `0`, `(0, 0)`, `""`): a flower drawn over
  sand leaves the cell sandy.
- **`covers` (bool)**: the tile hides the data of the tiles below it. A jetty
  over the sea covers, so the cell is not water.
- Nothing set: the layer's default, or null if no TileSet of the cell has that
  data layer.

The engine fixes no other names: each feature documents those it reads, and a
game adds its own in its TileSets. Wild encounters read `encounter` (a
terrain name) and `encounter_area` (feature 14); life on the maps reads
`front_source`, `rustle`, `footprints` and `reflects` on the tile drawn on
top (feature 18).

## Stepping

`can_step(cell, direction, level)` is true when the next cell is in a map, has
a floor on the level the walker ends on (`level_after()`), is not solid on
it, and no edge stands between the two cells, on the level left nor the level
reached: a ramp's railings keep out who comes from its side. Then
it runs the filter hook `can_step(allowed, cell, direction, level, walker)`:
characters, objects, surfing, bikes add their rules there. `can_step` takes
an optional `walker`, handed to the hook.

## Imported maps

The Studio map importer (feature 10 ter, `10c-studio-maps.md`) makes these
from a Studio project's maps. Studio projects draw their maps in
Tiled, and Studio turns them into RPG Maker XP map data; older projects were
made in RPG Maker XP directly. Both end up as the same tile properties, and
each has a place here.

| Tile property | Here |
|---|---|
| passage, four directions | solid polygon when all four block, edges otherwise; the importer resolves which layer wins |
| system tag | data, by name; "empty" is `covers` |
| terrain tag | data `terrain_tag` |
| height tags | `ramp`, with the `floor` reached |
| bridge tags | `floor`, and level 1 edges along the sides |
| priority | the tile's `z_index` |

## Config

`config/map.json`:

```json
{ "tile_size": 16, "fade_seconds": 0.25, "solid_layers": [1, 2], "edge_layers": [4, 5] }
```

One entry per level, as many in each list; only level 0 by default. Lists of
different lengths, empty, or with a layer outside 1–32 are logged and reset.

## Tests

TileSets and maps are built by the tests, textures included, in memory: no
asset. Covered: cells and centres, negative positions, solid tiles,
multi-cell tiles, flipped and turned tiles against Godot's physics, disabled
layers, edges seen from both sides of a border, each level's own layers,
a bridge crossed over and under, ramps entered from the side, railings,
walking on air, the stepping hook and the walker, bad directions
and levels, cells outside every map and in a neighbour, a layer with bigger
tiles, data from the top down, unset values, `covers`, missing data layers,
effective `z_index`, configured layers.
