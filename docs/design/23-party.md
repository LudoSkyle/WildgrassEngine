# Feature 23 — Pokémon and the party

Status: step 1 (the data) done; steps 2 and 3 to come.

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

`Wildgrass.trainer`: the player's `name` and `id` (a number drawn at a new
game, 0 to 65535, kept by the save). A Pokémon remembers the trainer who
caught it; one caught by the player counts as such.

## A Pokémon: `WgPokemon`

A `Resource`: a game writes one in the inspector (a gift, a trainer's
team) or makes one in code; the save keeps the party's as data.

**Made** by `WgPokemon.generate(species, level, options)`, as the
reference does, in its order:

1. A 32-bit `code`, drawn again up to 3 times with the bag's shiny charm,
   until shiny: shiny when its low 16 bits are below 16 (1 in 4096);
   `shiny` and `no_shiny` force it.
2. Level clamped from 1 to `max_level`.
3. Form (given, else the species' first); experience: its level's.
4. Caught: with a Poké Ball (or the ball given), at that time, its level,
   in the zone shown, by the trainer; gender: given, else female by the
   species' rate (genderless: none).
5. Friendship: the species' base; EVs 0; IVs drawn 0 to 31 each; nature:
   given, else the `code`'s high 16 bits modulo the natures' count; HP full.
6. Moves: those learnt by level up to its level, the last four, in the
   order learnt; PP full.
7. Held item: given, else drawn by the species' chances.
8. Ability: given, else the species' first (49 in 100), second (49), or
   hidden (2).

Every one of them can be given instead (`options`), as the reference's.

**Stats**, as the reference: HP `((IV + 2 base + EV/4) × level) / 100 +
level + 10` (Shedinja 1); the others `(((2 base + EV/4 + IV) × level / 100)
+ 5) × nature / 100`, floored at each step.

**Fields**: `species`, `form`, `nickname` (empty: the species' name),
`level`, `experience`, `code`, `nature`, `ivs`, `evs`, `hp`, `status`
(none, poison, paralysis, burn, sleep, freeze, toxic) and its count,
`friendship`, `ability`, `gender`, `held_item`, `moves` (up to four
`WgMoveSlot`: `move`, `pp`, `pp_ups`), the moves it knew
(`learnt_moves`), the catch (`ball`, `caught_at`, `caught_level`,
`caught_in`, `trainer_name`, `trainer_id`), egg fields (`is_egg`,
`steps_left`), and the reference's others kept as they are (Pokérus,
contest conditions, ribbons) for the features to come.

**Words** on it: `is_shiny()`, `stat(&"attack")`…, `max_hp()`, `is_alive()`,
`heal()` (HP, status, PP), `display_name()`, `learn(move)` (the oldest
forgotten past four), `forget(move)`, `knows(move)`, `set_level()` (its
experience follows), `cry()`.

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
2. The trainer; `WgPokemon`: made, stats, experience, moves, the words on it.
3. The party, saved; the engine's and Studio's words; the sample's tower:
   its team choice translated by hand (credit to its authors), the arch's
   guardian then letting the player through.

## Checked

On the sample project, imported: every move, ability and nature, each
field and each text in English and French, against Studio's files, a key
of theirs neither read nor named as left out failing; the experience of
each curve up to five levels past the highest, against the formulas
written apart in Python (`tools/judge/data.py`); Pokémon made with a seed, their stats and moves against the reference's
formulas ported apart in Python on Studio's data; played headless: the
tower gives a team, the guardian stops a player with none and lets one
with a team pass.

## Tests

Data and Pokémon built by the tests: each formula (stats, experience of
each curve), each draw (shiny rate, charm, nature from the code, IV range,
ability chances, gender rate, genderless, held items), the options winning,
the moves learnt and their order, `learn` past four, `heal`; the party full,
removed, swapped, saved and loaded; each word.
