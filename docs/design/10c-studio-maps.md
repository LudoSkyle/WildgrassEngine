# Feature 10 ter — Studio maps

Status: in progress (tiles, layers, passages, tags, animated tiles, bridges
and links; see *Later*).

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
`res://maps/studio_tiles.tres`, the textures to `res://maps/tiles/` (an
animated tileset's frames beside its picture, `<picture>-animated.png`). A map
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
- A tileset's animated tiles are Tiled animations: `<tile id>` and its
  `<frame tileid duration>` (ms), any tiles of the tileset in any order.
- `Data/Studio/maplinks/<dbSymbol>.json`: a map's neighbours. `id`, `mapId`
  (the map they are shown around), and `northMaps`, `eastMaps`, `southMaps`,
  `westMaps`: lists of `{mapId, offset}`.
- `Data/configs/display_config.json`: `tilemapSettings.autotileIdleFrameCount`,
  the game frames (at 60 a second) of a step of animated tiles; 6 if absent.

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

### Animated tiles

Studio plays a frame for whole steps of its idle frames: `max(1, ms div
(idle × 1000 div 60))` steps of `idle / 60` s. With the usual 6, a step is
100 ms: 300 ms shows 300, 150 shows 100, 50 shows 100. Every tile of a same
rhythm is in step with the others, whatever its map.

| Studio | Godot |
|---|---|
| a tileset with animated tiles | one more source, `<tileset> animated`: its texture a row per animated tile, the frames side by side |
| a cell drawing an animated tile | that row's tile, its frames and their durations; a flip is an alternative tile, as for any tile |
| an animation showing a tile outside the picture | a problem; the tile stays still |

Godot plays every tile animation on one clock, so tiles of a same rhythm keep
in step, as Studio's.

Studio draws the layers of a cell into one picture before animating it, so
when two animated tiles of different lengths share a cell, its frames run
out together; the importer keeps each layer its own animation, each tile
playing as its tileset says.

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
| 402 / 404, bridge crossed up and down, left and right | `floor` 1: a bridge's deck |
| 426 to 430, heights 2 to 6 | `ramp` true, `floor` 1: where a walker climbs onto a deck |
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

### Bridges

Studio gives a character a height: 1 on the ground, the number of a height
tag it steps on (heights 0 and 1 are the ground). From a height of 2 up, a
character steps onto a bridge's deck (a bridge tag, crossed its way) and
stays on it, the ground's passages forgotten, until it steps back onto the
height it came from; on the ground it goes under the deck, the ground's
passages holding.

The engine's levels say the same (tiles: *Levels and bridges*):

| Studio | Engine |
|---|---|
| a height of 2 or more | a ramp up to level 1: stepping onto it from the ground, the walker is on the deck's level |
| a bridge's deck | a floor of level 1: crossed on level 1 only where the deck goes, nothing of the ground blocking |
| back onto a height of 0 or 1, or any cell off the deck | stepping off a ramp onto a cell without the floor: back on the ground |
| under the deck | level 0: the ground's passages |

A deck needs a second level in the `map` config, which the engine has by
default. On the deck the walker is drawn over the y-sorted tiles (`z_index`
2), as Studio draws a character raised by its height; under it, among them,
on its row. One case differs: under a deck, Studio draws a character
(height 0 there) below a tile of priority 1 on the row above; the engine
draws it over.

Checked on the sample project's maps with heights and bridges, walked from
every ground cell with Studio's rules (height, bridge entered and left) and
with the engine's answers side by side: they agree on every step, on and
under the decks.

### Links

Studio shows a map's neighbours against its sides, from the first map link
(by `id`) whose `mapId` is the map's; walking off the map onto one of them
makes it the current map, with no transition. The engine's links (feature
1b) do the same:

| Studio | Engine |
|---|---|
| a map link's `northMaps`, `eastMaps`, `southMaps`, `westMaps` | the map's `links`, a `WgMapLink` each, in that order |
| `{mapId, offset}` | `map`: that map's dbSymbol; `offset`: as is, columns right (north, south) or rows down (east, west) |
| several maps on one side | several links on that side |
| a link to no map (0, or an id no map has), to the map itself, to a map already linked | a problem; left out |

Studio draws a map and its neighbours as one picture, so a tall tile of one
hides a character of the other as it would its own. The imported map's root
is y-sorted: its entities sort with those of the maps beside it.

Stepping onto a neighbour, Studio checks the cell stepped onto only: solid,
water, or its passage bit for the step's direction (its far side, the one a
step onward would cross); the engine checks the border crossed, as on any
step: the near side of that cell and the side of the cell left. They differ
only where one of these cells has an edge; the sample's seams have none.

Checked on the sample project's linked maps: along each linked edge, the
neighbour shown and every step across agree with Studio's rules, and a
walker crosses and comes back.

## Later

- **Events** (doors, characters, signs, items): from the map's events.
- Studio's switch turning every link off, and its older overlapping links
  (neighbours sharing a three-tile strip), a display setting.
- **Music** (`bgm`, `bgs`) and the encounter step count.
- The editor's menu to import from Godot, and importing again only what
  changed (the `.tmx`'s `sha1` Studio keeps).

## Tests

Tilesets, pictures and maps are written by the tests, tiny: layer levels from
names and groups, hidden and special layers, csv and base64 data, flipped
tiles, the key colour and the halving, passages (solid, edges, bush,
counter), tags and their data, a tag on an empty cell dropped, the priority
of each layer and the cells moved, the scene's tree, a second map sharing the
TileSet; bridges: a deck's floor, the ramps up to it, crossing over the
water and going under, a TileSet from an older import given the new data;
links: the first map link by id, the sides in order with their offsets,
several on a side, a link to no map, to itself or twice told and left out,
the neighbours placed as Studio places them and stepped into across the
seam, the map becoming current;
animated tiles: the strip of frames, the steps of each frame (and of
another idle count), a flipped one, one among the entities, an animation
outside its picture, a second map and a second import adding no source. The
whole sample project is checked outside the engine, cell by cell, against
Studio's own converted data: its pictures, each frame of its animated tiles
and their rhythms.
