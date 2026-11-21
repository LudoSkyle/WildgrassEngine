# Feature 10 — Pause menu and options

Status: implemented.

The menu the player opens on the map, the entries a game or a plugin adds to
it, and the options: what can be set, kept on the player's machine apart from
any saved game, and the screen that sets them. The title screen also opens
the options (feature 11).

## English labels

The engine's labels are plain English, shown through
`Wildgrass.texts.label()` (feature 5): Godot's translations, then
placeholders. A game translates them as any Godot text; a Studio project
shows Studio's words, through translations the Studio layer builds (feature
10 bis).

```gdscript
Wildgrass.texts.label("Bag")   # "Sac" in French, when translated
```

## The pause menu

The player's input reads one more action, `menu` (`ui_cancel` by default, in
the `movement` config). Pressed while the player stands still, with no
screen open, no interaction under way, no map changing, and the menu
enabled, it opens the `menu` screen.

```gdscript
Wildgrass.menu.enabled = false                 # a scene keeps it shut
Wildgrass.menu.add_entry(&"pokedex", "Pokédex", _open_dex, "has_dex", &"bag")
Wildgrass.menu.open()                          # as the key does
await Wildgrass.menu.show_screen(&"pokedex")   # an entry's screen, the menu hidden beneath
```

- `add_entry(id, text, callable, condition = "", before = &"exit")`: an
  entry, its text a label, placed before another (before Exit by default; at the end if that
  one is not there). `condition` is a story condition (feature 7), checked
  each time the menu shows: an entry whose condition fails is not shown. The
  callable is awaited; it returns true to close the menu, false or nothing to
  stay in it. An id taken again replaces the entry where it stands.
- `remove_entry(id)`, `entries()` (the ids, in order), `shown()` (those whose
  condition holds).
- `show_screen(name, args)` opens a screen with the services, hides the menu
  until it closes, and waits for it.
- The engine's entries, in order:

  | Id | Text | Condition | Does |
  |---|---|---|---|
  | `bag` | Bag | | opens `bag`, stays |
  | `options` | Options | | opens `options`, stays |
  | `save` | Save | `!save_disabled` | opens `save`; closes once saved |
  | `exit` | Exit | | closes |

  Pokémon, Pokédex and the trainer card add theirs with their features.
- `Wildgrass.menu.enabled` (true): false keeps the key from opening it; not
  saved, a scene sets it back. The story flag `save_disabled` hides Save, and
  is saved with the game.

## The menu screen

A replaceable screen, `menu` (`WgMenuScreen`), the engine's in Godot's theme:
a column of entries against the top right corner.

- Up and down move round; confirm runs the entry; cancel closes it. The
  cursor is kept from one opening to the next while the game runs, back on
  the first entry if its entry is no longer shown.
- An entry's screen opens above the menu, which hides and waits for its
  callable; keys go to the top screen only, and wait while an entry runs.
  The entries are shown again after it, their conditions checked anew.
- Its labels follow the language.
- The world stands still while it is open, as with any screen (feature 3).

## Options

```gdscript
Wildgrass.options.value(&"message_speed")       # 2
Wildgrass.options.set_value(&"volume", 80)      # applied and kept at once
Wildgrass.options.add_option(&"auto_run", {"values": [false, true], "default": false, "apply": _set_auto_run})
```

An option is an id and a dictionary: `values` (an array, or a callable
giving one), `default` (among them), `apply` (a callable given the value),
and for the screen `name`, `description`, `texts` (one per value),
`slider` (true: left and right stop at the ends) and `format` (`"%d%%"`).

- **Kept on the player's machine**, in `options.json`
  (`Wildgrass.paths.user_file()`: `test_options.json` when testing), not in a
  saved game: one set of options for every game. Read at start, before the
  engine's options are added; an option added later takes its kept value
  too. Written whenever a value changes, with the values of options not
  added kept as they were. A kept value no longer among an option's values is
  logged and takes the default; a broken file is logged and the defaults
  used.
- `set_value()` refuses, logged, an unknown option or a value not among its
  values. Signal `changed(id, value)`.
- An option without values, or whose default is not among them, is refused,
  logged. One whose values are empty for now (no frames listed) keeps its
  default quietly.
- The `options` config (`config/options.json`) gives the `order` of the
  options shown (`shown()`); an id no option has is skipped, so a Studio
  project's list (its `game_options_config.json`, through the Studio layer)
  works before battles exist. By default: `message_speed`,
  `message_frame`, `volume`, `language`. An option with fewer than two values
  is not shown.
- `text_of(id)`: the value's text, else its format, else the value.
- `was_kept(id)`: the player's machine holds a value for it, read or
  written; the title asks the language at first launch only when none was
  kept (feature 11).
- The engine's options, with Studio's ids; names, descriptions and value
  texts are labels:

  | Id | Values | Applies to |
  |---|---|---|
  | `message_speed` | 1, 2, 3 (slow, normal, fast; 2) | `Wildgrass.dialogue.letters_per_second`: the config's × 0.5, 1, 2 |
  | `message_frame` | the `frames` of the `dialogue` config (`{"style", "name"}`; none by default) | `Wildgrass.dialogue.style` |
  | `volume` | 0 to 100 by 5, a slider (100) | the volume of the `Master` audio bus, muted at 0 |
  | `language` | the choosable languages (feature 5), by their names | `Wildgrass.texts.language` |

  Studio's `screen_scale` has no engine option: the window is resized by
  hand, the game keeping its proportions with bars (the `display` config,
  feature 0). `battle_animation`, `battle_style` and `auto_run` come with
  battles and running.

## The options screen

A replaceable screen, `options` (`WgOptionsScreen`), the engine's in Godot's
theme: a row per option shown, its name and its value, and the description
of the option under the cursor below.

- Up and down move, stopping at the ends; left and right change the value,
  wrapping round, a slider stopping at its ends. Each change applies and is
  kept at once; there is no undo. Cancel closes it.
- Confirm on `message_frame` says a sample message in that frame
  (`frame_sample_text`).
- A language changed, by the screen or otherwise, the rows are written again
  in it.
- `Wildgrass.screens.open(&"options")`; the menu and the title open it.

The screens that cover the whole screen (the bag, the choice of a game, the
options) have an opaque background: Godot's default panel shows what lies
beneath.

## Later

- `battle_animation`, `battle_style`: with battles; `auto_run`: with an
  option for running.
- Music, cries and effects volumes apart: with sound (feature 15).
- The trainer card entry, Pokémon and Pokédex entries: with their features.
- Keys held to scroll a list: with the screens that need it.
- Back to the title from the menu: a game adds the entry (feature 11).

## Tests

Entries, options, configs, texts and screens are built by the tests, which
keep their options in a file of their own; input is simulated with Godot's
input actions.
Covered: entries placed and replaced, removed, their conditions, the key opening the
menu, a menu shut, opening over a screen, moving round, the cursor kept and
falling back, entries awaited with keys waiting, closing or staying and shown
again, the bag and the options opening above with the menu hidden, saving
closing the menu once saved only, labels following the language, the
engine's services; options applied and kept, coming back on the next launch,
wrong options and values, kept values no longer allowed, an option with no
values kept quiet, unknown ones kept,
a broken file, the order and what is skipped, value texts, formats, the
engine's options on the dialogue, the sound and the language, frames
without a style; the options screen's rows, descriptions, moving, values
round and sliders stopping, the value column, the language changed, the
frame sample, the menu opening it, opaque backgrounds, the engine's services.
