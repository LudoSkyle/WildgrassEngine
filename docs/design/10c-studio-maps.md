# Feature 10 ter — Studio maps

Status: in progress (tiles, layers, passages and tags; see *Later*).

A Studio project draws its maps in Tiled. The importer turns each into a
plain Godot map, once: a `WgMap` scene, one `TileMapLayer` per Tiled layer,
the TileSet they share and its textures. The game then reads scenes only, as
any Godot project; the scenes are retouched in Godot like any other. The
rules are Studio's own (its conversion of a `.tmx`, then what the existing
engines read of it), ported and checked map by map against the sample
project's converted data.

```bash
godot --headless --path <game> -s res://addons/wildgrass/studio/import_maps.gd -- <Studio Data folder> [map dbSymbol…]
```

Without map names, every map of `Data/Studio/maps` is imported. Each goes to
`res://maps/<dbSymbol>.tscn` (the `maps` path), the TileSet to
`res://maps/studio_tiles.tres`, the textures to `res://maps/tiles/`. A map
imported again is written again; the TileSet keeps the tiles of every map.

## What a Studio map is

- `Data/Studio/maps/<dbSymbol>.json`: `id`, `tiledFilename` (the `.tmx`
  under `Data/Tiled/Maps`, without its extension), `bgm`, `bgs`,
  `stepsAverage`.
- The `.tmx`: 32 px tiles, external tilesets (`.tsx`) only, layers in csv or
  base64 (gzip, zlib).
- Its layers, in document order, groups entered:
  - a layer is read if visible, or if it is one of the special names below;
    a group is entered if visible, or if its name starts with `system`;
  - **its level** `z` (0 to 5) is its name's last character when it is a digit
    from 1 to 6, minus one (`Tree_rgt_top_4`: 3); otherwise its group's,
    where a group named `z=N` gives N − 1; at the top, 0.
- **Special layers**, never drawn: `passages` (tileset `passages.tsx`),
  `systemtags`, `systemtags_bridge1`, `systemtags_bridge2`
  (`systemtags.tsx`), `terrain_tag` (`terrain_tag.tsx`). A cell's value is
  its tile index in that tileset; a system tag is 384 plus it.
- Every art tileset is drawn at 32 px but **is a 16 px picture doubled**, and
  keys out a colour (`<image trans="f05ba1">`) instead of alpha.

## What the importer makes

### Textures and the TileSet

- Each art tileset's picture, its key colour made transparent, halved: a
  16 px texture, as the engine's `tile_size` is 16 and Studio's own display
  draws them at half size.
- One TileSet for the project's maps, 16 px tiles, a source per Tiled
  tileset (its atlas with the tiles maps use; a flipped tile is an
  alternative tile), plus three sources for the special tilesets.
- Physics layers: the `map` config's first solid and edge layers (1 and 4).
  Data layers: those below.

### Passages

A passage is a byte. Bits 0x01, 0x02, 0x04, 0x08 block leaving or entering
the cell down, left, right, up; 0x40 is a bush, 0x80 a counter.

| Passage | Tile of the `passages` source |
|---|---|
| all four bits | a solid square |
| some bits | an edge strip along each blocked side (3 px wide) |
| 0x40 | data `bush` true |
| 0x80 | data `counter` true: talking reaches across it |

Stepping from one cell to the next needs both passages to allow it, which an
edge on either side of the border gives: the engine's edges are crossed
neither way.

### System tags and terrain tags

| System tag | Data |
|---|---|
| 384, empty | `covers`: hides the tags of the layers below |
| 385 ice | `ice` true, `encounter` `ice` |
| 389 grass, 390 tall grass, 391 cave, 397 mountain, 398 sand, 399 pond, 405 sea, 406 under water, 407 snow | `encounter`: `grass`, `tall_grass`, `cave`, `mountain`, `sand`, `pond`, `ocean`, `under_water`, `snow` (the names the Studio layer gives encounter groups) |
| 392 / 400 / 408 / 416, jumps right, left, down, up | `jump`: `(1, 0)`, `(-1, 0)`, `(0, 1)`, `(0, -1)` |
| every tag | `system_tag`: its name (`wet_sand`, `rapids_left`, `stairs_down`…), for a game's own rules |

A terrain tag is data `terrain_tag` (int). Tags and passages are read from
the top layer down: `systemtags_bridge1` over `systemtags`.

A tag or a passage painted on a cell with no drawn tile is dropped, as Studio
drops it.

### The scene

```
map009 (WgMap)          size: the .tmx's; zone: the zone listing the map
├── Ground_1 …          the level-0 layers, in order, z_index −1
├── Entities            y-sorted: the walkers, and…
│   ├── Tree_lft_top_4  …the layers of level 1 and up, y-sorted per cell
│   └── …
├── Passages            hidden, in this order: passages, terrain tags,
├── TerrainTags         system tags, a bridge's tags last (read first)
├── SystemTags
└── SystemTagsBridge1
```

**What hides whom.** Studio gives each drawn tile a priority from 0 to 5:
0 is under every character; a tile of priority p on row R covers a character
on row Rc unless Rc − R ≥ p. A layer of level z has priority z, with two
cases where Studio decides per cell and the importer moves those cells to a
layer of their own (`<layer> p<k>`):

- among the tiles of level 2 and up on a cell, all take the highest's
  priority;
- on a bridge cell (a `systemtags_bridge` tag), levels 1 to 3 take 3, levels
  4 and 5 take 5.

In Godot a layer of priority p ≥ 1 is y-sorted among the entities, each cell
at its centre plus `16·p − 1` px: a walker, sorted at its cell's centre,
draws over it exactly from row R + p down.

## Later

- **Animated tiles** (`TECH-Animations.tsx`): Godot animations built from
  Tiled's frames, durations rounded down to 100 ms as Studio does.
- **Bridges**: `systemtags_bridge1`, `ZTag` ends, a walker's height: the
  engine's `floor` and `ramp`, and drawing a walker on a deck among the
  y-sorted tiles instead of above them.
- **Links** (`Data/Studio/maplinks`): `WgMapLink`s, with their offsets.
- **Events** (doors, characters, signs, items): from the map's events.
- **Music** (`bgm`, `bgs`) and the encounter step count.
- The editor's menu to import from Godot, and importing again only what
  changed (the `.tmx`'s `sha1` Studio keeps).

## Tests

Tilesets, pictures and maps are written by the tests, tiny: layer levels from
names and groups, hidden and special layers, csv and base64 data, flipped
tiles, the key colour and the halving, passages (solid, edges, bush,
counter), tags and their data, a tag on an empty cell dropped, the priority
of each layer and the cells moved, the scene's tree, a second map sharing the
TileSet. The whole sample project is checked outside the engine, cell by
cell, against Studio's own converted data.
