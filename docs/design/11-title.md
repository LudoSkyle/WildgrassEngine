# Feature 11 — Title screen

Status: implemented.

What happens between launching the game and walking on its first map: splash
images, the language chosen at first launch, the title screen, the choice of
a game, a new game on the start map, a game continued, and back to the title.

The engine gives the flow, the `title` config and plain screens in Godot's
theme. A game's title screen is its own scene, free to do anything Godot
does: the engine only runs the steps and asks the game's scene to show them.
Pokémon Mirage's title (its arrival, "Press Enter", its row of cards with
Options among them, its fade to the map) is a setting of the same screens
with its own pictures, as a Studio project's is through the Studio layer
(feature 10 bis).

## The `title` config

`config/title.json`, or `title.tres`:

| Field | Default | |
|---|---|---|
| `show_at_start` | `false` | the engine calls `Wildgrass.title.start()` itself once ready; else the game calls it, or never (a game with no title, the tests) |
| `start_map`, `start_point` | `""` | where a new game starts; an empty point is the map's first spawn point |
| `splashes` | `[]` | images shown one after the other before the title (paths) |
| `choose_language` | `false` | the language is asked at first launch |
| `show_prompt` | `true` | the title waits for a key ("Press Enter") before going on |
| `show_choices` | `true` | the title offers its choices; without them, the key goes straight to Play |
| `controls_delay` | `0.0` | seconds before the title's choices take a key |
| `fade_seconds` | `0.6` | the fade from the title to the map |
| `name` | the project's name | shown by the engine's screen when it has no logo |
| `background`, `logo` | `""` | the engine's screen's pictures (paths) |

## The flow

```gdscript
Wildgrass.title.start()        # splashes, the language at first launch, then the title
Wildgrass.title.back()         # from a game: back to the title
```

1. **Splashes**: each image of `splashes` on the `splash` screen: it fades
   in, stays, fades out (0.4, 1, 0.4 seconds); confirm skips it. A missing
   image is reported once and skipped.
2. **The language, at first launch**: when `choose_language`, two languages
   or more are choosable, no language was ever kept in the options and no
   game is saved: the `language_choice` screen lists them by their names; the
   one picked is kept as the `language` option (feature 10).
3. **The title screen** (`title`); signal `title_shown`, where a game plays
   its title music until sound (feature 15) takes it.

`back()` drops the current map and its neighbours (`Wildgrass.maps.clear()`,
which ends every interaction and scripted walk), closes every screen (the
message box with what it had to say), resets
every part of the game (`Wildgrass.save.reset()`), then shows the title
again, without the splashes; refused while a map changes. Signal
`back_to_title`. The traveller waits out of the tree for the next game; a
game that ends at the title has the engine free it. `show_title()` opens the title alone, or returns the one
already open.

## The title screen

A replaceable screen, `title` (`WgTitleScreen`). A game's scene extends it and
keeps its own pictures and animations (clouds, birds, a logo that floats);
the screen runs the steps:

1. **Arrival**: black lifts over `fade_in_seconds` (0.5), then the game's
   arrival plays over `arrival_seconds` (0.6), `_arrival(progress)` called
   each frame from 0 to 1 (a logo growing in). Confirm cuts it short, opening
   nothing.
2. **Waiting for a key**, when `show_prompt`: the `Prompt` node blinks,
   `blink_on_seconds` (0.7) shown, `blink_off_seconds` (0.4) hidden; confirm
   goes on.
3. **Choices**, when `show_choices`: a column of choices, as the menu's
   entries (feature 10), taking keys after `controls_delay`, waited the first
   time they show only. Without them,
   the key goes straight to Play. Without a prompt, the choices come right
   after the arrival; with neither, the title waits for a key, then plays.

Cancel in a later step comes back to the one before (the choice of a game
back to the prompt); at the first, it does nothing. While a choice runs (the
choice of a game open above it), the title hides the nodes of
`hidden_under_choice` that showed (the logo, the name, the prompt), keeps
living beneath, and shows them again on every way back. `advance(delta)`
moves it on, as each frame does.

The engine's scene: the config's `background` behind, its `logo` over it,
else its `name`; "Press {key:ui_accept}" as its prompt, in Godot's theme.

```gdscript
Wildgrass.title.add_choice(&"credits", "Credits", _roll_credits, "", &"quit")
```

- `add_choice(id, text, callable, condition = "", before = &"quit")`,
  `remove_choice(id)`, `choices()`: as the menu's entries, awaited, true to
  close the title. Texts are labels.
- The engine's choices:

  | Id | Text | Does |
  |---|---|---|
  | `play` | Play | no game saved: a new game in slot 1; else the choice of a game |
  | `options` | Options | opens `options`, back to the title |
  | `quit` | Quit | quits the game; not shown on the web or on mobile |

## The choice of a game, from the title

The `save_slots` screen (feature 9) gains settings, so that a game's own
scene changes how it looks, not what it does:

| Setting | Default | Pokémon Mirage |
|---|---|---|
| `horizontal` | false: up and down | true: left and right move along a row |
| `wrap` | false | true: the row goes round |
| `new_game_card` | `each_free`: a card per free slot | `first_free`: one "New game" card, for the first free slot, gone when every slot is taken |
| `options_card` | false | true: an Options card, last, opening `options`; back from it, the cards are written in the language chosen |
| `_make_card(slot, summary)`, `_show_selected(card, selected)` | a button with the card's template, pressed under the cursor | the game's card: portrait, name, place, badges, Pokédex, time, the party's six cells; the others dimmed |
| `_ask_new_game(slot)`, `_ask_action(slot)`, `_ask_erase(slot)` | the message box: New game / Cancel; Continue / Erase / Cancel; "Erase file {slot}?", No selected | the new game at once; the game's own choice box |

The Options card's slot is `WgSaveSlotsScreen.OPTIONS_CARD`; it shows when
the screen is given `open_options`, as the title gives it. Cancel closes the
screen (`chosen(0, cancel)`); from the title, back to the prompt.

## A new game, a game continued

From the title, both leave the same way, over `fade_seconds`: the screen
fades to black, the title hides beneath it, the map loads, black lifts, the
title closes. Closed last, the screens waiting on a choice are still there
when it returns, and say what was chosen.

- **New game** (`Wildgrass.title.new_game(slot)`): `Wildgrass.save.new_game
  (slot)`, every part reset, hook `new_game`; the traveller
  (`Wildgrass.maps.traveller`, set by the game) arrives at `start_map`,
  `start_point`. No start map, or no traveller: logged, and the title stays.
  A start map that cannot be reached: logged, the game reset, black lifts
  over the title again.
  A name, a look, an introduction: the game's, on its start map or in the
  `new_game` hook.
- **Continue**: the game is loaded (feature 9). One that cannot be loaded
  says so, and the choice stays.
- Signal `game_started(slot, new)`, once the black has lifted.

Play time counts from the game, not from the title: a new game starts at 0, a
game continued where it was saved.

## Pokémon Mirage, step by step

| In Pokémon Mirage | In the engine |
|---|---|
| black lifts, the logo grows in, a key cuts it short without opening anything | the arrival: `fade_in_seconds` 0.5, `arrival_seconds` 0.6, `_arrival()` |
| "Press Enter" blinks, 0.7 s shown, 0.4 s hidden | `show_prompt` true, `blink_on_seconds`, `blink_off_seconds` |
| the key opens the choice of a game at once | `show_choices` false |
| the logo leaves, the sky and the tower go on beneath a veil | `hidden_under_choice`; the veil is the choice's scene |
| a row of cards that goes round, one "New game", an Options card | `horizontal`, `wrap`, `new_game_card` `first_free`, `options_card`, `slots` 3 |
| the cards: portrait, name, place, badges, Pokédex, time, six cells, the others dimmed | `_make_card()`, from the summary (feature 9), `_show_selected()` |
| "New game" starts at once | `_ask_new_game()` returning true |
| Continue / Erase / Back, then "Erase game 1?" with No selected | `_ask_action()`, `_ask_erase()` |
| Escape back to "Press Enter" | cancel back to the step before |
| a 0.6 s fade, the title gone in the black, the map loading | `fade_seconds` 0.6 |
| the title music | `title_shown`, until sound |
| the tests skip the title | `show_at_start` false |

## A Studio project

The Studio layer gives the `title` config, as for the others:

| Studio | Engine |
|---|---|
| `scene_title_config`: `additionalSplashes` | `splashes`: `graphics/titles/<name>.png` each |
| `scene_title_config`: `isLanguageSelectionEnabled` | `choose_language` |
| `scene_title_config`: `controlWaitTime` | `controls_delay` |
| `infos_config`: `gameTitle` | `name` |
| (no "Press Enter" in Studio) | `show_prompt` false |
| `graphics/titles/background.png`, `title.png`, when they exist | `background`, `logo` |

The title's choices and the questions of the choice of a game say Studio's
words: Play, Quit, New game, Continue, Erase, as the menu's (feature 10 bis);
the cards' templates ("File {slot}") have no Studio line and stay the
engine's labels. The project's own `config/title.json` wins
field by field: a Studio project
that wants its own title screen writes its scene and keeps Studio's
splashes, or not. Studio's start map lives in its RPG Maker data, which the
engine does not read: a Studio project sets `start_map` until the map
importer reads it.

## Later

- Studio's `introMovieMapId` (a map played as an introduction) and its start
  map: with the Studio map importer.
- Credits (Studio's `credits_config.json`): a screen of their own, later; a
  game adds a Credits choice meanwhile.
- A "Back to the title" entry in the pause menu: a game adds it in one line,
  `Wildgrass.menu.add_entry(&"title", "Back to title", Wildgrass.title.back)`.
- Choosing the player's name and look: with the trainer (features after 12).

## Tests

The title's tests use a test world, maps built in `user://`, recording
screens and transitions, and the engine's screens; time is advanced by hand
and input simulated with Godot's input actions. The Studio layer's make
their sandbox a small Studio project.
Covered: the config's defaults and negative times; splashes in order, a
missing one reported once, a second start ignored; the language asked at
first launch and kept, not asked unless wanted, once kept, with a game saved
or a single language; the title screen given the services and opened once;
the choices before Quit or another, replaced, removed, their conditions;
Play with no game starting one in slot 1 on the start point behind the fade,
the title hidden then closed, the hook, the play time reset; no start map,
no traveller, a start map that cannot be reached; the choice of a game
opened over the title, continuing, a game that cannot be loaded, a free slot
starting a new game there, with a real fade; Options and Quit; back to the
title, in the middle of a message or a walk, and refused while a map
changes; the engine showing the title only
when the config says so, and freeing a traveller left out of the tree. The screen: black lifting and the arrival, a key
cutting it short, the prompt blinking and its key, the pictures else the
name, the choices and cancel, no prompt, no choices, neither, the controls'
delay waited once, nodes hidden while a choice runs and shown again, one already hidden
staying so, a choice closing the title, back from the choice of a game to
the prompt, the language followed. Splashes fading and skipped; the
language listed from the current one, round, picked, cancel ignored. The
choice of a game: rows going round, one new game card, with no maximum, an
Options card written again once back, a game's own cards and questions.
Maps cleared, every part reset. Studio's title config and the project's
winning, Studio's words.
