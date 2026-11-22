# Feature 13 — Pokédex

Status: implemented.

What the player has seen and caught, the Pokédexes that list species in a
region's order, and the screens that show them. It reads the species
(feature 12); encounters (14) and, later, catching call it.

## Seen and caught

```gdscript
Wildgrass.pokedex.see(&"rattata", 1)        # true the first time this form is seen
Wildgrass.pokedex.catch(&"pikachu")         # caught, so seen too
Wildgrass.pokedex.is_seen(&"rattata")       # any form; is_seen(&"rattata", 1): that one
Wildgrass.pokedex.forms_caught(&"rattata")  # [0, 1]
```

- Each species keeps the forms seen and the forms caught; a form caught is
  seen. `see()` and `catch()` return true the first time, signals
  `seen(id, form, first)` and `caught(id, form, first)`. An unknown species
  is refused, logged once (feature 12).
- Everything is recorded, whichever Pokédexes the player has: a species out
  of the region counts nowhere, until a Pokédex that lists it is shown.
- `forget(id)`: as never seen (the debug tools).
- A part of the game (feature 9), `pokedex`: `{"seen": {id: [forms]},
  "caught": {id: [forms]}, "dexes": [ids], "dex": id}`; a new game has
  nothing seen. The `save_summary` hook adds `pokedex`: the species seen in
  the current Pokédex, for the cards.

## Pokédexes

```gdscript
var region := Wildgrass.pokedex.find(&"regional")   # a WgDex
region.number_of(&"bulbasaur")                       # its number in this Pokédex; 0 if not listed
Wildgrass.pokedex.seen_count(&"regional")            # species of it seen
Wildgrass.pokedex.caught_count(&"regional")
```

`WgDex` (`Resource`): `id`, `name` (a label), `start` (the first number, 1),
`creatures` (`[{species, form}]`, in order). A species' number is `start`
plus its place in it.

- Registered, else `res://dex/<id>.tres` (paths, `dex`), else a source, as
  species are. A species the list names but the engine does not know is
  logged once and skipped.
- `national`: if no Pokédex has that id, the engine's own, made of every
  species by national number, form 0, each numbered by its national number.
- `entries(id)`: the species of a Pokédex the engine knows, each `{species,
  form, number}`, in order.
- **The player's Pokédexes**: `Wildgrass.pokedex.dexes`, the ids the screen
  offers, in order, from the `pokedex` config's `dexes` (`["national"]`) at a
  new game; `add_dex(id)` gives another (the national one, late in the
  story). `dex`: the one shown, the first by default. Both are saved.

## The screens

A replaceable screen, `pokedex` (`WgPokedexScreen`), opened from the pause
menu's `pokedex` entry, before Bag, shown while the `pokedex` config's
`condition` holds (`""`: always).

- **The list**: a row per species of the Pokédex shown, its number and its
  name, marked seen or caught; a species never seen is a row of dashes.
  `hide_after_last_seen` (true): the list stops at the last species seen;
  nothing seen, every row in dashes. Beside it, the species under the
  cursor (its front picture once seen) and the counts seen and caught.
- Up and down move one row, going round; left and right ten; confirm on a
  species seen opens its entry; cancel closes. With several Pokédexes, the
  `switch` action of the config (none by default) shows the next one.
- **The entry**, `pokedex_entry` (`WgPokedexEntryScreen`): the picture, the
  number and the name; once caught, the genus, the types (their names), the
  height, the weight and the description, else question marks. The species
  cries as it opens. Up and down go to the species seen before or after,
  stopping at the ends; cancel goes back to the list, on that species. It
  is given the list's `rows` and the `index` shown.
- A game's scenes extend them: the rows (`_make_row(row)`,
  `_show_selected(row, selected)`), the species beside the list
  (`_show_species(row)`), the entry's fields (`_show_entry(row)`); `rows()`
  gives each row's `{species, form, number, seen, caught}`.

## The `pokedex` config

`config/pokedex.json`:

| Field | Default | |
|---|---|---|
| `dexes` | `["national"]` | the Pokédexes of a new game |
| `condition` | `""` | the menu entry shows while it holds |
| `switch` | `""` | the input action showing the next Pokédex |

## A Studio project

| Studio | Engine |
|---|---|
| `Data/Studio/dex/<dbSymbol>.json`: `dbSymbol`, `startId`, `creatures` | a `WgDex`: `id`, `start`, `creatures` |
| `csv`: `csvFileId`, `csvTextIndex` | `name`, that text |
| `regional.json` there | the `pokedex` config's `dexes`: `["regional"]` |

A Pokédex of the game's own wins over Studio's.

## Pokémon Mirage, step by step

| In Pokémon Mirage | In the engine |
|---|---|
| `regional.json`, Studio's format, the region's 151 species | a Pokédex, read through the Studio layer (`Data/Studio/dex/regional.json`); `dexes` `["regional"]` |
| `Pokedex.see()`, `catch()`: lists of species seen and caught, saved | `Wildgrass.pokedex`, with forms; the `pokedex` part |
| species out of the region recorded, never shown or counted | recorded, counted only among a Pokédex's species |
| the list: number and name, seen and caught marks, the frame on the row, the scroll bar; the last species seen ends it, dashes in the middle | `WgPokedexScreen`, `hide_after_last_seen`; Mirage's scene draws its rows (`_make_row()`) |
| up and down round, left and right ten, confirm the entry, the menu key closes | the same keys |
| the entry: picture, number, name; once caught genus, types, height, weight, description; else question marks; the cry | `WgPokedexEntryScreen`, `_show_entry()` |
| up and down in the entry: the species seen before or after | the same |
| the card's Pokédex count: species of the region seen | the `pokedex` summary |
| Debug → Fill the Pokédex | `see()`, `catch()` from the debug tools (feature 20) |

## Later

- Where a species lives (Studio's world maps and zones): with encounters
  and zones.
- Times caught and fought: with catching and battles.
- Searching and sorting the list.

## Tests

Species, Pokédexes, configs and Studio files are built by the tests; input
is simulated with Godot's input actions.
Covered: forms seen and caught, the first time told, a form caught seen,
forgetting, an unknown species refused; a Pokédex numbering from its start,
an unknown species in it skipped and logged once; registered, else the
folder's, else a source's, an unknown one logged; the national one by
national number unless the game has its own; counts among a Pokédex's
species; the player's Pokédexes from the config, given one more, the one
shown, an empty list corrected; saved and restored whole, a new game seeing
nothing, the cards' count. The list stopping at the last species seen,
dashes, every row when nothing is seen, the header and the side, moving
round and by ten, closing; the entry of a species seen, its fields once
caught, question marks before, going to the species seen before or after
and stopping, back on that species, its cry; the switch action, a single
Pokédex keeping the cursor; texts in the language; the pause menu's entry
and the engine's screens. Studio's Pokédexes, the regional one shown
first, the national one without it, a broken file logged, a game's winning.
