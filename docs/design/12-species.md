# Feature 12 — Pokémon species and types

Status: implemented.

What a Pokémon is, as data: its species and their forms, and the types. No
Pokémon of the player yet (a party, levels, moves in battle): this feature
gives what the Pokédex (13), wild encounters (14) and the Pokémon following
the player (19) read, and what later features will.

## Species

```gdscript
var bulbasaur := Wildgrass.species.find(&"bulbasaur")   # a WgSpecies
bulbasaur.number                                        # 1, its national number
bulbasaur.name                                          # a label: Wildgrass.texts.label()
var alolan := Wildgrass.species.form(&"rattata", 1)     # a WgSpeciesForm
alolan.types                                            # [&"dark", &"normal"]
alolan.picture(&"front")                                # a Texture2D, or null
Wildgrass.species.all()                                 # every species, by national number
```

`WgSpecies` (`Resource`): `id`, `number` (national), `generation` (0:
unknown), `name`, `genus` ("Seed Pokémon"), `description`, `forms` (one
`WgSpeciesForm` at least; the first is form 0).

`WgSpeciesForm` (`Resource`), what can differ from one form to the next:

| Field | |
|---|---|
| `form` | its number: 0, 1… |
| `name`, `description` | empty: the species' |
| `height`, `weight` | metres, kilograms |
| `types` | one or two type ids |
| `base_stats`, `effort` | `{hp, attack, defense, special_attack, special_defense, speed}` |
| `catch_rate`, `base_experience`, `growth_rate`, `base_friendship` | numbers; `growth_rate` the curve's number, 0 to 5 |
| `female_rate` | percent of females; -1: no gender |
| `egg_groups`, `hatch_steps`, `baby`, `baby_form` | breeding |
| `held_items` | `[{item, chance}]` in the wild |
| `abilities` | ability ids: two, then the hidden one |
| `evolutions` | `[{species, form, conditions: [{type, value}]}]` |
| `moves` | `[{move, how, level}]`: `how` is `level`, `tm`, `tutor`, `egg`, `evolution` |
| `pictures` | `{kind: Texture2D or path}`: `icon`, `front`, `back`, `footprint`, `character`, each with `_shiny`, `_female`, `_shiny_female` variants; `cry` (an `AudioStream` or a path) |
| `front_offset_y` | the front picture's lift, in pixels |

- `picture(kind, shiny = false, female = false)`: the variant asked, else
  without `_female`, else without `_shiny`, else the plain one; a path is loaded the first time it
  shows, a missing file reported once (paths). `cry()` likewise.
- Abilities, moves and items are named by id: their own data come with the
  features that use them (battles, the party).
- A game registers its species (`Wildgrass.species.register(species)`), else
  `res://pokemon/<id>.tres` (paths, `pokemon`), else a source
  (`add_source(read, ids)`: `read` given an id the engine does not have
  returns a `WgSpecies` or null; `ids` lists those it has), the first time
  that species is asked for: no reading of every file, no picture loaded
  before it shows.
- `form(id, form)`: a form the species does not have is its form 0, logged
  once. An unknown species is null, logged once.
- `ids()`: the id of every species known, none read; `all()`: every
  species, read, by national number then id (a debug view, a full Pokédex).

## Types

```gdscript
Wildgrass.types.find(&"grass")                           # a WgType
Wildgrass.types.factor(&"fire", [&"grass", &"poison"])   # 2.0
```

`WgType` (`Resource`): `id`, `name` (a label), `color`, `damage`
(`{defending type id: factor}`; a type it does not name: 1).

- Registered, else `res://types/<id>.tres` (paths, `types`), else a source,
  as species. `ids()`, `all()`.
- `factor(attacking, defending)`: the factors against each defending type,
  multiplied. An unknown type is logged once and counts 1.
- The engine ships no type: a game made in Godot writes its own (18
  resources, or as many as its world has); a Studio project has Studio's.

## A Studio project

The Studio layer (feature 10 bis) gives both as sources, read on demand:

| Studio | Engine |
|---|---|
| `Data/Studio/pokemon/<dbSymbol>.json`: `dbSymbol`, `id` | species `id`, `number` |
| (none) | `generation`, from the national number |
| texts `100000`, `100001`, `100002`, line `id` | `name`, `genus`, `description` |
| `forms[]`: `form`, `height`, `weight`, `type1`, `type2` (`__undef__`: none) | the form's fields |
| `baseHp`… `baseDfs`, `evHp`… `evDfs` | `base_stats`, `effort` |
| `catchRate`, `baseExperience`, `experienceType`, `baseLoyalty`, `femaleRate`, `breedGroups`, `hatchSteps`, `babyDbSymbol`, `babyForm`, `itemHeld` (`none` dropped), `abilities`, `evolutions`, `frontOffsetY` | as named above |
| `moveSet`: `LevelLearnableMove`, `TechLearnableMove`, `TutorLearnableMove`, `BreedLearnableMove`, `EvolutionLearnableMove` | `moves`, `how` `level`, `tm`, `tutor`, `egg`, `evolution` |
| `formTextId`: `name`, `description` (0: the species') | texts `100067`, `100068` |
| `resources`: `icon`, `front`, `back`, `footprint`, `character` and their `Shiny`, `F` variants, `cry` | `graphics/pokedex/pokeicon/<icon>.png`, `pokefront`, `pokeback`, `footprints`, `graphics/characters/<character>.png` (shiny pictures in their `…shiny` folders), `audio/se/cries/<cry>` |
| `Data/Studio/types/<dbSymbol>.json`: `textId`, `color`, `damageTo` | `name` (text `100003`), `color`, `damage` |

A species or a type of the game's own wins over Studio's, as items do.

## Pokémon Mirage, step by step

| In Pokémon Mirage | In the engine |
|---|---|
| `national.tsv`, made by `tools/gamedata.py` from the data pack | the pack's own files (`Data/Studio/pokemon`, `types`, texts, pictures), read through the Studio layer: the pack is Studio's format |
| number, id, generation, names, genus, height, weight, descriptions, two types | `number`, `id`, `generation`, `name`, `genus`, `height`, `weight`, `description`, `types`; French and English from the texts' columns |
| `icon`, `overworld`, `front`, the cry, one file per species | `pictures` `icon`, `character`, `front`, `cry()` |
| only the base form | every form; Mirage asks for form 0 |
| `Species`: three made-up species for encounters, with base stats | gone: encounters (14) name real species |

## Later

- A Pokémon of the player (level, moves, nature, gender, shiny): with the
  party, after the Pokédex.
- Abilities, moves, natures as data: with the features that use them.
- An editor tool turning a Studio project's data into resources: if a game
  made in Godot wants to start from it.

## Tests

Species, types, pictures and Studio files are built by the tests, in a
sandbox of their own.
Covered: species registered, else the folder's, else a source's, each read
once, a game's winning, the id filled, an unknown species and a resource of
another class logged once; a form it does not have giving form 0 logged
once, a species with no form; ids read without reading, every species by
national number then id; pictures falling back from female then shiny,
loaded once, a missing picture or cry reported once and tried once, also
for a species read by `all()`, a cry from a plain file; types registered, else the folder's, else a source's,
factors multiplied, a type not named counting 1, an unknown type logged
once. The Studio layer: species and their forms with every field, a form's
own texts, types and pictures, names in Studio's words, every species
listed unread and a game's winning, a broken file logged once, the
generation from the national number; types with their name, colour and
damage, a game's winning.
