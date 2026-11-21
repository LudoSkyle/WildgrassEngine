# Feature 5 — Texts and languages

Status: implemented.

What the game says, in the player's language: the game's own texts through
Godot's translations, Pokémon Studio's text files read as data, the language
and its choice, placeholders filled when a text is shown.

## The game's texts: Godot's translations

A game writes its texts in one language and translates them as any Godot
project does: `.po` or `.csv` files listed in *Project Settings →
Localization*, `tr()` and `tr_n()` in code, labels that translate themselves,
images swapped per language by Godot's remaps. The engine translates what it
shows the same way: messages, speakers, choices.

## Studio's texts

Studio projects keep their texts in `Data/Text/Dialogs/<file>.csv`: a header
of language codes, then one line per text, `\nl` for a line break. Species
names are file `100000`, items `100012`, and so on.

```gdscript
Wildgrass.texts.studio(100000, 25)     # "Pikachu", in the current language
Wildgrass.texts.studio_file(100012)    # every line of a file
```

- Read as data, not as Godot translations: Godot asks its translations again
  and again for every label, and a file is better read once, the first time
  it is asked for, then kept.
- Language: the column of the current language; empty or missing, the
  project's fallback locale (*Localization → Locale → Fallback*), then the
  first column that has a text. A cell Studio left untranslated (`[~ 0]`) is
  empty.
- A missing file or line gives `""`, logged once.
- A regional locale reads its language's column (`fr_FR` → `fr`); a column
  code differing from the Godot locale is mapped by `studioColumns`
  (`"ja": "kana"`).
- Godot would import these files as translations: the editor plugin sets
  them to *Keep File*, so that they are read as they are and exported, and
  removes what Godot had made of them.

## The language

```gdscript
Wildgrass.texts.language = "fr"          # TranslationServer.set_locale()
Wildgrass.texts.languages()              # ["fr", "en"]: choosable, in order
Wildgrass.texts.language_name("fr")      # "Français"
```

- Signal `language_changed(code)`. Godot refreshes labels itself; what a game
  built from `studio()`, it builds again.
- At start: `defaultLanguage` if set, else Godot's choice (the system's).
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
| `{text:file:line}` | a Studio text |
| `{text:file:line\|fallback}` | a Studio text, else the fallback through `tr()`, unlogged (feature 10) |

- `set_value(name, null)` removes a value. The filter hook
  `text_value(value, name)` gives values the game computes (feature 7 adds
  story variables there).
- An unknown name stays as written, logged once.
- Studio's tokens are read as values: `[VAR PKNICK(0001)]` is `{pknick_1}`;
  one left without a value is removed, logged once.
- Messages, speakers and choices are formatted when shown, after `tr()` and
  before the `message_text` hook; what a value puts into a message is escaped,
  so a name never reads as a tag.

## Config

`language_config.json`, the file Studio projects already have:

```json
{
	"defaultLanguage": "",
	"choosableLanguageCode": ["fr", "en"],
	"choosableLanguageTexts": ["Français", "English"],
	"studioColumns": { "ja": "kana" }
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
- Studio's plural and gender branches (`NUMBRNCH`, `GENDBR`): with the
  battle texts that use them.

## Tests

Services, configs and Studio files are built by the tests in a sandbox; the
locale is put back after each. Covered: setting the language and its signal,
the default at start, choosable languages and Godot's, names and their
fallback, config errors; a line in each language, a regional locale, a mapped
column, the fallback locale then the first column, `\nl` and quoted commas,
a whole file, reading once, missing files and lines; setting to *Keep File*
and what is removed; values, callables, removing, truth of each kind, the
value hook, keys, their first input and hook, Studio references, tokens,
what is missing and its log, escaping; messages, speakers and choices
formatted when shown.
