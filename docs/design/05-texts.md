# Feature 5 — Texts and languages

Status: implemented.

What the game says, in the player's language: the game's own texts and the
engine's labels through Godot's translations, the language and its choice,
placeholders filled when a text is shown.

## The game's texts: Godot's translations

A game writes its texts in one language and translates them as any Godot
project does: `.po` or `.csv` files listed in *Project Settings →
Localization*, `tr()` and `tr_n()` in code, labels that translate themselves,
images swapped per language by Godot's remaps. The engine translates what it
shows the same way: messages, speakers, choices.

The engine's own labels ("Bag", "Text speed") are plain English:

```gdscript
Wildgrass.texts.label("Bag")                 # translated, then placeholders filled
Wildgrass.texts.label("{count} left", {"count": 3})
```

Screens show their words through `label()`; a game translates them as any
Godot text.

## Studio's texts

The core reads no Studio file. A Studio project's text files
(`Data/Text/Dialogs/<file>.csv`) are read by the Studio layer (feature 10
bis): a line, a whole file, `{text:file:line}`, Studio's `[VAR …]` tokens,
and the engine's labels in Studio's words.

## The language

```gdscript
Wildgrass.texts.language = "fr"          # TranslationServer.set_locale()
Wildgrass.texts.languages()              # ["fr", "en"]: choosable, in order
Wildgrass.texts.language_name("fr")      # "Français"
Wildgrass.texts.label_in("fr", "Bag")    # "Sac": another language than the one shown
Wildgrass.texts.is_given_in("fr", "Bag") # true if it has words of its own in French
```

- Signal `language_changed(code)`. Godot refreshes labels itself; what a game
  built from texts, it builds again.
- `label_in()` tells nothing that follows the language; a placeholder that
  picks a language asks `reading_language()` (Studio's texts do).
- At start: `default` if set, else Godot's choice (the system's).
  Keeping the player's choice is the options' (feature 10); asking it on the
  first launch, the title screen's (feature 11).

## Placeholders

```gdscript
Wildgrass.texts.set_value(&"player", "Ludo")
Wildgrass.texts.set_value(&"rival", func() -> String: return rival_name)
Wildgrass.texts.format("Welcome, {player}! Ready{player_girl?e|}?")
```

| Placeholder | Gives |
|---|---|
| `{name}` | the value, as text; a `Callable` is called each time |
| `{name?yes\|no}` | `yes` if the value is true, a non-zero number or a non-empty text, else `no`: gendered words, plurals |
| `{key:action}` | the key bound to an input action, else its first input, through the filter hook `key_name(name, action)` (button glyphs) |
| `{name:argument}` | a placeholder a plugin adds: `add_placeholder(name, callable)`, the callable given the argument (`{text:file:line}`, the Studio layer's) |

- `set_value(name, null)` removes a value. The filter hook
  `text_value(value, name)` gives values the game computes (feature 7 adds
  story variables there).
- An unknown name stays as written, logged once.
- The filter hook `text_tokens(text)` rewrites a text before its placeholders
  are read: the Studio layer turns `[VAR PKNICK(0001)]` into `{pknick_1}`.
- Messages, speakers and choices are formatted when shown, after `tr()` and
  before the `message_text` hook; what a value puts into a message is escaped,
  so a name never reads as a tag.

## Config

`config/language.json`:

```json
{
	"default": "",
	"choosable": ["fr", "en"],
	"names": ["Français", "English"]
}
```

Without choosable languages, every locale Godot has translations for, by
Godot's name. Codes and names of different lengths are logged; names missing
are Godot's.

## Later

- Telling a text that has no translation: a tool, with the game's tests.
- Numbers and money as the language writes them: with the bag (feature 8).
- Party, trainer and story values (`\p`, `\v`, battle names): with their
  features.
- Studio's plural and gender branches (`NUMBRNCH`, `GENDBR`): in the Studio
  layer, with the battle texts that use them.

## Tests

Services and configs are built by the tests in a sandbox; the locale is put
back after each. Covered: setting the language and its signal, the default at
start, choosable languages and Godot's, names and their fallback, config
errors; values, callables, removing, truth of each kind, the value hook, keys,
their first input and hook, placeholders a plugin adds and the tokens hook,
labels translated then filled, what is missing and its log, escaping;
messages, speakers and choices formatted when shown. Studio's texts: feature
10 bis.
