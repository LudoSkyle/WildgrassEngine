# Feature 3 — Walking

Status: implemented.

Characters that walk cell by cell: the player with the keyboard or a pad,
later the characters of the map (feature 6) through the same API. Covers
facing, steps, running, ledges, ice, levels, the player's doors and seams, the
animation contract and the camera. Talking to what you face is feature 4;
followers come later.

## A walker

`WgWalker` (`Node2D`) is the root of a character scene the game makes:

```
Player (WgWalker)
├── Sprite (AnimatedSprite2D)   any size, offset so the feet sit on the cell
├── Shadow (Sprite2D)           optional: shown while jumping
├── Camera (WgCamera)           player only
└── Input (WgPlayerInput)       player only: its controller
```

Its origin is the centre of its cell. Wherever it is put (a spawn point
snapped to the grid's corner, say), it moves to that cell's centre: when it
enters the game, and when a warp or a reload places it.

| Field | Default | |
|---|---|---|
| `facing` | down | |
| `level` | `0` | see tiles: levels and bridges |
| `sprite` | `Sprite` | the `AnimatedSprite2D` |
| `shadow` | `Shadow` | shown while jumping, if present |
| `jumps` | `true` | jumps ledges |
| `slides` | `true` | slides on ice |
| `through` | `false` | blocks no one, blocked by no character |
| `pace` | `0` | its walking pace; 0: the config's (feature 6) |
| `reflects` | `true` | shows its reflection over water (feature 18) |
| `ground_offset` | `8` | its ground line below its origin, where water mirrors it |

```gdscript
walker.turn(Vector2i.LEFT)
walker.step(Vector2i.LEFT)                 # false if refused (bumped)
walker.step(Vector2i.LEFT, true)           # running
walker.step(Vector2i.UP, false, false)     # backing away: keeps its facing
await walker.step_finished
walker.cell                                # Vector2i
walker.is_moving
```

Signals: `turned(direction)`, `step_started(from, to)`,
`step_finished(cell)`, `bumped(direction)` (once per push against an
obstacle). The walkers service relays every walker's
`walker_left(walker, cell, direction, running)` as a step starts and
`walker_entered(walker, cell)` halfway into its last cell, and gives them
all (`all()`).

## Steps

- **A step always goes to its end.** `step()` is refused while one runs.
- **Who decides the next step** is the walker's controller: a child extending
  `WgWalkerController`, asked every frame while the walker is free, and again
  at once when a step ends during a frame, with the time left. A held key
  never stops between cells: after any time T, the walker has gone pace × T,
  however the frames fall. `WgPlayerInput` is one; feature 6 adds others.
- **The pace is chosen when a step starts**: walk (the walker's `pace`, else
  the config's) or run, in cells per second (the `movement` config), then the
  filter hook
  `step_pace(pace, walker, direction, running)`: a bike changes it there.
- `Wildgrass.tiles.can_step()` decides, with the walker passed to its hook: a
  surfboard allows water there. Refused: `bumped(direction)`, the walker faces
  that way and plays its walk in place.
- **A step reserves its target cell, on the level it reaches**: two walkers
  never go to the same cell. Walkers block each other through the tiles'
  `can_step` hook, except that a walker may step into a cell another is
  leaving (feature 6); an interactable that `blocks` (an item on the ground,
  feature 8) blocks its cells the same way; `Wildgrass.walkers.at(cell, level)` finds who stands
  there. `walker.destination` is the cell it ends on, `walker.heading` the
  direction of its step, `walker.can_step(direction)` whether a step would
  start. `walker.place_at(cell, level, facing)` puts it on a cell at once (a
  loaded game, a scene).
- **The level changes** as `Wildgrass.tiles.level_after()` says, and
  `z_index` is twice the level: 0 on the ground, 2 on a level 1 deck. Draw a
  deck of level L at `z_index` 2L − 1, and what covers every walker (roofs,
  treetops) above twice the highest level.
- A warp or a reload during a step abandons it, gives the cell back and puts
  the walker on its new cell. Freed, a walker gives its cells back.

## Ledges and ice

- **Ledge**: a solid tile whose `jump` data (`Vector2i`) is the direction of
  the step. The walker jumps it and lands one cell beyond, if it can step there
  from the ledge. One step of two cells, at `jump_pace`; the sprite rises in an
  arc of `jump_height` pixels while the node stays on the ground (sorting,
  camera, shadow). The other way, or nowhere to land: a bump.
- **Ice**: `ice` data. A step that leads onto ice starts a slide: the walker
  goes on in the direction of that step, legs still, at its pace, until a step
  is refused or it lands off the ice. Nothing is asked of its controller
  meanwhile. `slides = false`: walks on ice as anywhere.

## The player

`WgPlayerInput` drives its walker:

- **Tap to turn, hold to walk**: from a standstill, a direction pressed turns
  the walker; still held after `hold_seconds`, it walks. While walking, a held
  direction steps on at once.
- **The last direction pressed wins**; released, the one still held takes
  over.
- **Run** while the run action is held, decided at each step.
- **Nothing is read** while a screen is open, a warp runs, or the walker
  slides.
- **After a door, the way back is blocked, and only it**: the direction that
  would take the player back (into the door, or out of the exit it arrived
  on), if held on arrival, is ignored until released. Any other held direction
  walks on into the new map.
- Actions are named in the `movement` config (`ui_up`, `ui_down`, `ui_left`,
  `ui_right`, `run` by default) and bound in Godot's input map.

The traveller (`Wildgrass.maps.traveller`) also, on its own:

- lands on a **contact door** → `Wildgrass.maps.use(door)`; else a trigger
  (feature 6), then maybe a wild Pokémon (feature 14);
- tries to step off an **exit door** in its direction → uses it instead of
  stepping, even toward a wall;
- lands anywhere → `Wildgrass.maps.cross()`: linked maps;
- arrives through a warp → faces the direction given.

A door is found by the cell it stands in: one door per cell. A passage of
three cells is three doors, each to its own point.

Crossing a seam takes the traveller out of the tree and back: its facing,
level, reserved cell and animation frame carry on.

## Animation

Animations of the `AnimatedSprite2D`, named `<state>_<direction>`:

| State | When | If missing |
|---|---|---|
| `idle` | standing | first frame of `walk`, paused |
| `walk` | walking, bumping | — |
| `run` | running | `walk`, faster |
| `turn` | turning in place, not looping | none: straight to `idle` |
| `jump` | jumping | `walk` |

Directions: `down`, `up`, `left`, `right`. The filter hook
`walker_animation(state, walker)` may name another state: `bike`, `surf`.
The walk animation runs on from step to step, so feet alternate; it is drawn
for the walk pace and sped up with the pace.

## Camera

`WgCamera` (`Camera2D`) follows its walker.

- **A map with links**: no limits; beyond the maps, the game's clear colour.
  A crossing never moves the camera.
- **A map without links** (a room, a cave): limited to the map; narrower than
  the screen on an axis, centred on it. Limits change only with a warp, under
  its transition.
- A map without a size: no limits.

## Config

`config/movement.json`:

```json
{
	"walk_pace": 4, "run_pace": 8, "jump_pace": 5, "jump_height": 8,
	"hold_seconds": 0.12,
	"actions": { "up": "ui_up", "down": "ui_down", "left": "ui_left", "right": "ui_right", "run": "run", "interact": "ui_accept", "menu": "ui_cancel" }
}
```

Paces are cells per second. A pace or a length not positive is logged and
reset; an action missing from the input map is logged once.

## Tests

Walkers, maps and TileSets are built by the tests, with their own services;
time is advanced by hand and input simulated with Godot's input actions.
Covered: snapping to a cell, steps and their end, distance after any split of
time, paces and the pace hook, a step during a step, bumps, backing away,
reservations between two walkers and across levels, `through`, `z_index`,
ledges both ways and with nowhere to land, slides and how they end,
`slides = false`, tap and hold, the last direction pressed, running, input
while a screen is open or a warp runs, missing actions, the way back after a
door, doors of both kinds, crossing a seam and what survives it, steps cut by
a warp or a reload, settling on arrival, facing after a warp, every
animation, its fallback, feet carrying on between steps, the animation hook,
camera limits and centring, config errors.
