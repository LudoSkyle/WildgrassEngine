# Feature 10 bis — The Studio layer

Status: implemented.

The engine does not depend on Pokémon Studio. Its configs, texts and data are
its own, made with Godot's editor. A Studio project still runs as it is,
through a layer of its own: it recognises the project, reads Studio's files,
and turns them into the engine's settings and data, through the engine's
public API. What Studio can describe is a floor, never a ceiling: a game goes
as far as the engine goes, Studio or not.

Before it, Studio was mixed into the core: configs with Studio's names and
format in Studio's folder, items and quests read from Studio's JSON by their
services, the bag's pockets numbered as Studio's sockets, the engine's labels
written as Studio's text lines. This feature moved all of it into the layer.
No game ran on the engine yet: nothing is kept for older layouts.

## The core, without Studio

**Configs** are in the project's `config` folder (paths, `res://config/`), one
per name, as a Godot resource (`save.tres`, edited in the inspector) or as
JSON (`save.json`), the resource winning. JSON keys are the fields' own
names, and problems name them (`path_cells`, `letters_per_second`).

| Config | Fields |
|---|---|
| `display` | `resolution`, `window_scale`, `fullscreen` |
| `log` | unchanged |
| `language` | `default`, `choosable` (codes), `names` (each written in its language) |
| `bag` | `pockets` (`{id, name, reveal}`), `max_count`, `max_money`, `reveal_seconds` |
| `save` | `slots` (0: no limit, 1: a single game), `file` (`saves/game`), `save_anywhere` |
| `options` | `order` |
| `map`, `movement`, `dialogue` | unchanged, snake_case keys |
| `studio` | `columns`: the Studio layer's (below) |
| `title` | feature 11 |

- A plugin gives values for a config with `Wildgrass.config.add_source(name,
  callable)`: the callable returns a dictionary of fields, applied over the
  defaults; the project's own file is applied last, field by field.
  `is_given(name)`: a file or a source gives values; the `display` config is
  applied at start only then.
- The engine's **labels** are English ("Bag", "Text speed"), shown through
  `Wildgrass.texts.label(text, values)`: Godot's translations, then
  placeholders. A game translates them as any Godot text; a message's own
  `values` are labels too. `{text:…}`, and its fallback syntax, leave the
  core.
- `Wildgrass.texts.add_placeholder(name, callable)`: a plugin adds a
  placeholder (`{name:argument}`); the filter hook `text_tokens(text)` lets
  it rewrite a text before placeholders are read.
- **Items** are `WgItem` resources, registered by the game or found as
  `res://items/<id>.tres` (paths, `items`) the first time they are asked for.
  `Wildgrass.items.add_source(callable, lister)`: another origin, given an
  id the engine does not have, returning a `WgItem` or null; `lister` lists
  its ids (Studio's, by their files).
- **Quests** are `WgQuest` resources, registered or found in
  `res://quests/*.tres` (paths, `quests`).
  `Wildgrass.quests.add_source(callable)` gives others: the callable returns
  an array of quests.
- The bag's default pockets are the engine's: Items, Medicine, Poké Balls,
  TMs, Berries, Key Items (revealed), English labels, with no Studio number.
- The engine's own default for saves: `user://saves/game-1.json`, a single
  game `saves/game.json`.

## The layer

`addons/wildgrass/studio/`, `Wildgrass.studio`. It turns itself on when the
project is a Studio project (`project.studio` in the folder of paths
`studio`, `res://`), or by the project setting `wildgrass/studio/enabled`
(`auto`, `on`, `off`), before any config is read, and only calls the core's
public API. It installs once; `uninstall()` takes back the labels'
translations (tests, a project switched). Studio's data folder is paths
`data`, `res://Data/`.

**Configs** (`Data/configs/*.json`, Studio's keys, the others and `klass`
ignored), each a source of an engine config:

| Studio | Engine |
|---|---|
| `display_config`: `gameResolution`, `windowScale`, `isFullscreen` | `display`: `resolution`, `window_scale`, `fullscreen` |
| `language_config`: `defaultLanguage`, `choosableLanguageCode`, `choosableLanguageTexts` | `language`: `default`, `choosable`, `names` |
| `save_config`: `maximumSave`, `baseFilename`, `isCanSaveOnAnySave` (`saveKey` set: logged) | `save`: `slots`, `file`, `save_anywhere` |
| `game_options_config`: `order` | `options`: `order` |
| `settings_config`: `maxBagItemCount` | `bag`: `max_count` |
| `scene_title_config`, `infos_config` | `title` (feature 11) |

A file that is not a JSON object is logged. A Studio key the engine has no
use for yet is read when its feature comes: `introMovieMapId` with maps, the
Pokémon settings with the party.

**Texts** (`Data/Text/Dialogs/*.csv`), `Wildgrass.studio.texts`:

- read as data, in the current language: `line(file, line)`,
  `file_lines(file)`, `cells(file, line)`. The current language's column,
  else the fallback locale's, else the first with a text; a cell Studio left
  untranslated (`[~ 0]`) is empty; `fr_FR` reads `fr`; a column differing
  from the Godot locale is mapped by the `studio` config's `columns`
  (`{"ja": "kana"}`). A missing file or line gives `""`, logged once. The
  editor plugin keeps these files as files (*Keep File*), not translations;
- `{text:file:line}` in any text: a placeholder the layer adds;
- Studio's `[VAR …]` tokens, rewritten by the `text_tokens` hook into
  placeholders: `[VAR PKNICK(0001)]` → `{pknick_1}`, `[VAR NAME]` →
  `{name}`; a token of digits alone (a format code) shows nothing;
- the engine's English labels shown with Studio's words: at install, the
  layer makes a Godot translation per column from a table of the engine's
  labels and their Studio lines ("Bag" → `100014:2`, "Text speed" →
  `100042:3`…), so a Studio project reads "Sac" without the core knowing
  why.

**Items** (`Data/Studio/items/<dbSymbol>.json`): a source of the items
service, turned into `WgItem` as before (`klass` → `kind`, `isLimited` →
`consumed`, `socket` → pocket, icon from `graphics/icons/`; name,
description and plural `{text:…}` of files `100012`, `100013`, `9001`).
Studio's pockets, in Studio's order, their names from Studio's texts
(`{text:100015:4}`…), become the bag config's pockets; the socket numbers
stay in the layer.

**Quests** (`Data/Studio/quests/*.json`): a source of the quests service,
read as before (names `{text:100045:<id>}`, descriptions
`{text:100046:<id>}`).

**Species and types** (`Data/Studio/pokemon`, `types`): sources of the
species and types services (feature 12). **Pokédexes**
(`Data/Studio/dex`): the Pokédex service's, the regional one shown first
(feature 13). **Wild groups** (`Data/Studio/groups`): encounter tables
found by id (feature 14). **Sound design** (`sound_design_config`,
`scene_title_config`'s `bgmName`): the `audio` config and the title's music
(feature 15).

**Later**, with their features: maps (the importer), zones, the
introduction map, music.

## A Studio project and a game's own

A Studio project needs nothing more: it runs. A game made in Godot never
meets the layer. A Studio project that grows past Studio adds its own: a
config file in `res://config/` wins over Studio's values field by field, an
item in `res://items/` over Studio's, a screen of its own over the engine's.

## Steps

1. Configs: the `config` folder, resources and JSON, sources, the engine's
   names and fields.
2. Texts: English labels, placeholders and the tokens hook added by plugins.
3. Items and quests: folders of resources, sources; the engine's pockets.
4. The layer: recognising a project, configs, texts and labels, items and
   pockets, quests; the editor keeping Studio's text files.
5. Docs: this one implemented, the earlier ones without Studio in the core.

## Tests

The core's tests use no Studio file. The layer's, in `tests/studio/`, make
their sandbox a small Studio project (`tests/support/studio_project.gd`) and
install the layer on their own services.
Covered: the config registry's sources over the defaults and the project's
file over them field by field, a resource winning over its JSON, one of
another class ignored; items registered, else resources of the items folder,
else a source's, the engine's pockets by default; quests registered, else in
the quests folder, else a source's; placeholders a plugin adds, the tokens
hook, labels translated then filled. The layer: a project recognised by its
file unless the setting says otherwise, Studio's configs becoming the
engine's, the project's own winning field by field, a save key and a broken
file logged, Studio's pockets in Studio's order with their names, the
engine's labels in Studio's words until uninstalled, installed once, a Godot
project never meeting it; Studio's texts in the current language, a regional
locale, a mapped column, the fallback locale then the first column,
untranslated cells, whole files, read once, missing files and lines logged
once, set to *Keep File*, `{text:…}` and tokens in any text; Studio items read
once on demand, icons loaded when shown and a missing one reported once, a
game's item winning; Studio quests read, their names following the language,
played like any other, a game's winning, bad files logged.
