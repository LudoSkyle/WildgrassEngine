# Feature 20 — Debug tools

Status: implemented.

What a game's maker reaches for while building it: jumping through a
quest, filling the bag or the Pokédex, forcing the hour or the weather,
speeding the game up, checking every species' data. A **Debug** entry of
the pause menu opens them, in debug builds only. The engine's tools and the
game's own are kept apart: what the engine gives works in every game, what
a game adds (its quests' steps, its own gifts) belongs to it.

## The tools

`Wildgrass.debug` keeps them, in pages. The first page has two lines:

- **Engine**: the engine's tools (below);
- **Game**: the game's own, the page a game's tools go to by default;
  hidden while the game has none.

```gdscript
Wildgrass.debug.add_tool(&"rod", "Give the rod", _give_rod)              # in Game
Wildgrass.debug.add_tool(&"lap", _lap_label, _next_lap)                  # a label that changes
Wildgrass.debug.add_tool(&"boss", "Skip the boss", _skip, {"shown": _boss_here})
Wildgrass.debug.add_page(&"bell", "Bell quest", {"lines": _bell_lines})  # a page in Game, lines made when it opens
Wildgrass.debug.add_tool(&"sun", "Always sunny", _sun, {"page": &"engine"})   # beside the engine's, if a game must
Wildgrass.debug.remove_tool(&"speed")                                    # an engine tool a game does not want
```

- A tool: an `id`, a `label` (a text, or a callable giving it: "Speed:
  x2"), what it does (a callable, awaited). Options: `page` (`game` by
  default; `engine`, or a page of either), `before` (a tool of that page;
  empty: the end), `shown` (a callable; false hides the line).
- **What it does returns true to keep the page open** (a setting cycled in
  place, its label read again), false to close the tools: what follows
  (a message, a reload) shows over the game, asked with
  `Wildgrass.debug.then(callable)`.
- A page: an `id`, a `label`, the same `page`, `before`, `shown`; its
  `lines`, if given, a callable returning `[{label, action}]` when the page
  opens (a line per quest, per map).
- A page lists its tools, then **Back**; cancel is Back. Back from the
  first page returns to the pause menu; with no game tools, Debug opens
  the engine's page at once. Up and down move round; a page
  taller than the screen scrolls with the cursor.
- The `debug` screen (`WgDebugScreen`) shows a page: a column of lines like
  the pause menu's, in Godot's theme, replaceable as any screen.
- The pause menu's **Debug** entry, before Exit, shows when the `debug`
  config's `enabled` says so: `"auto"` (debug builds, the default), `true`,
  `false`. `Wildgrass.debug.open()` opens the tools from anywhere else (a
  game's key), unless they are open already.

## The engine's tools

On the **Engine** page, in this order, then Back:

| Line | Does |
|---|---|
| Fill the bag | adds every item but those of pockets that `reveal` (key items): 3 of the first, 4 of the next…, up to the bag's `max_count`, to see counts of every width |
| Quests | a page: a line per quest known; each opens Start over · Next objective · Finish |
| Hour: real | cycles the `debug` config's `hours` (dawn 6.5, day 12, dusk 19, night 23), then the real hour again: `daytime.forced_hour`; stays open |
| Weather: Clear | `weather.cycle()`; on a map with a weather of its own, which shows instead, the label says it too ("(this map: Rain)"); stays open |
| Species | the species view (below); hidden without species |
| Fill the Pokédex | in the dex shown, one species in three caught, the next seen, the next left as it was |
| Speed: x1 | cycles the `debug` config's `speeds` (1, 2, 4, 8): `clock.speed`; stays open |

Better than Mirage, after them:

| Line | Does |
|---|---|
| Empty the bag | takes everything out |
| Empty the Pokédex | forgets every species seen |
| Warp | a page: a line per map of the maps folder (not its subfolders); warps to its first spawn point |
| Reload the map | `maps.reload()`: the characters back where they start |
| Through walls: off | the traveller walks through tiles and characters (a `can_step` hook run after every other, priority 1000); doors, triggers and grass still work; stays open |
| Encounters: chance | cycles `encounters.forced`: chance, always, never; stays open |
| Followers: on | `followers.enabled`; stays open |
| Save here | writes the game in its slot, even where saving is off |

**Quests**, the engine's (feature 7: objectives, a Studio project's
among them): the engine knows them, so their page is the engine's. *Next objective*
completes the first objective not done (revealing it if hidden), starting
the quest if it was not; *Finish* completes them all (its earnings stay to
claim); *Start over* forgets the quest: `quests.forget(id)`, new, signal
`forgotten(id)`. Each closes the tools, says what it did ("Bell quest: one
objective more.", "already done"), then reloads the map, as the story's
`[reload]` does, so the map shows what changed.

What a tool forces outside the game's state lasts until changed or the
game quits, and is never saved: the hour, the weather, the speed, walking
through walls, the forced encounters. What it changes in the game's state
(the bag, the Pokédex, quests, flags) is saved with it.

## The species view

Screen `species_view` (`WgSpeciesViewScreen`), from Debug → Species: every
species the engine finds, by national number, to check their data.

- On the left the list, `lines_shown` (12) at a time, a star by a species
  with something missing; the title counts them. A picture is checked by
  its path, not loaded (`WgSpeciesForm.has_picture(kind)`, new), so a
  thousand species list at once.
- On the right its card: icon, front picture, its `character` sheet, its
  number, genus, generation, types, height, weight, and its name and
  description in every language the game offers (`language` config's
  `choosable`), one after the other; what is missing in red: a name or a
  description without words of its own in a language (another language's
  shown in its place counts as missing: `texts.is_given_in()`), a height, a
  weight, the icon, the front picture, the sheet.
- The `character` sheet turns a quarter a second (down, left, up, right),
  from down again on each species, at one scale for all (`sheet_scale`, 2
  screen pixels a picture pixel at the game's 320 × 240: a big Pokémon
  shows bigger), on a checkerboard of picture pixels with the axes of its
  cell: whether it is centred shows.
- Up and down: a species, round; left and right: ten; cancel closes.

`texts.label_in(language, text)`, new: a label in another language than the
one shown, Godot's translations and a Studio project's texts alike.
`texts.is_given_in(language, text)`, new: whether a text has words of its
own in a language: each placeholder that can tell has its own text there
(`add_placeholder(name, callable, given)`; a Studio line, a cell of its
own), and what is written around them is translated to that language, or
the language has no translation at all (the one the game is written in).

## Lists to choose from

The tools list what the engine knows, so `items.ids()` and `quests.ids()`
are new, as `species.ids()`: the registered, the folder's, and a source's
that can list its own (`add_source(source, lister)`; Studio's do).

## Maps by path

`maps.warp()`, the doors and a saved game take a map id, or a scene path
(`res://…`) for a map outside the maps folder: a map kept with a game's
tests, say. `maps.maps_folder()` gives the folder Warp lists.

## Config

`config/debug.json`:

```json
{
	"enabled": "auto",
	"hours": [["dawn", 6.5], ["day", 12], ["dusk", 19], ["night", 23]],
	"speeds": [1, 2, 4, 8]
}
```

A wrong `enabled`, an hour out of 0 to 24 or given twice, a speed not
positive are logged and reset.

## A Studio project

The same tools; Studio's items and quests are listed. Studio's debug
console is its engine's, not its project's: nothing to read.

## Pokémon Mirage, step by step

| In Pokémon Mirage | In the engine |
|---|---|
| a Debug entry always shown, before Quit | the Debug entry; Mirage's `enabled` true |
| a choice box of three pages, the game's tools and the generic ones mixed | the `debug` screen: Engine, Game |
| Fill the bag: every item but key ones, 3, 4, 5…; two key items given with their reveal | Engine → Fill the bag; Game → Mirage's two key items |
| Quests → a quest → Start over · Next step · Finish: steps of flags and items, a message, the map reloaded | Game → Mirage's Quests page (`add_page` with `lines`), its steps unchanged; Engine → Quests for engine quests |
| Hour: real, dawn 6.5, day 12, dusk 19, night 23, real; stays open | Hour, the same hours |
| Weather: the eight in turn; stays open | Weather |
| National Pokédex: the debug view (list, card, names and descriptions in French and English, missing data in red, the sheet turning on a checkerboard at 4 screen pixels a pixel of a 1152 × 648 view) | the species view, every language offered, at 2 screen pixels a pixel of the game's 320 × 240 |
| Fill the Pokédex: one in three caught, one in three seen | Fill the Pokédex |
| Test field: `tests/maps/field.tscn`, its spawn point | dropped: the engine has its own tests; Mirage may keep it in Game, the map by its path |
| Speed: x1, x2, x4, x8 (`Engine.time_scale`) | Speed, `clock.speed` |

## Later

- Editing flags and values, Studio's switches and variables among them.
- Battles to test, healing the party, giving Pokémon: with those features.
- A key to walk through walls held, a key to save anywhere, autosave: with
  the options' keys.

## Tests

Services, maps, species and screens are built by the tests; screens are
driven with Godot's input actions; the speed, the hour and the forced
encounters are put back after each test.
Covered: Engine and Game apart, the first page titled Debug, a tool's lines
kept off it, the tools open once at a time, Game hidden while empty and
Debug opening Engine then; tools added to the game's page, before another,
hidden, replaced, removed, one beside the engine's; a label read again; a
tool staying open or closing and what it asked run after; pages and their
lines, Back and cancel, back to the pause menu or closing it with the menu;
a page taller than the screen scrolling; the entry shown by `enabled` (auto
in a debug build and not, true, false); a wrong config corrected, an hour
given twice kept once; the engine page's lines in order; each engine tool's
effect: the bag filled up to its limit without key items and emptied, the
hour and the weather cycled, a map's own weather said, the Pokédex filled
and emptied, the speed cycled, quests moving on, finishing, already done,
started over or not started, each said then the map reloaded, Warp listing
the maps and warping, Reload and Save here on a map only, walls walked
through by the traveller alone and after a game's hook, doors still
working, encounters and followers cycled, the game saved where saving is
off, nothing forced saved; the species view's missing data found without
loading a picture, its list, stars and count, moving by one and ten round,
its card in every language and in red, a name missing in one language
alone, the icon's first frame, the sheet turning at its scale and from down
again, opened by the tool keeping the tools open; `label_in()` for Godot
and Studio texts, nested and under an override set elsewhere;
`is_given_in()` for Godot and Studio texts; `ids()` of items, of a Studio
project's items and of quests; `forget()` and its signal; maps by path,
warped to, saved and loaded.
