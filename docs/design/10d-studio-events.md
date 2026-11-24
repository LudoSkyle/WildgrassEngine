# Feature 10 quater — Studio events

Status: in progress. Every event and common event is written; the commands
the engine has a class for run (feature 21), the others are kept raw until
it has one.

A Studio map's events are RPG Maker XP events, in `Data/MapXXX.rxdata` (Ruby
Marshal): pages, each with a condition, a graphic, a trigger and a list of
commands. The importer writes each as the engine's event (feature 21), one
to one, nothing left out.

## Reading

- `studio/marshal_reader.gd` reads Ruby's Marshal 4.8 into plain values and
  runs nothing. An object is a Dictionary (`class` and its fields without
  `@`), a self-dumped one (a `Table`) its bytes under `data`, a symbol a
  StringName; the same object met twice is the same Dictionary (a move
  route and its 509 lines).
- `MapXXX.rxdata`: `events` by id, each `name`, `x`, `y`, `pages`; Studio's
  map id is the file's number (`map019` is `Map019.rxdata`).
  `CommonEvents.rxdata`: the common events, by id.

## What the importer writes

| Studio | Engine |
|---|---|
| an event | a `WgEvent` named `Event<id>`, `event_id` its id, on its cell in the map's `Entities`, with a `WgCharacterSprite` named `Sprite`; `invisible_` in its name: `invisible_blocker` |
| a page | a `WgEventPage`, in order |
| switch 12 on, switch 5 on | condition `switch_12, switch_5` |
| variable 3 ≥ 2 | `variable_3 >= 2` |
| self switch A | `local:A` |
| `character_name`, `direction`, `pattern`, `opacity` | `sheet` (the file copied from `graphics/characters` into `res://graphics/characters`), `direction`, `pattern`, `opacity` |
| `trigger`, `through`, `always_on_top`, `direction_fix`, `walk_anime`, `step_anime` | the same |
| its list | its `commands`, one to one, each with its indent |
| a common event | `res://common_events/<id>.tres`: its trigger, its switch (`switch_N`), its commands |

| Command | Engine |
|---|---|
| 0, 404, 412, 604 (ends of blocks) | `WgEventBlockEnd` |
| 106 Wait `n` | `WgEventWait`, `n / 30` s |
| 108, 408 Comment | `WgEventComment` |
| 111 Conditional Branch: switch, variable, self switch, timer, a character facing, money, item (Studio's id read as its dbSymbol), button | `WgEventIf`; an actor, an enemy, a weapon, an armor, a script: `UNSUPPORTED`, false |
| 411 Else, 112 Loop, 413 Repeat, 113 Break, 115 Exit, 116 Erase, 117 Common Event, 118 Label, 119 Jump | `WgEventElse`, `WgEventLoop`, `WgEventRepeat`, `WgEventBreak`, `WgEventExit`, `WgEventErase`, `WgEventCallCommon`, `WgEventLabel`, `WgEventJump` |
| 121 Switches, 123 Self Switch | `WgEventSetSwitches`, `WgEventSetLocalSwitch` |
| 122 Variables: a number, a variable, random, an item's count, a character's x, y, direction, screen place, terrain tag, the map, the party, the money, the steps, the play time, the timer, the saves | `WgEventSetVariables`; an actor's or an enemy's: `UNSUPPORTED`, 0 |
| any other | `WgEventRaw`: its code and parameters, as they are |

## The report

`<maps>/events.txt`, written by each import for the maps imported: the
events and commands written, then what the engine does not run yet, by
count: each raw command by name (a script by the method it calls, its
modules and receiver dropped: `ge(2).animate_from_charset(…)` is
`animate_from_charset`), each condition and operand it cannot read. It is
the list of what to add to the engine.

On the sample project: 482 events on 21 maps, 13 810 commands, 4 995 not
run yet (messages 1 624, move routes 515, and the screen's and sounds'
commands first); 100 common events.

## Checked

- The reader gives the same events, cells, names, pages, triggers and
  commands as Studio's own readable copies of the sample project's 21 maps
  (`MapXXX.rxdata.yml`).
- At the start of a game (no switch, no variable, no self switch), the page
  each of the 482 events shows and whether it blocks its cell agree with
  RPG Maker's rule (456 shown, 265 blocking).

## Tests

Map files are written by the tests (`tests/support/marshal_writer.gd`).
Covered: integers small, large and negative, UTF-8 text, symbols, objects,
hashes, an object met twice, a self-dumped one, data cut short or not
Marshal; an event and its pages (conditions, look, trigger); each command
and its parameters, the raw ones and their count; a script's method; a map's
events written into its scene, its sheets copied, the common events, the
report.
