# Feature 9 — Saving

Status: implemented.

A game kept in a slot: what each service holds, written as JSON, read back
where the player left it; a new game; the save screen and the choice of a
game. Options are not part of a game: feature 10. The title screen that opens
the choice is feature 11.

## Slots

```gdscript
Wildgrass.save.slot                   # the slot of the game played; 0: none yet
Wildgrass.save.has(2)                 # true if slot 2 holds a game
Wildgrass.save.slots()                # the slots to show
Wildgrass.save.summary(2)             # what its card shows, or {}
Wildgrass.save.write()                # in `slot`; false if refused
await Wildgrass.save.load_game(2)     # plays slot 2 where it was left
Wildgrass.save.new_game(2)            # empties every part; slot 2 is the game's
Wildgrass.save.erase(2)
Wildgrass.save.reset()                # empties every part, no game played
```

- A slot is a number from 1. The `save` config (`config/save.json`) sets
  how many: `slots` (0: as many as the player wants, `slots()` going one past
  the last used; 1: a single game), `file` (`saves/game`: the file of slot 2
  is `saves/game-2.json`, a single game's `saves/game.json`, in the `saves`
  folder of paths, `user://`; `test_saves/…` when launched for testing),
  `save_anywhere` (true: the save screen may write in another slot than the
  game's; false by default). A Studio project's `save_config.json` gives
  them through the Studio layer (feature 10 bis).
- `new_game(slot)` resets every part and makes `slot` the game's, writing
  nothing: until written, the slot keeps what it held. `slot` 0 there takes
  the first empty one. Hook `new_game(slot)`, signal `new_game_started(slot)`:
  the game warps to its first map there.
- `write()` with no slot chosen takes the first empty one; past
  `slots` it is refused, logged. Signal `written(slot)`.
- `erase(slot)` removes the file; the game played keeps its slot. Signal
  `erased(slot)`.
- `reset()` empties every part and forgets the game played (`slot` 0),
  telling no one: back to the title (feature 11).

## What a game holds

A game is the state of its **parts**, each a name and its callables:

```gdscript
Wildgrass.save.add_part(&"pokedex", _state, _restore, _reset, _check)
```

- `state()` returns a dictionary JSON holds (numbers, texts, booleans,
  arrays, dictionaries with text keys): anything else refuses the write,
  logged with where it stands. `restore(state)` puts it back, and may be a
  coroutine; `reset()` is a new game; `check(state)`, optional, may refuse a
  load before anything is restored. Callables are methods, never lambdas
  holding their object. A name taken twice is refused, logged.
- The engine's own parts: `story` and `quests` (feature 7), `bag` (feature 8),
  `clock` (the play time, `Wildgrass.clock.seconds`), `daytime` (the game's
  own hour, feature 16), `pokedex` (feature 13) and `map`, last.
- A part a game file holds and no one added is kept as read and written back
  as it was: a plugin removed then put back loses nothing; a new game drops
  it. A part added that a file lacks (a game saved before it existed) is
  reset.
- Restoring follows the order parts were added, each awaited: the map is
  built once flags, the bag and quests are back, so what shows on it is right
  from its first frame.

## The map part

`Wildgrass.walkers` keeps it: the current map's id; the cell, level and
facing of `Wildgrass.maps.traveller`; and those of every walker on that map,
by its path in it (a guard a scene moved aside stays aside). Cells are the
map's own, from its corner, whichever map the player crossed into.

- Loading warps with no transition to that cell (`Wildgrass.maps.go_to_cell`)
  and puts each walker back with `walker.place_at(cell, level, facing)`; a
  walker no longer on the map is skipped. Other maps start again from their
  scenes, as after any warp.
- A map that no longer exists refuses the load before anything is restored,
  logged, unless the filter hook `save_lost_map(map_id, lost_id, state)`
  names one that does: the traveller then starts at its first spawn point.
- A game saved with no map or traveller restores none.

## The file

`user://saves/game-1.json`:

```json
{
	"format": 1,
	"game_version": "1.0.2",
	"saved_at": "2026-11-21T10:12:00",
	"summary": { "seconds": 3754.2, "map": "town", "zone": "harbour" },
	"parts": { "story": {…}, "quests": {…}, "bag": {…}, "clock": {…}, "map": {…} }
}
```

- `format` is the engine's layout of the file; `game_version` the project's
  `application/config/version`. **A game from an older version** goes through
  the filter hook `save_upgrade(parts, game_version)` before its parts are
  restored: a game renames a flag there. A file of a `format` newer than the
  engine's is refused, logged.
- **Writing never leaves half a file**: it writes `….json.tmp`, then renames
  it over the old one; a failure at either step leaves the old game as it
  was, logged, and `write()` returns false. A file that cannot be read
  (broken JSON, not a game) is refused, logged, and left as it is: its card
  shows it damaged (`{"damaged": true}`), not empty.
- Nothing in it depends on the project's layout: a map by its id, a place in
  cells.
- The `summary` is what a card shows without reading the parts, built by the
  filter hook `save_summary(summary, slot)`: the engine adds the play time,
  the map and its zone; a game adds the player's name, badges, its party.
  `Wildgrass.save.summary_now()` is the game played's.

## Loading

`load_game(slot)`:

1. reads the file, upgrades it (`save_upgrade`), refuses it if broken or
   newer, or if a part's `check` refuses it: nothing is restored then;
2. restores the parts in order, the map last;
3. hook `game_loaded(slot)`; signal `loaded(slot)`.

## The save screen

A replaceable screen, `save` (`WgSaveScreen`), the engine's in Godot's theme:
a summary of the game in a corner (its zone, else its map, and the play time
as `h:mm`), then in the message box:

1. when `save_anywhere`: "Save in which file?", a choice per slot (the
   game's selected; a new one offered) and Cancel;
2. "Would you like to save the game?" (Yes / No);
3. if the file holds a game: "There is already a saved file. Is it OK to
   overwrite it?";
4. "The game was saved.", `locked` for `saved_seconds` (1), then the screen
   closes; a game that cannot be written says "The game could not be
   saved.".

No, or cancel, closes it writing nothing. Signal `done(saved)`. Its texts are
the scene's. `Wildgrass.screens.open(&"save")`; the pause menu opens it
(feature 10).

## The choice of a game

A replaceable screen, `save_slots` (`WgSaveSlotsScreen`): a card per slot of
`slots()`, the game played's selected; up and down move, stopping at the
ends. A card's text is a template, `{slot}`, `{place}`, `{time}` and what the
game added to the summary (`{name}`); a free slot and a damaged file have
their own.

- On a game, in the message box: Continue (loads it, then closes; a game that
  cannot be loaded says so), Erase (asked with No selected; the card
  empties), Cancel.
- On a free slot: New game (`new_game()`, then closes). On a damaged file:
  Erase.
- Keys wait while a game loads; cancel closes it. Signal
  `chosen(slot, action)`: `continue`, `new_game`, `erase`, or `cancel` with
  slot 0.
- A game's scene changes how it looks, not what it does (feature 11): its
  layout settings, its cards, its questions.

The title opens it (feature 11), giving `new_game` and `continue` callables
in place of the save service's, and `open_options`; else
`Wildgrass.screens.open(&"save_slots")`.

## Later

- Options (message speed, volume, language): their own file, feature 10.
- Pokémon, the party, the Pokédex as parts: features 12 and after.
- Reading Studio's binary saves, encrypting them: not planned.
- Autosave, saving anywhere from a debug key: the debug tools (feature 20).

## Tests

Parts, configs, maps, files and screens are built by the tests, in a saves
folder of their own; time is advanced by hand and input simulated with Godot's
input actions.
Covered: a game written and read back whole, the file's layout, the slots
with no maximum, with one, a single game's file, writing past the maximum,
the game's slot else the first empty one, a new game and its hook, parts kept
and reset, the restore order and a coroutine awaited, a check refusing a
load, upgrades, newer and broken files, damaged cards, summaries and what a
game adds, what JSON cannot hold and a summary that cannot be written, a file
that cannot be replaced, erasing, test files apart, a bad config; the play time kept; the map part with the traveller's
level and facing, walkers put back and one gone, cells of a map not at the
origin, walkers of other maps left out, a lost map refused or replaced, no
map, a traveller that is no walker; the save screen's summary, saving, the
saved text held, overwriting on Yes only, No and cancel, a write that fails,
picking a file and the game's selected, the engine's services; the choice's
cards and templates, moving, continuing, a new game, erasing with No first, a
damaged file, a failed load, keys waiting for a load, the engine's services;
reset emptying every part and what no one added.
