# Feature 18 — Life on the maps

Status: implemented.

What makes a map feel alive under the characters' feet and around them:
tall grass that rustles and hides their legs, footprints in sand, reflections
in water, Pokémon flying over the map with their shadow, things that
twinkle, and the banner naming the place on arrival. Each is set once, on a
tile (feature 2) or as a node; nothing is drawn by hand on a map.

These read a cell's data on **the tile drawn on top** there (the highest
`z_index`, the last in the tree between equals), not the first that sets
it: a jetty over the sea is no water, a flower over sand keeps no prints.

## Tall grass

A tile of tall grass declares, in tile data:

- `front_source` (int, 0: none): the source of its front strip, the same
  atlas coordinates: the bottom few pixels of the tuft, drawn over whoever
  stands on the cell. When a map loads, the engine builds its front layer
  among the map's y-sorted entities, on the same cells, sorted an eighth of
  a cell below their centre (2 px), so a character standing there is in the
  grass up to the waist and nothing follows them as they walk.
- `rustle` (array of atlas coordinates): what the tuft goes through when a
  walker comes halfway into the cell (Mirage: `[7, 8, 8, 7]` of its row),
  `rustle_seconds` (0.07) each, then back to its own; the front strip
  follows. A tuft rustling does not start again.

Every walker shown rustles it, unless its `rustles` is off; a map needs
nothing more.

## Footprints

A tile whose `footprints` data is true keeps prints: a walker leaving it
for the next cell puts a pair there, halfway through its step, one foot each
side of its way, the leading foot changing each step (a zigzag) — so twice
as fast running. A jump or a warp leaves none, nor a walker hidden or
whose `prints` is off. A print darkens the ground
by `darkness` (0.26) for half its life, then fades: `life_seconds` (1) in
all, even once its walker is gone. Prints lie just above the ground layer,
under the rest of the map.

The `footprints` config (`config/footprints.json`): `texture`, a picture of
eight cells of `cell` pixels (8) side by side, two feet for each direction,
down, left, right, up, the left or upper foot first; else a dark oval made
in code. `life_seconds`, `darkness`.

## Reflections

A tile whose `reflects` data is true is water one sees oneself in. A walker
shows its reflection there: its current picture each frame (an
`AnimatedSprite2D`'s frame, a `Sprite2D`'s region), flipped about its ground
line (`ground_offset` below its origin: 8, its feet), lifted back towards
them (`lift`, 5: the empty rows at the bottom of a picture), multiplied by
`tint` (pale blue, 0.45 opaque).

It shows only where it falls on water: going down from its top, the first
stretch of water in each column of cells, a bank ending it; then the widest
run of columns whose water shares some height, cut to that height. So it
rises into view through a step, stops at a bank, and keeps to the water
during a step sideways. It sways by a pixel four times a second. A walker
hidden shows none. It lies
just above the water layer: whatever stands over the water covers it.

- `WgWalker` gains `reflects` (true; false for a Pokémon flying) and
  `ground_offset` (8).
- The `reflections` config: `tint`, `lift`.
- Reflections are drawn once every walker has moved, by a node of the
  engine processed last (`Wildgrass.reflections.show_all()`); `of(walker)`
  gives one.

## Pokémon flying

`WgFlyer`, a node of the map: a species' `character` sheet (feature 12:
four rows, down, left, right, up, of four columns), its wings beating on
columns 0 and 2, drawn `lift` pixels (14) over a shadow (`shadow_offset`,
6); no body, no talk. Its `Sprite` and `Shadow` are made unless its scene
has them.

- Its flight: legs of one to three cells in a straight line within its
  `zone` (cells), a leg cut short at the zone's edge, never turning back
  unless cornered, hovering `rest` seconds between legs (0.3 to 1.6), at
  `pace` cells per second (2.5).
- Or carried by the wind (`drift` 1 east, -1 west): it crosses its zone
  without stopping, a cell and a half past the edge before coming back from
  the other side, its pace varying by a quarter, its way waving a cell
  around its row, its picture bobbing two pixels. Two flyers of the same
  `seed` keep their gap, a flock; each bobs its own way.
- It cries now and then (`cry_every` 10 to 24 s, within `cry_range` cells
  of the player, 4, at `cry_volume`, 0.45), never during a message or over
  another cry (feature 15); missed, it tries again a second later.
- Over a tile whose `reflects` is true, its shadow turns from translucent
  black (`shadow_land`) to dark turquoise (`shadow_water`).
- `wildgrass`: the engine it reads (species, audio, dialogue, maps, tiles),
  the autoload's unless set; `advance(delta)`.

## Twinkles

`WgTwinkle`, put on any drawing (it extends `Node2D`): it swells and pales
by turns, a beat of `period` (1.1 s) and one 3.3 times slower under it, from
`1 - swell` to `1 + swell` of the scene's size (0.35) and down to `dim` of
its opacity (0.35). Something shining at the bottom of the water gets
noticed.

## The place's banner

`WgZone` (`Resource`), what maps of a zone share (`WgMap.zone`, feature 1):
`id`, `name` (a label), `banner` (a style). Found as species are:
registered, else `res://zones/<id>.tres` (paths, `zones`), else a source
(`Wildgrass.zones`). A zone needs no data: without any, no banner, and no
error.

`location_banner` (`WgLocationBanner`) slides down at the top left when the
traveller arrives in a zone whose name differs from the last one shown,
once no transition covers the map (the maps' own, the title's fade into
the game); at once when crossing into a linked map. It slides in `slide_seconds` (0.3), stays `stay_seconds` (2.2),
slides up; a new name while it shows slides it in again. Two maps of one
zone, or two zones of one name (a house's floors), do not show it again; a
zone without a name shows nothing; back at the title, the next map shows
it.

It is replaceable as a screen is (`screens.set_scene()`, the setting
`wildgrass/screens/location_banner`), but put on the screens' layer and
never on their stack, and under every screen: it takes no key, stops no
one, and lets encounters happen. The engine's is a panel in Godot's theme; a game's draws its styles
(`_show_style(style)`: Mirage's wood, metal, stone, cave, forest, beach,
water, sea, light text on the dark ones). Signal `banner_shown(name,
style)` of the zones.

## A Studio project

| Studio | Engine |
|---|---|
| `Data/Studio/zones/<dbSymbol>.json`: `id`, `panelId` | a `WgZone`: `name` its text (file `100010`, line `id`), `banner` `panel_<panelId>` |
| `forcedWeather` | the zone's maps' weather, with the map importer |
| system tags `TallGrass`, sand, water on its tiles | `front_source`, `rustle`, `footprints`, `reflects`, with the tile importer |
| `graphics/particles` (`tall-grass`, `floor_print`…) | the pictures a Studio project's tiles and footprints use |

## Pokémon Mirage, step by step

| In Pokémon Mirage | In the engine |
|---|---|
| tufts on `Background/Grass`, the front strip of source 9 built at load, sorted 2 px below the centre | tile data `front_source`; the engine's front layer |
| rustling `7, 8, 8, 7`, 0.07 s each; cells just left still rustling | `rustle`, `rustle_seconds` |
| `sand` tiles keeping a pair of prints per cell left, zigzag, 26 % darker, 1 s, half at full strength | `footprints`, `darkness`, `life_seconds`; Mirage's `footprints.png` as the texture |
| `water` tiles; the reflection cut to the water, rising through a step, a pixel of sway, 0.45 pale blue | `reflects`, the `reflections` config |
| flyers: species, zone, pace, rest, seed, cries, drift, 14 px up, the shadow turquoise over water | `WgFlyer` with the same settings |
| the bell's twinkle: period, swell, dim | `WgTwinkle` |
| `location` and `banner` on a map; shown when the name changes, after the fade; 0.3 s in, 2.2 s | the map's zone, a `WgZone` with its name and style; the same times |
| moving water: a shader on the water tiles | the game's shader, as before |

Better than Mirage: a column whose water shares no height with its
neighbours' starts a run of its own instead of hiding the reflection.

## Later

- Surfing, bikes, puddles splashing: with their features.
- Studio's tile system tags read into tile data: with the tile importer.
- Studio's `forcedWeather`: with the map importer.
- Pixel defaults for cells other than 16 px (`ground_offset`, the oval,
  the flyer's lift and shadow): set by the game meanwhile.

## Tests

Maps, tiles, sprites, species, zones and Studio files are built by the
tests; steps, prints, reflections, flyers, twinkles and the banner are
advanced by hand.
Covered: front strips built once among the entities, sorted below the
centre; a tuft rustling
halfway in, once while rustling, never off the grass, a new map getting its
own, a rustle dropped with its map. A pair of prints each side of the way above the ground layer, the
leading foot changing for each walker, holding then fading after its walker
is gone; none off the data, under a jetty or after a jump; the config's
picture by direction and foot, a missing one reported once and the oval
drawn; prints gone with their map; a wrong config corrected. A reflection flipped, tinted, following the
frame, above the water layer; cut at a bank and rising through a step, never
taken up past a bank, whole when it starts in the water; only the columns
over water, a flipped picture cut its way, the height columns share, the
widest run winning and a column apart starting its own; swaying; none under
a jetty, off water, without the data or for a walker that does not reflect;
a sprite's region; gone with its walker, made anew on its next map. A flyer's wings and row, shadow
under its picture; legs straight within its zone, never back, hovering;
cornered in a corridor, hovering in a single cell; carried by the wind,
wrapping, its pace and lane varying, bobbing; a flock keeping its gap;
crying over the player, not during a message, trying again; its shadow over
water. A twinkle's range and beat around the scene's size and tint. Zones
registered, the folder's, a source's, an unknown one logged; the banner
after the transition and under a fade still open, off the screens' stack
and under the screens, sliding, staying, sliding
up; only a new name, none without a name or without data; crossing into a
linked map; again after the title; a game's banner and its styles, a wrong
scene logged. Studio's zones named by their line with their panel, a broken
file logged once.
