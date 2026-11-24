# Feature 10 quater — Studio events

Status: in progress. The events are read and sorted, and the report
written; no event is written into a map yet (see *In steps*).

A Studio map's events are RPG Maker XP events, in `Data/MapXXX.rxdata` (Ruby
Marshal): pages, each with conditions, a graphic, a trigger and a list of
commands. The engine has no command interpreter: it says what a map holds
with its own nodes. The importer recognises the events those nodes say,
writes them into the map's scene, and lists every other one, event by event,
to be rewritten by hand on the engine's nodes.

## Reading

- `MapXXX.rxdata` read as data: `studio/marshal_reader.gd` reads Ruby's
  Marshal 4.8 into plain values and runs nothing. An object is a
  Dictionary (`class` and its fields without `@`), a self-dumped one (a
  `Table`) its bytes under `data`, a symbol a StringName; the same object
  met twice is the same Dictionary (a move route and its 509 lines).
- `events` by id, each `name`, `x`, `y`, `pages`; Studio's map id is the
  number of the file (`map019` is `Map019.rxdata`).
- A page: `condition` (`switch1_id`, `switch2_id`, `variable_id` ≥
  `variable_value`, `self_switch_ch`, each with its `_valid`), `graphic`
  (`character_name`, `direction`, `pattern`), `trigger` (0 action, 1 player
  touch, 2 event touch, 3 autorun, 4 parallel), `through`, `move_type`,
  `list` (`code`, `indent`, `parameters`).
- Studio's event name tags: `[sprite=off]`, `[offset_x=]`, `[offset_y=]`,
  `[z=]`, `invisible_`, `$`, `surf_`, `[particle=off]`, `[reflection=on]`,
  `[noslide=on]`.

## When an event starts

| Trigger | Starts |
|---|---|
| action (0) | the action key, facing it |
| player touch (1), event touch (2) | stepped on, or bumped into: a step toward it that fails, whatever stopped it |
| autorun (3), parallel (4) | by itself |

A touched event is **bumped into** when it shows and blocks (a graphic, not
`through`), is `invisible_`, or stands on a cell whose passages block every
side; it is **stepped on** otherwise.

## Which page

Studio shows the last page whose conditions all hold; none: the event is not
there. In the engine:

| Studio | Engine |
|---|---|
| switch 12 on | `switch_12` |
| variable 3 ≥ 2 | `variable_3 >= 2` |
| self switch A on | `local:A` (the event's own node) |
| one page, or the first with no condition | always there |
| every page conditioned, one page | `WgShowIf` with its condition |
| pages that only change what is said | `states`: one per page from the second, in order |
| pages that change anything else (graphic, trigger, place, kind) | listed |

## Known forms

| An event that… | Becomes |
|---|---|
| has a graphic and, on action, only says messages | a character: `WgWalker` with a `WgCharacterSprite` (its sheet copied from `graphics/characters`), facing its page's direction, and a `WgTalk` |
| has no graphic (or `[sprite=off]`) and only says messages | a `WgSign` on its cell |
| on touch (1, 2), one transfer to a map and cell, around it only sounds, fades, tints, waits and moves (and the scripts that only show: animating a sheet, hiding the follower), other pages only its arrival (autorun on a self switch, the same kinds of commands) | a door (next step): stepped on, a contact `WgDoor` on its cell; bumped into, an exit `WgDoor` on each free cell beside it, facing it, and a still character with its graphic on its cell |
| on action, gives an item found (`pick_item`) | a `WgItemBall` (visible with a graphic, else invisible) |
| a graphic only, no command | a character that says nothing, or a still sprite |

- Messages: consecutive `Show Text` (101 and its 401 lines) are one text,
  `[page]` between them. A message `2, 0` (Studio's dialog file 100002, line
  0) is the key `dialogs.2.0`; the game's translations give its words.
- In the words: `:[name=X]:` at the start is the speaker; `[WAIT n]` (frames)
  `[pause=n/60]`; `\v[n]` `{variable_n}`; `[VAR …]` as the Studio layer reads
  it. A token not read: the line is listed.
- Comments (108, 408) are skipped.

A transfer on the action key or to a place held in variables, a branch, a
choice, a script of another kind: the event is left by hand. What a door
changes besides (variables, switches, self switches, a common event called)
and its arrival page are noted: the door says none of it.

A script is known by the method it calls, its modules and receiver dropped
(`ge(2).animate_from_charset(…)` is `animate_from_charset`).

## The report

`<maps>/events.txt`, written by each import for the maps imported: the
counts by form, then each event per map, its id, cell and name, and what it
becomes (a door's way in and where it leads, what it leaves out) or why it is
left by hand (its first command or script of no form, its pages, its
trigger). It is the list of what to rewrite by hand, and shrinks as the
importer learns forms.

On the sample project: 482 events on 21 maps, 31 doors, 33 characters, 23
signs, 10 items found, 25 still sprites, 13 with nothing to write, 347 by
hand. Every door leaves something out: its arrival page, a return point in
variables, the elevator's floor.

## Texts

The importer writes the words of the keys it uses into a translation file,
`<maps>/dialogs.csv` (`keys` and one column per language of Studio's
`Dialogs` files), which the game lists in its localization settings.

## In steps

1. Reading the events and the report (done).
1. Doors and their arrival points: what a door leaves out, to decide.
2. Characters and signs, their words and the translation file.
3. Items found.
4. Page conditions: who is there and what is said.

Each step checked on the sample project: what is written against Studio's
own data, the report's count going down.

## Tests

Map files are written by the tests (`tests/support/marshal_writer.gd`).
Covered: integers small, large and negative, UTF-8 text, symbols, objects,
hashes, an object met twice, a self-dumped one, data cut short or not
Marshal; each form, a door stepped on or bumped into (graphic, `invisible_`,
a blocked cell), what a door changes besides and its arrival page noted,
what a door cannot say, every other reason to leave an event by hand; a
script's method; the report. The reader is checked on the sample project
against Studio's own readable copies of its maps (`MapXXX.rxdata.yml`):
the same events, cells, names, pages, triggers and commands.
