# Feature 16 — Day and night

Status: implemented.

The hour of the game, the moments of the day it falls in, the tint they
give the maps outside, the lights that come on at night, and the story
conditions that follow them.

## The hour

```gdscript
Wildgrass.daytime.hour()          # 18.5 at half past six
Wildgrass.daytime.moment()        # &"dusk"
Wildgrass.daytime.forced_hour = 23.0   # debug and tests; -1: the hour again
```

- The `daytime` config's `source`: `real`, the player's clock (it is night
  in the game when it is night at home); or `game`, an hour of its own that
  starts at `start_hour` and moves `minutes_per_second` game minutes each
  second of the game clock (feature 0: paused with the game, sped up with
  it), saved with the game (a part, `daytime`), a new game at
  `start_hour`. `day()`: the days gone by since the game started (`game`), or
  the day of the year (`real`); `weekday()`: 0 for Monday to 6.
- `forced_hour`, not saved, wins over both.

## Moments

The config's `moments`, each `{tint, light}`, and `keys`, the day as marks
`[hour, moment]` in order: between two marks the tint and the light glide
from one to the other; two marks of the same moment make a plateau. By
default, Pokémon Mirage's day:

| Moment | Tint | Light | Fully |
|---|---|---|---|
| `night` | dark blue `(0.38, 0.44, 0.78)` | 1 | 20:30 to 5:30 |
| `dawn` | rosy `(0.96, 0.86, 0.92)` | 0 | 6:30 |
| `day` | none | 0 | 7:30 to 17:30 |
| `dusk` | orange `(1, 0.76, 0.58)` | 0 | 19:00 |

- `tint(hour)`, `light(hour)`: the glide at that hour (now by default);
  `moment(hour)`: the moment of the last mark reached. A tint is a colour,
  `"#rrggbb"` or `[r, g, b]`. Marks out of order, or of a moment the config
  lacks, are logged and left out.
- Signal `moment_changed(old, new)` as the hour crosses a mark of another
  moment.
- A story condition reads it: `time:night`, `!time:day` (feature 7).

## The maps outside

`WgMap` gains `outside` (false) and `shade` (white). While the current map
is outside, everything the maps draw (the maps, the player, the
characters) is tinted by the moment's tint times the map's shade: a wood in
half-light darkens day and night alike. A map inside is never tinted;
screens never are.

Two shader globals follow each frame, for a game's shaders (windows lit at
night, a haze that fades): `day_tint` (the tint, white inside) and
`night_light` (the light, 0 inside). The engine declares them unless the
project does. `map_tint()` and `map_light()` give them; the tint is a
`CanvasModulate` under the maps' host (`canvas_modulate`).

## Lights at night

`WgNightLight`, a `PointLight2D` the engine fills with a soft round glow
of `radius` pixels (made in code, no asset) when it has no texture: its
energy is `brightness` times the moment's light outside (0 inside), so it comes on as night falls and goes out as it leaves; `flicker`
and `reach` make a flame waver (0: steady). A street lamp, a window's glow
are scenes of the game with one inside.

## The `daytime` config

`config/daytime.json`:

| Field | Default |
|---|---|
| `source` | `real` |
| `start_hour` | 12 |
| `minutes_per_second` | 1 |
| `moments`, `keys` | above |

## A Studio project

Studio keeps its day and night in its RPG Maker switches and variables and
its tone sets in code, not in its data: a Studio project gets the engine's
moments (or its own `daytime` config), the real hour as Studio uses by
default. Its switches of the moments, read by its events: with the event
importer.

## Pokémon Mirage, step by step

| In Pokémon Mirage | In the engine |
|---|---|
| the machine's hour | `source` `real` |
| night, dawn, day, dusk; the marks `KEYS`, gliding, plateaus | the default `moments` and `keys` |
| `metadata/daylight` on a map outside, a `CanvasModulate` added | `WgMap.outside` |
| `metadata/shade` multiplying the tint | `WgMap.shade` |
| interiors and the interface never tinted | the same |
| `night_light`, `day_tint` shader globals, set each frame | the same |
| street lamps and window glows: `light()`, flicker, reach, a glow without asset | `WgNightLight` in the game's scenes |
| windows lit by a shader on the house tiles, the haze over the outside | the game's shaders, reading the globals |
| Debug → Hour, `set_hour()`, not saved | `forced_hour` (the debug tools, feature 20) |
| tests at noon | the tests set `forced_hour` |

## Later

- Seasons, a calendar of months: when a game needs them.
- Weather's own tint under the moment's: with weather (feature 17).
- Studio's switches of the moments: with the event importer.

## Tests

Maps, configs and lights are built by the tests; the hour is forced or the
game's own advanced by hand; the shader globals are recorded, the rendering
server keeping no value headless.
Covered: the player's clock and weekday, a forced hour winning, the game's
own hour moving with the game clock and counting days, never going back;
the tint and the light gliding and holding, the moment of the last mark,
the day going round before the first mark and after the last; tints as
text and numbers; a moment change told once; `time:` in a story
condition; the game's own hour saved and a new game at its start; a wrong
config corrected. A map outside tinted by the moment and its shade, inside
or no map never; the shader globals once enabled; a night light coming on
with the night, wavering, steady at 0, out by day, half at dusk's end.
