# Feature 4 — Dialogue

Status: implemented.

Messages written letter by letter in a box; questions with choices; talking
to what the player faces: signs, things to examine. Texts and languages are
feature 5, characters of the map feature 6, story conditions feature 7.

## Saying something

```gdscript
await Wildgrass.dialogue.say("Welcome to the [color=red]Pokémon Center[/color]!")
await Wildgrass.dialogue.say("I'm Alix.", {"speaker": "Alix", "speaker_color": Color.RED})
var answer := await Wildgrass.dialogue.ask("Shall I heal your Pokémon?", ["Yes", "No"])
if await Wildgrass.dialogue.confirm("Save the game?"):   # Yes / No, cancel = No
	pass
```

- `say()` returns once the player has read the last page. `ask()` returns the
  index of the choice taken.
- **The box stays open between messages**: it closes at the end of the frame
  in which the last one ended, unless another `say()` or `ask()` follows.
  `await say(a)` then `await say(b)` never makes it flicker.
- A message goes through `tr()`, then `Wildgrass.texts.format()` (feature 5:
  names, keys, gendered words), then the filter hook
  `message_text(text, options)`, then its tags are read (below). Speakers and
  choices go through `tr()` and `format()` too. A handler may change
  `options` (a speaker named in the text itself). **What a handler puts in
  goes through `Wildgrass.dialogue.escape()`** (`[` → `[lb]`): a nickname
  written `[page]` stays text.
- `close()` closes the box at once. A pending `say()` returns, a pending
  `ask()` returns `cancel` (or `-1`); so they do if the box is freed, or a warp
  or a reload happens during the message, which closes it. Crossing a seam
  keeps it.
- **The key that ends a message never starts something else**: the press that
  closes a sign does not read it again, whenever Godot closes the box in that
  frame (`Wildgrass.screens.took_input()`).

| Option | Default | |
|---|---|---|
| `speaker` | none | name shown beside the box, through `tr()` |
| `speaker_color` | the label's | |
| `portrait` | none | a `Texture2D` shown beside the box |
| `style` | `Wildgrass.dialogue.style` | see the box |
| `place` | `bottom` | `top`, `middle` |
| `auto` | `0` | seconds after the last page before going on without the key (battles) |
| `hold` | `false` | returns once written; the box stays until the next message or `close()` (“Saving…”) |
| `walk_away` | `false` | a direction other than the one faced ends the message, and the player walks on that way (signs) |
| `screen` | `message_box` | another screen extending `WgMessageBox` (a battle's box) |

Signals: `opened`, `page_shown`, `advanced` (the key took the text on),
`message_finished`, `choice_moved(index)`, `choice_made(index)`,
`choice_refused(index)`, `closed`. Sounds and animations hang from them.

From Kotlin or C#: `call("say", …)`, then the `message_finished` signal.

## The box

A replaceable screen, `message_box`, extending `WgMessageBox` (`WgScreen`).
The engine's own scene uses Godot's default theme, no asset:

```
MessageBox (WgMessageBox)
├── Frame (PanelContainer)
│   └── Margin (MarginContainer)
│       └── Text (RichTextLabel)  BBCode on, no scrollbar
├── Speaker (PanelContainer)      optional
│   └── Name (Label)
├── Portrait (TextureRect)        optional
├── Waiting (CanvasItem)          optional: shown while a written page waits
└── Choices (VBoxContainer)       optional, with one Button as a model
```

A game restyles it by inheriting the scene (font, `StyleBoxTexture`,
margins) and pointing `wildgrass/screens/message_box` to it. Node paths are
exports of `WgMessageBox`; `arrange = false` keeps the scene's own layout
instead of placing the nodes as below. Optional nodes stay hidden when unused.

- **Letter by letter**, through `visible_characters`: BBCode and Godot's text
  effects keep working while the text is written.
  `Wildgrass.dialogue.letters_per_second` comes from the config and can be
  changed by the options; 0 writes each page at once.
- **The confirm action**, or a click on the box: text still being written →
  all of it at once; written → the text goes on, else the message ends.
- **How the text goes on** (`advance` in the config):
  - `page` (default): a page is as many lines as `Text` shows, laid out by
    Godot with its font, width and wrapping, so a page breaks where the text
    wraps anyway. The box clears and writes the next one.
  - `scroll`: the lines slide up one by one at `scrollSpeed`, the next one
    written below, as in older games.

  Never a scrollbar. Each language breaks where it must, since layout follows
  `tr()`. How many lines: as many as `Text` is tall.
- **`place`** moves the box; the speaker's name sits above it, below when the
  box is at the top.
- **`style`** sets `theme_type_variation` on `Frame`: a game draws a sign's
  frame as a variation of its Theme, `"sign"` → `MessageFrame_sign`. None
  defined: the default frame. `Wildgrass.dialogue.style` is the default, for
  a frame the player picks in the options.

## Tags

Look and colour are Godot's BBCode (`[color]`, `[b]`, `[font_size]`, `[img]`,
`[wave]`…). The engine adds its own tags, taken out before the text reaches
the label and acted on when writing reaches them:

| Tag | Effect |
|---|---|
| `[page]` | a new page here |
| `[pause=0.5]` | writing stops for that many seconds |
| `[speed=2]` | letters per second × 2 until the end of the message; `[speed]` alone: back to normal |
| `[wait]` | writing stops until the confirm action |

- **Every tag runs once, in order**, however the text is shown.
- The confirm action while writing shows the text up to the next `[wait]`,
  running the tags on the way; `[pause]` is skipped. So does a pace of 0.
- A tag that returns a signal holds writing until it is emitted, and the key
  does nothing meanwhile: a jingle plays to its end.

**A game adds its own**: `Wildgrass.dialogue.add_tag(&"give", _give)`. The
callable gets the tag's value as a `String` (`[give=potion*3]` → `"potion*3"`)
and runs when writing reaches it; if it returns a signal, writing waits for it
(a jingle). A name of Godot's BBCode, or one already taken, is refused. An
unknown tag is left to the label, which shows it, and logged.

## Questions

`ask(text, choices, options)`. Options: `default` (0), `cancel` (the last
choice; `-1`: cancel does nothing).

- The choices appear once the question's last page is written, against the
  box's right edge: above it, below when the box is at the top.
- Up and down move, with wrap-around; confirm picks; cancel answers
  `cancel`. Only the config's actions do: the Buttons take no keyboard focus,
  the mouse and touch pick with them.
- A choice is a `String`, through `tr()`, or `{"text": …, "disabled": true}`:
  shown, never picked (`choice_refused`).
- The list shows `maxChoices` (config) at most, and only as many as fit
  between the box and the edge of the screen; beyond, it scrolls, the
  selection kept in view.

## Talking to what you face

The player's input reads one more action, `interact` (`ui_accept` by
default, in `movement_config.json`). Pressed while the player stands still,
the engine looks at the cell faced, on the player's level:

1. **A `WgInteractable`** covering it, on that level, found by global
   position (one inside a walker is that walker). Its `_interact(walker)`
   runs; the player reads no input until it returns, the interactable is
   freed, or a warp or a reload happens; crossing a seam keeps it waiting.
2. **A counter**: tile data `counter` on that cell → the cell beyond is looked
   at instead (a nurse behind her desk).
3. **Tile data `message`** (`String`): said as is. Every bookshelf of a
   TileSet says the same thing without an object per shelf.
4. Then, in every case, the filter hook `interact(handled, cell, walker)`: a
   game adds surfing on the water faced, say.

Tile data is read as `Wildgrass.tiles.data()` reads it: the top tile that
sets it, whatever the level; `covers` hides what a deck covers.

`Wildgrass.walkers.interact(walker)` does the same for any walker;
`Wildgrass.walkers.is_busy(walker)` is true while an interaction holds it.

`WgInteractable` (`Node2D`), placed on its cell:

| Field | Default | |
|---|---|---|
| `size` | `(1, 1)` | cells covered, from its own |
| `level` | `0` | inside a walker: the walker's |
| `sides` | all | the directions the player may face while talking to it (`Up` alone: read from below) |

Signal `interacted(walker)`. It blocks nothing: what is drawn blocks through
the TileSet, a sign included.

`WgSign` extends it: `text` (multiline, `[page]` inside), said with
`style = "sign"` and `walk_away`. Anything else (a clock that tells the time,
a television) is a game's subclass overriding `_interact()`.

## Config

`dialogue_config.json`:

```json
{
	"lettersPerSecond": 50,
	"advance": "page",
	"scrollSpeed": 60,
	"maxChoices": 6,
	"actions": { "confirm": "ui_accept", "cancel": "ui_cancel", "up": "ui_up", "down": "ui_down" }
}
```

`scrollSpeed` is in pixels per second. A value not positive is logged and
reset; an unknown `advance`, logged, gives `page`.

## Later

- Entering a number (quantities): with the bag, feature 8. Naming the player
  or a Pokémon: its own screen, with the new game.
- The money shown beside a shop's question: feature 8, as a tag.
- Text placeholders, the key bound to an action, words that follow the
  player's gender: feature 5. Story variables: feature 7.
- A character turning toward the player it talks to: feature 6.

## Tests

Box, maps, TileSets and interactables are built by the tests; time is advanced
by hand and input simulated with Godot's input actions.
Covered: letter by letter, showing and ending with the key, the box kept
between messages and closed after the last, pages as the label lays them out,
the last page's scroll, `[page]` in both modes, scrolling line by line, each
tag, tags run once in order when skipped, a tag that holds writing, a pace of
0, tags a game cannot take, unknown tags, `tr()` then the hook and its
options, escaping, speaker, portrait, style and its default, places, a game's
own box, `auto`, `hold`, `walk_away`, another box screen, messages cut by
`close()`, a freed box or a warp, a seam that keeps the box, a click, option
and config errors, missing actions; choices shown once written, the default,
moving round, cancel and its values, `confirm()`, disabled choices, the mouse,
only the config's actions, scrolling and fitting the screen, placing,
questions cut short or whose box cannot open, wrong questions; reading a sign,
the player held, the key that ends a sign, walking away, sides, size and
level, an interactable in a walker, counters, tile messages, the interact
hook, an interaction ended by its end, a freed target or a warp, a seam that
keeps it.
