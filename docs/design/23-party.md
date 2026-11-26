# Feature 23 — Pokémon and the party

Status: steps 1 (the data) and 2 (the trainer, a Pokémon) done; step 3 to
come.

The player's Pokémon: each one as the reference makes it (its level and
experience, nature, IVs and EVs, stats, gender, shininess, ability, moves,
held item, friendship, status, nickname, where and how it was caught), and
the party that carries up to six of them. A game written in Godot makes
and gives Pokémon with the engine's own words; a Studio project's scripts
do with Studio's (`$actors`, `add_pokemon`, `generate_from_hash`…),
through feature 22.

Not here: battles, evolution, the PC's boxes, the party's screen, eggs
hatching, the daycare, contests: each its own feature, on this model.

## The data a Pokémon needs

Species and types are there (features 12, 13). Added, each a catalog as the
species' (feature 12: registered, then `res://<folder>/<id>.tres`, then a
source; the engine ships none), with the Studio layer's source reading
`Data/Studio/…`:

| Service | Resource | Studio |
|---|---|---|
| `Wildgrass.moves` (`res://moves/`) | `WgMove` | `moves/*.json`; texts in files 100006 (name), 100007 (description), 100072 (contests), by its number |
| `Wildgrass.abilities` (`res://abilities/`) | `WgAbility` | `abilities/*.json`; texts in files 100004, 100005, by its `textId` |
| `Wildgrass.natures` (`res://natures/`) | `WgNature` | `natures/*.json`; name in file 100008, by its number |

Each has `register`, `add_source`, `find` (an unknown id logged once),
`has`, `ids`, and `all` by number. Each resource has its `id`, its `number`
and its texts, labels shown through `Wildgrass.texts.label()`.

- **`WgMove`**: `type`, `category` (`PHYSICAL`, `SPECIAL`, `STATUS`),
  `power`, `accuracy`, `pp`, `priority`, `critical_rate` (0 to 6),
  `target` (whom it aims: `user`, `adjacent_foe`, `all_pokemon`…), `flags`
  (`contact`, `punch`, `sound`, `protectable`…: `WgMove.FLAGS`;
  `has_flag()`), `effect` (the battle procedure it runs) and
  `effect_chance`, `stat_changes` (`[{stat, stages}]`), `statuses`
  (`[{status, chance}]`), `map_use` (the common event it runs on the map),
  and for contests `contest_condition`, `appeal`, `jam`, `combo_moves`,
  `contest_effects`. Studio's names (`isDirect`, `ATK_STAGE`, `PARALYZED`…)
  are the Studio layer's alone.
- **`WgAbility`**: its texts.
- **`WgNature`**: `stats` (`{attack, defense, speed, special_attack,
  special_defense}`: 90, 100 or 110; `factor(stat)`, 100 for a stat not
  named), `liked_flavor`, `disliked_flavor` (empty: none). A Pokémon's
  nature is drawn by number, as the reference does: a number modulo
  `natures.count()`, then `natures.of_number(n)`, null and logged if no
  nature has it.

**Experience**: `WgExperience.total(growth, level)`, by the reference's six
formulas (`WgExperience.Growth`: `FAST`, `NORMAL`, `SLOW`, `PARABOLIC`,
`ERRATIC`, `FLUCTUATING`, a species form's `growth_rate`; any other counts
as normal), each division rounded down. The highest level is the `pokemon`
config's `max_level` (100; Studio's `settings_config.json`,
`pokemonMaxLevel`).

**A Godot project made from a Studio project** reads no Studio file: the
Studio layer's `import_data.gd` writes the project's moves, abilities and
natures as the game's resources, each text a key (`move.<id>.name`,
`move.<id>.description`, `move.<id>.contest_description`,
`ability.<id>.name`…; empty when Studio's line says nothing) whose words in
each language go into `locale/data.csv`, and its highest level as
`config/pokemon.json` unless the game has one:

```bash
godot --headless --path <game> -s res://addons/wildgrass/studio/import_data.gd -- <Studio Data folder>
```

## The trainer

`Wildgrass.trainer`, as the reference's: a boy's and a girl's identity, the
one played (`girl`) giving `name` and `id`. At a new game the boy's id is
drawn below 2^30 (`0x3FFFFFFF`), the girl's is it `xor 0x28F4AB4C`; the
names are the engine's words `wg.trainer.boy` and `wg.trainer.girl`, in
the language shown. `shown_id()` is `id % 100000`. Kept by the save. The
`{player}` placeholder says `name`.

## A Pokémon: `WgPokemon`

A `Resource`: a game writes one in the inspector (a gift, a trainer's
team) or has one made; the save keeps the party's as data.

**Made** by `Wildgrass.pokemon.make(species, level, options)`, as the
reference does, in its order:

1. A 32-bit `code`, drawn below `0xFFFFFFFF`, again up to 3 times with
   the shiny charm in the bag, until shiny: shiny when its low 16 bits are
   below 16 (1 in 4096). `shiny: true` or `false` forces it, by setting
   those bits to 0 or `0xFFFF`.
2. Level: at least 1.
3. Form: given, else the species' own rule (Unown: `code % 28`; Meowstic:
   1 if female, decided once its gender is; the others 0), a form the
   species does not have giving 0. Experience: its level's.
4. Caught: with a Poké Ball (or the `ball` given), now (`caught_at`,
   seconds), at its level, in the current zone, by the trainer (each can
   be given); caught by the player when that trainer is the player.
   Gender: given, else female when a draw from 0 to 99 is below the
   species' `female_rate`; a rate of -1 makes it genderless, 0 male and
   100 female, even given.
5. Friendship: given, else the species' base (0 to 255); EVs given, else
   0; IVs given, else drawn from 0 to 31 each; contest conditions given,
   else 0. Nature: the number given (or a nature's id), else the code's
   high 16 bits, modulo the natures' count, then the nature of that
   number. HP full.
6. Moves: those the species learns by level from 0 to its level, the
   highest levels first, each once, until four, then in level order
   (moves of the same level in the order the species lists them; a move
   the game does not have left out, logged); each with its full PP; `moves`
   given replace them from the first.
7. Held item: given, else a draw from 0 to 99 walking down the species'
   chances; none past them.
8. Ability: given, else a draw from 0 to 99: below 49 the species' first,
   below 98 its second, else its third (hidden).

Every draw goes through `Wildgrass.pokemon.draw(from, to)`, on its
`random` (a `RandomNumberGenerator`, which a test or a judge seeds; a span
past 31 bits drawn on 32).

**Stats**, as the reference: HP `((IV + 2 base + EV/4) × level) / 100 +
10 + level` (Shedinja 1); the others `(((2 base + EV/4 + IV) × level /
100) + 5) × nature / 100`, each division rounded down.

**Fields**: `species`, `form`, `nickname` (empty: the species' name),
`level`, `experience`, `code`, `nature` (a number), `ivs`, `evs`
(`{hp, attack, defense, speed, special_attack, special_defense}`), `hp`,
`status` (empty, `poison`, `paralysis`, `burn`, `sleep`, `freeze`,
`toxic`) and `status_count`, `friendship`, `ability` and
`ability_index`, `gender` (`NONE`, `MALE`, `FEMALE`), `held_item`,
`moves` (up to four `WgMoveSlot`: `move`, `pp`, `max_pp`),
`learnt_moves` (every move it has known), the catch (`ball`,
`caught_at`, `caught_level`, `caught_in`, `trainer_name`, `trainer_id`,
`caught_by_player`), `steps_left` (an egg until 0), `pokerus`,
`conditions` (`{cool, beautiful, cute, clever, tough, sheen}`),
`ribbons`.

**Bound** to its data (its species' form, its nature, the moves) by
`Wildgrass.pokemon.bind(pokemon)`: done when made, given or restored; a
Pokémon written in the inspector is bound when the engine first takes it.
A word that needs the data on a Pokémon not bound logs it once.

**Words** on it: `is_shiny()`, `is_egg()`, `stat(&"attack")`…,
`max_hp()`, `is_alive()`, `set_hp()` (0 clears the status), `heal()` (HP,
status, PP), `display_name()`, `knows(move)`, `learn(move)` (as when it
grows: the oldest forgotten past four), `forget(move)`, `set_level()`
(within 1 and the level limit; its experience that level's), `cry()`.
The level limit is `Wildgrass.pokemon.level_limit`: the `pokemon`
config's `max_level`, which a game may lower or raise during play (kept
by the save).

**A Godot project made from a Studio project** gets its species and types
too from `import_data.gd`: resources in `pokemon/` and `types/`, their
texts as keys in `locale/data.csv` (`species.<id>.name`,
`species.<id>.form_<n>.name`, `type.<id>.name`…), their pictures copied
into the game's `graphics/` where Studio keeps them (`pokedex/pokefront/`,
`characters/`…) and their cries into `audio/cries/`, a file already there
the same not copied again; then Godot imports them.

## The party: `Wildgrass.party`

Up to six (`party` config's `size`, the reference's 6):
`add(pokemon) -> bool` (false if full), `remove(index)`, `swap(a, b)`,
`at(index)`, `size()`, `is_empty()`, `is_full()`, `alive_count()`,
`heal()`, `has(species)`, `index_of(species)`, `first_alive()`; the signal
`changed`. Kept by the save, each Pokémon as data. The followers
(feature 19) and the Pokédex (feature 13: seen and caught when added) are
told.

## Words for events' scripts (feature 22)

The engine's: `party`, `give_pokemon(species, level, options) -> bool`
(made, added, the Pokédex told), `trainer`.

Studio's: `actors` (`$actors`: `empty()`, `size()`, `[i]` as `actors.at(i)`,
`any(func)`…), `pokemon_party` (`$pokemon_party.heal_party`), `add_pokemon(id,
level, shiny)`, `add_specific_pokemon(pokemon)`, `add_rename_pokemon(pokemon)`
(renaming waits for the naming screen: added, logged), `pokemon_from_hash({…})`
for `PFM::Pokemon.generate_from_hash`, with Studio's keys (`id`, `level`,
`shiny`, `form`, `given_name`, `nature`, `stats`, `bonus`, `item`, `ability`,
`moves`, `gender`, `loyalty`…). The translator writes them by the rules of
feature 22.

## In steps

1. The data: moves, abilities, natures, experience; their Studio sources.
2. The trainer; `WgPokemon`: made, stats, experience, moves, the words on
   it; the sample's species and types imported, with their pictures and
   cries.
3. The party, saved; the engine's and Studio's words; the sample's tower:
   its team choice translated by hand (credit to its authors), the arch's
   guardian then letting the player through.

## Checked

On the sample project, imported: every move, ability and nature, each
field and each text in English and French, against Studio's files, a key
of theirs neither read nor named as left out failing; the experience of
each curve up to five levels past the highest, against the formulas
written apart in Python (`tools/judge/data.py`); every species and type,
each field and text, each picture and cry the same bytes as Studio's and
loading (`species.py`); Pokémon of every species at five levels, with
options and with the shiny charm, each draw written down and what Studio's
rules make of them computed apart (`pokemon.py`); Pokémon made with a seed, their stats and moves against the reference's
formulas ported apart in Python on Studio's data; played headless: the
tower gives a team, the guardian stops a player with none and lets one
with a team pass.

## Tests

Data and Pokémon built by the tests: each formula (stats, experience of
each curve), each draw (shiny rate, charm, nature from the code, IV range,
ability chances, gender rate, genderless, held items), the options winning,
the moves learnt and their order, `learn` past four, `heal`; the party full,
removed, swapped, saved and loaded; each word.
