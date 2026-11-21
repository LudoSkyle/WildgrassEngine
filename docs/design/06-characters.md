# Feature 6 — Characters

Status: implemented.

The characters of the maps: how they move by themselves, how a script moves
them, how they talk, the cells that react when the player steps on them, and
guarded passages. A character is a `WgWalker` (feature 3); what it says may
depend on the story (feature 7); where it stands is saved with the game
(feature 9).

## A character

A scene the game makes, placed in a map's `Entities`:

```
Fisher (WgWalker)                pace 2: slower than the player
├── Sprite (WgCharacterSprite)   sheet: a 4 × 4 character sheet
├── Wander (WgWander)            how it moves by itself: a controller
└── Talk (WgTalk)                what it says
```

`WgWalker.pace` (cells per second, `0`: the config's) sets its walking pace;
running stays the player's.

## Moving by itself

A controller (`WgWalkerController`, feature 3) decides; the engine gives
three, a game writes others.

| Controller | Moves |
|---|---|
| none | stands, facing its `facing` |
| `WgWander` | after a pause of `pause` seconds (a range), turns to a random direction, and steps that way `step_chance` of the time (0.7) if the cell is in its `area` (a `Rect2i`) or carries its `tile_data` (`&"grass"`: it stays in the grass, whatever its shape) |
| `WgPatrol` | walks to each cell of its `route` in turn, in a straight line, and loops; waits while someone is in the way |

- `area` and `route` are cells of the character's own map, wherever that map
  is shown (a neighbour sits elsewhere in the world). Neither leaves the map.
- A wanderer never steps onto a ledge or onto ice: it would leave its area
  with no way back.
- **Nobody moves by themselves while a screen is open, a warp runs, or the
  player is held by an interaction** (the `movement` config:
  `"still_during_dialogue": true`). The walker stops asking its controller then,
  so a game's controllers obey too. Characters of linked maps on screen move
  as well.

## Moving by script

For scenes, through the walkers service: each call returns once done, `true`
if the walk ended, `false` if it was cut short.

```gdscript
await Wildgrass.walkers.walk(guard, [Vector2i.LEFT, Vector2i.LEFT, Vector2i.UP])
await Wildgrass.walkers.walk_to(guard, Vector2i(12, 7))   # finds its way
await Wildgrass.walkers.walk(guard, [Vector2i.DOWN], {"face": false})   # backs away
guard.turn_toward(player)   # along the axis it is furthest on
```

- While a script moves it, its controller waits.
- Someone in the way: it waits for the cell, up to `patience` seconds (2),
  then gives up (`false`). `{"skip_blocked": true}` skips that step instead.
- `walk_to()` takes world cells, like `walker.cell`. It searches a path
  through what `can_step` allows, over a few frames, visiting at most
  `path_cells` cells (config, 400); none: `false`.
- Cut short: a warp, a reload or back to the title, the walker freed, or
  another `walk()` for it,
  which takes over. The service holds the wait, so the caller always resumes.

## Talking

`WgTalk` extends `WgInteractable` (feature 4), inside a character:

| Field | |
|---|---|
| `text` | what it says, `[page]` inside |
| `speaker`, `speaker_color` | its name, shown beside the box |
| `turns` | `true`: turns toward the player, then back |

- **A character is talked to on the cell it ends on**: mid-step, the cell it
  walks into, not the one it leaves. It ends its step, turns toward the
  player, speaks, then turns back to the direction it had, unless a script
  moved or turned it meanwhile.
- Its controller waits while it talks (`Wildgrass.walkers.set_still()`).
- A game extends `WgTalk` for more: a question, a gift, a battle.

## Cells that react

`WgTrigger` (`Node2D`), on a map: `size` and `level`, like an interactable.

- When a step of the traveller **ends** on it, `_triggered(walker)` runs. The
  player is held at once, before a held key starts another step, and reads no
  input until it returns (feature 4's rule). Signal `triggered`.
- A slide ends there; a ledge's jump triggers only where it lands.
- Not when the traveller arrives by a warp or a reload, turns, is moved by a
  script, or is held already.
- `enabled` switches it off (feature 7 ties it to the story).

## Guarded passages

`WgRoadblock` extends `WgTrigger`, on the free cell beside a guard:

| Field | |
|---|---|
| `guard` | path to the guard, a character on a neighbouring cell |
| `text` | what the guard says; empty: its `WgTalk`'s |

When the player steps on it:

1. the player backs away one cell, keeping its facing, and in the same frame
   the guard steps onto the passage behind it: they move together;
2. the guard faces the player and speaks;
3. the guard goes back to its post, facing as before;
4. the direction that led into the passage is ignored while its key stays
   held, as after a door.

A walker may step into a cell another walker is leaving: that is how the
guard steps in behind the player, and how a follower will (feature 19).

The player always gets control back: if it cannot back away, the guard
speaks from its post; without a guard, or with one freed on the way, the text
is said all the same, and nothing waits for the guard.

## Character sheets

`WgCharacterSprite` (`AnimatedSprite2D`) builds its animations from `sheet`, a
character sheet as Studio and RPG Maker draw them: 4 columns of steps, 4 rows
facing down, left, right, up. `idle_<dir>` is the first column, `walk_<dir>`
the four, at `fps` (8) at the walk pace; the feet sit at `foot_line` (8: the
bottom of a 16-pixel cell). `columns`, `rows_order`, `fps` and `foot_line`
change the layout; it shows in the editor too. A game with its own
`SpriteFrames` uses a plain `AnimatedSprite2D`.

## Config

The `movement` config gains `"still_during_dialogue": true`, `"patience": 2`
and `"path_cells": 400`. A negative patience or a path size not positive is
logged and reset.

## Later

- Conditions on what a character says, whether it is there, a guard's
  passage: feature 7.
- Sight (who a character sees in front of it), trainers walking up to the
  player, emotions above a head: with battles.
- Moves relative to the character, as event routes have them: an importer
  builds them on `walk()`.
- Grass over feet, reflections, footprints: feature 18. Followers: feature 19.

## Tests

Maps, TileSets, characters and sheets are built by the tests; time is
advanced by hand, frames awaited where a search or a scene spans them.
Covered: a pace and running; wandering in an area, on tiles, in a map shown
elsewhere, never into a neighbour, never onto a ledge or ice, its pause and
turns alone; a route in straight lines, in a map shown elsewhere, waiting
without bumping, a point off the map; nobody moving during a screen, a warp
or an interaction, unless the config says so, the traveller always asked;
scripted walks, backing away, running, the controller waiting, dialogue not
stopping them, waiting then giving up, skipping, cut short by another walk,
by freeing or by a warp, paths around walls and over ledges, characters not
blocking a search, no path within `path_cells`, `turn_toward()`, stepping into
a cell being left, config errors; talking, its speaker and colour, not
turning, mid-step on the cell walked into, not on the one left, not turning
back when moved, the controller waiting; triggers holding a held key at
once, not on a turn, a scripted walk, a warp or when off, ending a slide,
after a jump; the guarded passage with both moving in the same frame, the
guard speaking, going back, the way back blocked, no room to back away, no
guard, a guard freed; sheets, their layout and their removal.
