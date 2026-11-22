# Feature 17 — Weather

Status: implemented.

The weather outside: what falls (rain, snow, sand), what drifts over the
map (fog, a blizzard's veil), the tint it gives the screen, and which
weather is on. The engine ships the code and no image: a weather's pictures
are the game's.

## Weathers

`WgWeather` (`Resource`), one per weather:

| Field | |
|---|---|
| `id`, `name` | `name` a label |
| `category` | `none`, `rain`, `hail`, `sandstorm`, `sun`, `fog`: what battles will read |
| `particles` | the pictures that fall; a particle's picture follows its rank |
| `particle_velocity` | pixels per second, along which they fall: the slope of their pictures |
| `particle_count` | 60 |
| `splashes`, `splash_share` | a splash's pictures, and the share of particles that are splashes (rain: half) |
| `floating` | snow: each fall wavers, faster low on the screen, a step aside |
| `layer`, `layer_velocity` | a picture tiled over the map, drifting (fog, a blizzard, sand) |
| `tone`, `gray` | added to the screen (a `Vector3`, each channel -1 to 1), and taken from it first, 0 to 1 (a rain: -30 / 255 each, gray 10 / 255) |
| `pulse`, `pulse_seconds` | the tone's strength beating (the sun) |
| `sunlight` | the tone fades as night falls (the sun) |

Found as species are: registered, else `res://weather/<id>.tres` (paths,
`weather`), else a source. `none` is the engine's own: nothing falls,
nothing tints.

## How it falls

- **Every particle lives on its own**: it is born at a random place in the
  view, moves along its velocity, and dies after a random distance, to be
  born again elsewhere. Nothing scrolls as a block.
- **Anchored to the map**: particles and the layer have places in the world;
  the view only says where one is born or wraps. Walking, the rain stays
  where it falls.
- **A splash** follows no drop: placed at random, it lives 0.3 to 0.5
  seconds and shows only its last 0.2.
- **The layer** tiles enough copies to cover the view plus one row and one
  column, put back as they leave it.
- **The tone** reads the screen already drawn: it takes the day's tint off
  (feature 16, `day_tint`), adds the weather's tone to the world as it is by
  day, and puts the day's tint back, so rain darkens night in proportion as
  it does day. The sun's fades as night falls (`1 - night_light`).
- Only on a map outside (feature 16); never on screens. `WgWeatherLayer`,
  under the maps' host above the maps (`z_index` 51), draws it
  (`Wildgrass.weather.layer`): `show_weather()`, `view` (the camera's),
  `advance(delta)`, `seed()`.

## Which weather

```gdscript
Wildgrass.weather.current = &"rain"      # the weather of the maps outside
Wildgrass.weather.weather()              # the WgWeather on now
```

- `current`: the weather on, `none` at the start; not saved (a game keeps
  it in its story if it must).
- `WgMap.weather`: a map's own (a desert always in a sandstorm); empty: the
  current one. Signal `changed(old, new)`.
- `cycle()`: the next weather known, then `none` (the debug tools, feature
  20).

## A Studio project

Studio names six weathers by number, its pictures in its engine, not in its
project: a Studio project writes its `WgWeather` resources with its own
pictures. Studio's numbers become the engine's ids: 0 `none`, 1 `rain`,
2 `sun`, 3 `sandstorm`, 4 `snow`, 5 `fog`; a zone's `forcedWeather` becomes
its maps' `weather` with the map importer.

## Pokémon Mirage, step by step

| In Pokémon Mirage | In the engine |
|---|---|
| eight weathers: clear, rain, heavy rain, snow, blizzard, sandstorm, sun, fog | eight `WgWeather` resources with Mirage's pictures and numbers |
| 60 sprites, half of a rain's splashes, three lengths of drop by rank | `particle_count`, `splash_share`, `particles` by rank |
| drops along their own slope, dying after a random distance; snow floating | the same; `floating` |
| splashes placed at random, 0.3 to 0.5 s, shown the last 0.2 | the same |
| everything anchored to the map | the same |
| the tiled veil of blizzard, sand, fog | `layer`, `layer_velocity` |
| the tone added after taking gray, under the day's tint; the sun beating, gone at night | `tone`, `gray`, `pulse`, `sunlight` |
| outside only | the same |
| rain at three tenths of its pace | its `particle_velocity` |
| Debug → Weather, not saved | `cycle()`, `current` |

## Later

- Fading from one weather to the next, a storm's lightning: when a game asks.
- Weather in battles: with battles, from `category`.
- Studio's zones forcing a weather: with the map importer.

## Tests

Weathers, pictures and maps are built by the tests; the layer is advanced
by hand, its chance seeded, its view set.
Covered: `none` the engine's unless the game has its own; weathers
registered, else the folder's, else a source's, an unknown one logged; the
weather on changing and told once, an unknown one showing none; a map's
own winning while current; `cycle()`; pictures by rank and splashes by
their share. Sixty particles, half splashes; drops along their slope,
born again after their distance; drops born around the view, splashes
shown only at the end; particles anchored when the view moves; snow
floating; the layer tiling the view plus one and drifting; the tone set,
shown, hidden without one; the sun beating and gone at night; the weather
on maps outside only.
