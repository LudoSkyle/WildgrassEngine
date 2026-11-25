# Feature 21 — Events

Status: in progress. Done: events, pages and their conditions, how events
start, the lists and their flow and story commands, common events, messages,
choices and numbers, moving by oneself and routes imposed, transfers,
events placed, local switches of other events. Next: the screen and sound
commands (step 2), then script calls (see *In steps*).

What a map does as the player goes: characters that talk, doors that open,
scenes that play. An event stands on a cell with pages; the page shown is the
last whose condition holds, and it says how the event looks, what starts it
and the list of commands it runs. The engine runs those lists itself. It is
the model Studio's projects use (RPG Maker's), so the Studio importer writes
each event as it is, nothing left out; a Godot game writes its events in the
inspector the same way. The engine's simpler nodes (`WgTalk`, `WgSign`,
`WgDoor`, `WgItemBall`…) stay: a game uses either.

## An event

`WgEvent` (`WgWalker`), in a map's `Entities`, with a `WgCharacterSprite`
named `Sprite`:

| Field | |
|---|---|
| `pages` | `WgEventPage` resources, in order |
| `event_id` | its number on the map: what commands and conditions name |
| `invisible_blocker` | blocks and is bumped into with nothing to show |

`WgEventPage` (`Resource`):

| Field | |
|---|---|
| `condition` | a story condition (feature 7): `switch_12`, `variable_3 >= 2`, `local:A` |
| `sheet`, `direction`, `pattern` | how it looks: a character sheet, the direction it faces, the column it shows at rest; no sheet: nothing shows |
| `trigger` | `ACTION`, `TOUCH` (the player steps onto it, or into it), `EVENT_TOUCH` (as `TOUCH`; it walks into the player too), `AUTORUN`, `PARALLEL` |
| `through`, `always_on_top`, `fixed_direction`, `walk_animation`, `step_animation` | as RPG Maker's |
| `opacity` | from 0 to 1 |
| `move_type`, `move_route` | how it moves by itself: `FIXED`, `RANDOM`, `APPROACH` (toward the player), `ROUTE` (its `WgMoveRoute`) |
| `move_speed`, `move_frequency` | RPG Maker's 1 to 6: its pace, and how long it stands between moves |
| `commands` | the list it runs |

- The page is chosen again at the next frame after the story changes
  (feature 7's `changed`, once for all changes): a door's arrival page shows
  the moment its local switch is set. The same page chosen again changes
  nothing. No page: the event is not there (it neither blocks nor starts),
  but stays in the tree.
- A new page turns the event only when its direction differs from the page
  before's.
- It blocks its cell when it shows a sheet and is not `through`
  (`invisible_blocker`: even with none).
- **Starting.** The action key starts the event the player faces with an
  `ACTION` page, across a counter too, unless it can be stepped on; then
  one under the player. `TOUCH` and `EVENT_TOUCH` start it when the
  player's step ends on it, if it can be stepped on (no sheet, or `through`,
  on a cell not solid); else when a step of the player toward it fails,
  whatever stopped it. `AUTORUN` starts by itself, again each time its list
  ends, as long as the page shows; an `EVENT_TOUCH` under the player too.
- An event the player started faces the player while its list runs, then
  turns back, unless `fixed_direction`.
- Local switches `A` to `D` are its local flags (`local:A`), kept by the
  save. They are named by its number on its map (`map019/event_7:A`), so
  that a list elsewhere can set them; an event numbered 0 by its path in
  the map. Two events with one number share them.

## Moving

Moves keep RPG Maker's time: 60 ticks a second, counted from the frame's
time, whatever the frame rate.

- **Speed** `s` is `60 × 2^s / 128` cells a second (3: 3.75; 4: 7.5).
  **Frequency** `f` is how many ticks it stands between two moves by
  itself: `(40 − 2f) × (6 − f)` (3: 102; 6: none).
- A `WgMoveRoute` is a list of `WgMoveStep`, numbered as RPG Maker's 45:
  steps the four ways and the diagonals, at random, toward or away from the
  player, forward, backward; jumps; waits; turns; switches; speed,
  frequency, animations, fixed direction, through, on top, graphic,
  opacity, a sound effect. A step, a turn, a jump and a wait take their tick;
  the others run at once with the next. Its end starts it again if
  `repeat`. A step blocked is tried again until it passes, unless the route
  is `skippable`. A jump of `d` cells lasts `(10 + d − speed) × 2` ticks.
  Blending and calls are logged.
- **By itself**, as its page says, between its frequency's stops (a step,
  a jump or a turn starts its stop again); not while
  it is starting or its list holds it, nor during a warp or a screen other
  than a message.
- **A route imposed** (`WgEventMoveRoute`) replaces the moves of its
  character, the player too, until its end; then it moves as its page says.
  A new page of the event ends the route imposed on it.
  `WgEventWaitForMoves` waits until no route imposed is under way.
  `Wildgrass.events.force_route(walker, route)` does the same from code.
- An `EVENT_TOUCH` event whose step into the player fails starts.

## Transfers

- **`WgEventTransfer`** takes the player to `cell` of `map` (empty: the
  map shown), counted from the map's origin; or, `by_variables`, to the map
  numbered by variable `map_variable` (the `map` config's `numbers` say
  which map a number is) and the cell of variables `x_variable` and
  `y_variable`. It then faces `direction`, or keeps its facing (zero, or
  `fixed_direction`). `transition`: `dissolve`, RPG Maker's fade (the last
  picture dissolves into the new map in 20 ticks), or `none`.
- It waits while a message is under way or a warp runs, then the list waits
  until the player has arrived; `Wildgrass.maps.transfer()` does the same
  from code. The map shown is not built again: its events keep their
  places and pages. A map or number unknown is logged once and the list
  goes on.
- **On another map the list goes on**, its event forgotten: a character it
  names by number is an event of the map shown, 0 none. A local switch it
  names by number is still one of the map it started on.
- Arriving starts nothing: a `TOUCH` page under the player waits for a
  step; an `EVENT_TOUCH` one starts once the transfer is over, as it does
  when it comes under the player.
- **`WgEventSetEventLocation`** puts a character at once on `cell` of its
  map (from the map's origin), or on the cell of variables `x_variable` and
  `y_variable`, or on another character's cell, that one taking its place;
  then faces `direction` (zero: as it was).
- **`WgEventSetLocalSwitch`** sets a local switch of the event running the
  list, or of event `event` of `map` (empty: the map the list started on).

## Commands

A list of `WgEventCommand` resources, each with its `indent`, as RPG Maker
holds them; a block (a branch, a loop's body) is the commands after its
start at a greater indent, and the markers that end blocks stay in the list.

`Wildgrass.events` runs them:

- **One list at a time holds the player**: the first event starting on the
  map shown, by number, else a common event running by itself. The
  player reads no input until it ends.
- **Parallel lists** run beside it: each `PARALLEL` page of the map shown,
  each `PARALLEL` common event whose switch is on, again each time they end.
  A page that changes drops its parallel list; a list holding the player
  goes on to its end whatever its event's page becomes.
- The service owns the lists and advances them each frame: a list goes on
  after a warp frees its map (its event forgotten, as for a common event).
- At most 100 commands run in a frame: a loop that never waits gives the
  frame back.
- A command whose feature the engine does not have yet logs it once and
  goes on.

The set is RPG Maker's whole:

| Group | Commands |
|---|---|
| Flow | conditional branch (switch, variable, local switch, timer, money, item, character facing, script condition), else, loop, break, label, jump to label, exit, erase event, call common event, wait |
| Messages | show text, choices, input number, text options |
| Story | switches, variables (and their operations, random, character positions…), local switches, timer, money, items |
| Moving | transfer player, set event location, scroll the map, move route (every move command), wait for moves, change map settings |
| Screen | tone, flash, shake, weather, transitions, pictures (show, move, rotate, tone, erase), animations |
| Sound | BGM, BGS (play, fade, memorize, restore), ME, SE, stop SE |
| Game | battle, shop, name input, party and actor changes, menu, save, game over, back to title |

Each command is a resource a game edits in the inspector; the engine runs
each with its own services. Done:

| Command | Does |
|---|---|
| `WgEventIf` | a condition: a switch on or off, a variable against a number or a variable, a local switch, the money, an item in the bag, a character facing a way, a key held, a story condition; `WgEventElse` its other branch |
| `WgEventLoop`, `WgEventRepeat`, `WgEventBreak` | a loop and its end; a break leaves the loop it is in |
| `WgEventLabel`, `WgEventJump` | a jump to the first label of that name |
| `WgEventExit`, `WgEventErase` | end the list; remove the event until its map is built again |
| `WgEventWait` | seconds (RPG Maker's `n` is `n / 30` s) |
| `WgEventCallCommon` | a common event's list, then on |
| `WgEventSetSwitches`, `WgEventSetLocalSwitch` | switches `first` to `last` on or off; a local switch of the event, or of event `event` of `map` |
| `WgEventSetVariables` | set, add, subtract, multiply, divide, modulo, by a number, a variable, a random number, an item's count, a character's place or facing or terrain tag, the map, the money, the play time; floored and within ±99 999 999 as RPG Maker's |
| `WgEventSay` | a message (a text, or a key the game's translations give); the list waits until it is read. Followed at once by `WgEventChoices` or `WgEventInputNumber`, it is their question |
| `WgEventChoices`, `WgEventWhen`, `WgEventWhenCancel` | a choice and the block of each answer; `cancel` as RPG Maker's: 0 nothing, `n` the answer `n - 1` (a choice, or 4: the cancel's own block) |
| `WgEventInputNumber` | a number of `digits` digits from 0 into a variable; cancel does nothing |
| `WgEventTextOptions` | where the next messages show, with or without their frame (style `transparent`) |
| `WgEventMoveRoute` | a `route` imposed on a `character`; the list goes on |
| `WgEventWaitForMoves` | waits until every route imposed has ended |
| `WgEventTransfer` | the player to a cell of a map, or of the map and cell three variables hold (see *Transfers*) |
| `WgEventSetEventLocation` | a character on a cell, the cell of two variables, or another character's |
| `WgEventComment`, `WgEventBlockEnd` | nothing |
| `WgEventRaw` | a command with no class yet: its code and parameters, logged once |

Characters are named as RPG Maker does: -1 the player, 0 the event running
the list, a number an event of its map.

**Messages.** One at a time: while another list's message or question is
under way, a list's own waits its turn (it is not queued, so a list dropped
meanwhile shows nothing). `[look_to=3]` in a message turns the player toward
event 3 of the list's map (0: nothing).

## Common events

`WgCommonEvent` resources, `res://common_events/<number>.tres` (paths
`common_events`): a list called by number, or run by itself (`AUTORUN`,
`PARALLEL`) while its `switch` (a flag) is on. Calls nest up to 100 deep; a
missing one is logged once.

## Script calls

Studio's events call Ruby methods (`give_item`, `animate_from_charset`, a
follower hidden…). The engine has a command per behaviour, `WgCall`: a
name and its arguments, run by a handler the engine registers
(`Wildgrass.events.add_call(name, callable)`); a game adds its own. The
importer turns a script line that is a call into it; a line that is more
(a loop, a block, an assignment) is reported, its behaviour to be given a
command of its own. The import report lists every call the engine does not
handle yet, with its count: it is the list of what to add.

## The Studio importer

Each event of a map, written as a `WgEvent` in its scene: every page, its
condition, look, trigger, moves and commands, translated one to one; common
events into resources (feature 10 quater, done for what the engine runs; the
rest kept raw). Messages become text keys (feature 5), the words of
Studio's dialog files written into the game's translations. Switches and
variables are named `switch_N`, `variable_N` (feature 7).

## In steps

1. Events, pages, conditions, triggers; flow, story, message and moving
   commands; move routes; common events. The importer writes events and
   their texts. On the sample: talking characters, signs, doors (with their
   animation, arrival and return points), scenes made of messages and moves.
2. Screen and sound commands, pictures.
3. Script calls, by count in the report: the sheet animations, followers,
   items given and found first; each feature's calls with the feature
   (battles, shops, the PC…).

Each step is checked on the sample project against Studio's own data and,
headless, by playing its events.

## Tests

Maps, events and common events are built by the tests. Covered: the last
page that holds, chosen again as the story changes, no page; blocking; the
action key, across the event or under the player; touch stepped on and
bumped into; the event facing the player then turning back, the player held;
autorun again until its page changes; parallel lists beside, again, and
dropped with their page; a list going on after its page changes and after a
warp frees its map; branches and else, variables compared to variables;
loops, nested, a break leaving only its own, labels; a loop never waiting
giving the frame back; each variable operation, floored, bounded; local
switches, erasing; common events called, missing, running by themselves; a
command with no class. Moving: a route imposed, then let go; a list waiting
for it; a blocked step tried again or skipped; RPG Maker's ticks at 60 and
120 frames a second; a page route repeated or run once; moving by itself at
its frequency, still while its list runs, from a map just built; a page
route that only turns, standing its frequency between turns; the movers
of walkers freed dropped; speed, switches, through, fixed direction, on top,
opacity and graphic changed by a route; a jump's ticks; a route imposed on
the player while a list holds it; a new page ending a route; an
`EVENT_TOUCH` event walking into the player. Transfers: on the map shown
(its events kept, the player held again), to another map (the list going
on, its event forgotten, a local switch named by number still the starting
map's), by variables through the map numbers, to no map; waiting for a
warp; RPG Maker's 20 ticks of dissolve, and none without a renderer;
arriving starting no `TOUCH` page but an `EVENT_TOUCH` one; events placed by
cell, by variables, swapped, turned; local switches of another event and
of another map, shown there.
