# Feature 22 — Event scripts

Status: in progress. Done: step 1 (scripts, script conditions, route
steps' scripts, the engine's first words, the setting), step 2 (Studio's
first words, the importer's translation, the project's translations).
Next: each feature adds its words (step 3).

Events say most things with commands (feature 21). What commands cannot say,
a script says: a few lines of GDScript an event runs, or a condition it
tests. This feature gives events their scripts, in two layers:

- **The engine's words**, for any game: a game written by hand in Godot
  writes its scripts with them, and needs nothing else.
- **A tool's words**, a module on top, optional: Studio's first (its
  scripts' names, as a Studio script would call them), another tool's
  later. An importer writes a tool's scripts in its words; a developer who
  ports a script by hand writes the same.

Studio's data stay read as they are (feature 10): scripts are the one place
where a tool's language becomes GDScript. If Studio one day writes its
scripts in GDScript with the same words, they run as they are.

## A script

| Where | What |
|---|---|
| `WgEventScript` (a command) | `source`: GDScript statements; the list waits until they end (`await` allowed: a message, a choice, a walk) |
| `WgEventIf`, kind `SCRIPT` | `source`: a GDScript expression, true or false |
| `WgMoveStep`, kind `CALL` | `call`: GDScript statements, run as the step |

A game writes them in the inspector or in a scene file; an importer writes
them for its tool.

**How it runs.** At first use, a script is wrapped and compiled once (kept
for the next runs), as a class extending the project's script context:

```gdscript
extends WgScriptContext          # or the project's context, see below

func run() -> void:
	give_item(&"potion")         # the script's lines
	await say("Here you go!")
```

A condition is `func check(): return (<source>)`, its answer seen as it is:
one that is not `true` or `false`, or that waits, is logged and is false.
Compiling takes about 0.15 ms; a script that does not compile is logged
once, with its map, event, page and command (its line n is the compiled
class's line n + 3, as Godot's error says), and is skipped (a condition is
false). Typing warnings (untyped declarations, unsafe access…) do not stop
a script, whatever the project's settings. A route step's script runs at
once, its route not waiting for it; `this` is the moving event.

**A context per list.** A list running gets one context, and its scripts
share it: `this` (the event, or null), `memory` (a Dictionary kept for the
whole list, where a script leaves what the next one reads).

## The engine's words (`WgScriptContext`)

For any game, in the engine's own vocabulary; each feature adds its own.
The first set:

| Word | Does |
|---|---|
| `this`, `player`, `character(n)` | the event, the player, a character as commands name them |
| `flag(name)`, `set_flag(name, on := true)` | a story flag (feature 7) |
| `value(name)`, `set_value(name, v)` | a story value |
| `local(letter)`, `set_local(letter, on, event := 0, map := &"")` | a local switch |
| `say(text)`, `ask(question, choices) -> int` | a message, a choice (awaited) |
| `give_item(id, count := 1)`, `take_item(…)`, `has_item(id)`, `item_count(id)` | the bag (feature 8) |
| `sees_player(reach, side := 0)`, `player_in_line(reach, direction)`, `player_in_rect(size)` | as feature 21's conditions |
| `wait(seconds)`, `transfer(map, cell, facing := Vector2i.ZERO)` | as the commands |
| `start_common(n)`, `play_effect(name, volume, pitch)` | as the engine's |
| `player_in_circle(distance_squared)` | as feature 21's condition |
| `memory`, `this`, `player` | the list's memory, its event, the player |
| `erase(event)`, `erase_forever(event)` | this event, or `event`, removed until its map is built again, or for good (feature 21) |
| `party`, `trainer`, `give_pokemon(species, level, options := {})` | the party and the trainer; a Pokémon made and added (feature 23) |
| `next_message_asks(choices, answered, cancel := -1)` | the list's next message asks `choices`, `answered` given the index taken (feature 23) |
| `engine` | `Wildgrass`: every service, for what has no word yet |

## A tool's words: a module

A module is a script extending `WgScriptContext` with a tool's words, in
the tool's own folder (`addons/wildgrass/studio/studio_script_context.gd`
for Studio). A project has one script context: the setting
`wildgrass/events/script_context` (default: `WgScriptContext`). Installing
the Studio layer sets Studio's. A game that wants words of its own extends
its context and names its own script in the setting. Nothing of the
engine depends on a module.

**Studio's words.** The names Studio's scripts call, doing what they do in
Studio, on the engine's services. A word the engine cannot do yet logs
"not handled yet: <word>" once and does nothing. They come with the
features that do them (the party with the party, battles with battles…);
first: `gv`, `set_gv`, `gs`, `set_gs`; `gp`, `ge()`, `get_character()`
(`x`, `y`, `direction`, `moveto()`); `set_self_switch`, `get_self_switch`;
`player_spotted`, `trainer_spotted`, `player_spotted_rect`,
`trainer_spotted_rect`, `player_spotted_directional`, `detect_player`,
`detect_player_rect`, `detect_player_circle`; `delete_this_event_forever`,
`delete_event_forever`, `delete_event`; `text.set_variable`,
`text.unset_variable`, `text.reset_variables`; `cry_pokemon`. With the
party (feature 23): `actors`, `pokemon_party`, a Pokémon's members,
`pokemon_from_hash`, `add_pokemon`, `add_specific_pokemon`,
`add_rename_pokemon`, `choice`, `ext_text`. Next, with their features: the
items with their messages (`give_item`, `add_item`, `pick_item`), the
following Pokémon, the sheets' animations, emotions…

**From Ruby to GDScript**, the rules an importer and a developer follow:

| Ruby | GDScript |
|---|---|
| `gv[26]`, `$game_variables[26]` | `gv(26)`; `gv[26] = 3` is `set_gv(26, 3)` (GDScript cannot index an object by a number) |
| `gs[12]`, `$game_switches[12]` | `gs(12)`; `set_gs(12, true)` |
| `gp`, `$game_player` | `gp`: the player as Studio sees it (`x`, `y` from its map's origin, `direction` 2, 4, 6 or 8) |
| `ge`, `ge(3)`, `get_character(3)` | `ge()`, `ge(3)`, `get_character(3)` |
| a method ending in `?` | the same without it: `player_spotted(3)`, `bag.contain_item(&"potion")` |
| `:town_map` | `&"town_map"` |
| `$actors`, `$bag`, `$quests`, `$pokedex`… | `actors`, `bag`, `quests`, `pokedex`…: the engine's, with Studio's method names |
| `Module::Name.method` | `name.method`: the module's last name in snake_case |
| `@choices` | `memory.choices` |
| `&&`, `\|\|`, `!`, `nil` | `and`, `or`, `not`, `null` |
| `list.map { \|x\| … }`, `.each`, `do … end` | `list.map(func(x): …)`, `for x in list:` |
| keyword arguments `f(1, volume: 80)` | a Dictionary last: `f(1, {volume = 80})` |

## Characters lifted and the view nudged (step 4)

The sample's elevators, its teleporters and its library's scene lift a
character pixel by pixel (Studio's `offset_screen_y`), loop until it is
high enough, and nudge the view along (`gm.scroll_up(16)`). Without these
words a loop never ends and the game stands still: 37 of the sample's 59
doors.

**The engine's**, for any game:

| Word | Does |
|---|---|
| `WgWalker.look_offset` (`Vector2`, game pixels) | moves what the walker shows, its cell unchanged |
| `WgWalker.shadow_offset`, `WgWalker.shadow_shown` | moves its shadow, hides it |
| `Wildgrass.screen.scroll_by(pixels)` | moves the view at once, held within the map, as a scroll does (step 2 of feature 21) |
| `Wildgrass.followers.put_back()` | the line back on the traveller's cell, hidden (what `enabled` does when it changes) |

The player's look offset, shadow offset and shadow are kept by the save,
with where it stands (the `map` part), as the reference keeps its player.

**Studio's**, in the Studio layer:

| Studio | Words |
|---|---|
| a character's `offset_screen_x`, `offset_screen_y` | its `look_offset`, in Studio's screen units: 32 a cell, so a game pixel is `tile_size / 32` of one; `nil` is 0 |
| `offset_shadow_screen_x`, `offset_shadow_screen_y` | its `shadow_offset`, the same units |
| `shadow_disabled` | not `shadow_shown` |
| `reset_follower` | on the player, its line put back (Studio lets go of the characters following it); on an event, nothing: no event leads a line yet |
| `leave_cycling_state` | nothing: the engine has no bike yet, the player never rides |
| `gm` (`$game_map`): `scroll_up`, `scroll_down`, `scroll_left`, `scroll_right(distance)` | `Wildgrass.screen.scroll_by()`, Studio's distance in its map units: 128 a cell |
| `follow_me`: `smart_disable()` | the followers' line off if it is on, remembered (kept by the save) |
| `follow_me`: `smart_enable()` | the line on if a `smart_disable()` once found it on (remembered as the reference's, never forgotten), else off |
| `follow_me`: `update()`, `reset_position()` | nothing to do (the line follows by itself); the line put back |

**The translator** (the rules above): a character's `offset_screen_x`,
`offset_screen_y`, `offset_shadow_screen_x`, `offset_shadow_screen_y` and
`shadow_disabled` read and written, `+=` and `-=` on them; Ruby's
`a = b = value` as two lines (`b = value`, then `a = b`); `reset_follower`
and `leave_cycling_state` called on a character; `gm`'s scrolls; a
module's `FollowMe` as `follow_me`.

**Checked** on the sample: every door gone through (`doors.gd`) leads to its
map with the screen as it should be, the scenes given a minute to play.

## The Studio importer

A script command (355 and its 655 lines), a script condition, a route's
script step:

1. **The project's translation**, if it has one: `res://studio/scripts/`,
   one file per Ruby script, `<hash>.gd`, the hash the first 12 hex of the
   SHA-1 of its Ruby. It is a real GDScript file extending Studio's context,
   its Ruby in a comment at its top, with `func run() -> void:` (a script,
   a route's step) or `func check():` returning the condition: written in
   the Godot editor, with its completion. The importer takes that
   function's body.
2. Else **the importer's own translation** (`studio/studio_ruby.gd`), for
   a script made only of words Studio's context has, by the rules above;
   statements: calls, `gv[n] = …` (`+=`, `-=` too), `gs[n] = …`,
   `gp.direction = …`, `@name = …`. Feature 21's condition kinds are no
   longer written: a script condition becomes a `SCRIPT` condition.
3. Else the Ruby is kept (a raw command, a condition not read, a step's
   `original`) and reported; the importer writes its file in
   `res://studio/scripts/to_translate/`, its body `pass` (or `false`), for
   a developer to fill and move up a folder.

The project's script context is Studio's: a Studio project gets it when
the layer is installed; a game imported once from Studio names it in its
settings (the importer says so).

The sample's scripts get their GDScript this way: the importer's for most,
written by hand for the others (the tower's team choice first), with
credit to their authors.

## Not changed

Feature 21's condition kinds (`PLAYER_SEEN`…) stay: the inspector's way
without code; `sees_player()` and `player_spotted()` call the same engine
function. The Studio importer writes scripts in their place.

## Decided

1. `gv(26)` and `set_gv(26, 3)` for `gv[26]`.
2. One script context per project, a game extending it for its own words.
3. Translations: one `.gd` file per Ruby script in `res://studio/scripts/`,
   named by a hash of its Ruby.
4. Scripts only as text (`source`), no "function of a game script"
   reference: one way to write them; a script may call the game's own
   autoloads.

## In steps

1. `WgEventScript`, `SCRIPT` conditions, `CALL` steps; `WgScriptContext`
   and its first words; the setting; compile errors located.
2. Studio's context and its first words; the importer's translation and
   the project's translations; the conditions read so far written as
   GDScript.
3. Then each feature adds its words (the party next, and the tower's team
   choice written by hand in the sample).
4. Characters lifted and the view nudged: the look and shadow offsets,
   the view scrolled by pixels, the followers' line; their Studio words.

## Tests

Scripts built by the tests. Covered (step 1): a list's script with the
engine's words (flags, values, local switches, characters, the player);
the list waiting for a script that waits, and its scripts sharing their
memory; a script that does not compile logged once with its place and
skipped, in a list and in a condition; a condition's answer, true, false,
or neither (logged); seeing the player in a condition; the project's
context giving its own words, a wrong one logged; a route step's script,
and a step not translated reported. Step 2: each translation rule, in a
condition and in a script; what stays raw; the project's translation
winning, a file to translate written once and kept; each of Studio's
words run (variables, switches, characters from their map's origin, local
switches of a map by its number, the detections, events deleted for good
and still deleted when their map is built again, text variables); the
Studio layer naming its context, unless the game names one.
