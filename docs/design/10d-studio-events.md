# Feature 10 quater — Studio events

Status: in progress. Every event and common event is written; the commands
the engine has a class for run (feature 21), messages and choices with their
words in each language, the others are kept raw until it has one.

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
| 101 Show Text and its 401 lines | `WgEventSay`: its words (see *Messages*) |
| 102 Show Choices, 402 When, 403 When Cancel | `WgEventChoices` (each choice's words, its cancel), `WgEventWhen`, `WgEventWhenCancel` |
| 103 Input Number, 104 Text Options | `WgEventInputNumber`, `WgEventTextOptions` |
| 122 Variables: a number, a variable, random, an item's count, a character's x, y, direction, screen place, terrain tag, the map, the party, the money, the steps, the play time, the timer, the saves | `WgEventSetVariables`; an actor's or an enemy's: `UNSUPPORTED`, 0 |
| any other | `WgEventRaw`: its code and parameters, as they are |

## Messages

A message `3, 30 …` (Studio's dialog file `Data/Text/Dialogs/3.csv`, line
30) or a choice `\t[11, 27]` (file `100011.csv`, line 27) is the key
`dialogs.3.30`, `dialogs.100011.27`; words written in the event itself are
converted and kept in it. Each key's words, in each language of Studio's
files that Godot knows (an untranslated cell: the fallback language's, else
the first), are written into `<maps>/dialogs.csv`, a translation file the
game lists in *Project Settings → Localization* (the importer says so); its
import takes the words as written (`unescape_translations` off), as Studio's
own words may hold a backslash.

Studio's codes, in the order Studio reads them:

| Studio | Engine |
|---|---|
| `\\` | a backslash |
| `\v[n]` | `{value:variable_n}` |
| `\N[1]`, `\n[1]` | `{player}`; another actor `{actor_n}`, counted |
| `\p[n]` | `{party_n}`, counted |
| `\k[a]` | `{key:ui_accept}` (Studio's key names as Godot's actions) |
| `\E`, `\f[girl§boy]` | `{flag:switch_1?e|}`, `{flag:switch_1?girl|boy}` (switch 1: the player is a girl) |
| `\t[f, l]` | that line's words, in the same language, their codes read after |
| `...`, ` $` | `…`, a space that does not break |
| a text variable a script sets (`[POKE]`) | `{poke}` |
| `[VAR NAME(000n)]` | `{name_n}`, as the Studio layer reads it |
| `:[name=Ann,2]:`, `align`, `lookto` | `[speaker=Ann][speaker_color=#…]`, `[align=…]`, `[look_to=…]` |
| `\c[n]` | `[color=#…]` (the fill row of `graphics/windowskins/_colors.png`), `\c[0]` back to the default |
| `[WAIT n]` | `[pause=n/60]` |
| `\s[b]`, `\s[i]`, `\s[r]` | `[b]`, `[i]`, back to plain |
| `\G` (money window), `face`, `city`, `\^` (big text), `\spd`, `\img`, `\d` | not shown yet: counted in the report, taken out |
| any other `[` | written as text (`[lb]`) |

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

- Every message and choice of the sample project (1 839 keys), in English
  and French, shown through the engine's dialogue headless: the text on
  every page and the speaker agree with Studio's own steps, ported apart;
  no unknown tag. The Hub's welcome plays to its end, the question answered
  either way.

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
