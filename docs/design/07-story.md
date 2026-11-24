# Feature 7 — Story

Status: implemented.

Where the player is in the story: named flags and values, conditions written
on what a map holds, what characters say as the story moves on, who is on a
map, and quests. Saving it all is feature 9's.

## Story state

```gdscript
Wildgrass.story.set_flag(&"bell_told")
Wildgrass.story.has(&"bell_told")             # true
Wildgrass.story.clear_flag(&"bell_told")
Wildgrass.story.set_value(&"badges", 3)
Wildgrass.story.value(&"badges")              # 3; unset: 0
```

- Flags and values are named, apart: a flag and a value may share a name. A
  value is a number or a text.
- Signal `changed(name)`, after any change; `restored` once after `restore()`
  or `reset()`.
- **Local flags** belong to one thing on one map, as a found item or a
  trainer beaten: `Wildgrass.story.local(node, &"taken")` names the flag of
  `node`, from the id of the node's own map and its path in it, to set and
  read like any other.
- `state()` gives everything as a dictionary that JSON can hold,
  `restore(state)` puts it back, `reset()` empties it: feature 9 saves and
  loads with them.
- In a text, `{flag:name?yes|no}` reads a flag, `{value:name}` a value (0
  when unset, as a variable is).
- A value set shows in texts as `{name}` (feature 5's placeholders), unless
  the game set a text value of that name; an unset one stays as written.
- Studio and RPG Maker number their switches and variables; an importer names
  them `switch_12` and `variable_12`, and local switches `A` to `D`.

## Conditions

A condition is a text, written in the inspector:

| Term | True when |
|---|---|
| `bell_told` | the flag is set |
| `!bell_hung` | the flag is not set |
| `badges >= 3` | the value compares so (`=`, `!=`, `<`, `<=`, `>`, `>=`) |
| `local:taken` | the local flag of the thing the condition is on |
| `time:night` | the moment of the day (feature 16) |

`!` denies any term. Terms joined by `,` must all hold; an empty condition is
true. `Wildgrass.story.check("bell_told, !bell_hung", node)`: `node` is what
`local:` refers to. The filter hook `story_term(result, term, node)` reads
terms a game adds (`has:potion`, feature 8); a term nobody reads is false,
logged once.

## Who is on a map

`WgShowIf` (`Node`), a child of anything on a map, with `condition`: when the
map loads, before it enters the tree, its parent is freed if the condition
does not hold. A character, a sign, a guarded passage that is not there
neither holds a cell, nor blocks, nor speaks; neighbours loaded in the
background too.

It is decided when the map loads: a flag set meanwhile shows at the next
visit, or after `Wildgrass.maps.reload()`. (Imported events change page the
moment a switch changes; a live mode may come later without changing this
node.)

## What is said

`WgTalk` and `WgSign` gain `states`: entries `condition => text`. The last
whose condition holds is said, else `text`; the list is in the order of the
story. Chosen each time the player talks (`current_text()`, which a guarded
passage says too).

`ask`, a question before speaking: `Question?` for `text`, or
`condition => Question?` for one state. Yes says the text; No or cancel says
nothing.

Tags for messages (feature 4):

| Tag | When writing reaches it |
|---|---|
| `[flag=name]` | sets the flag |
| `[unflag=name]` | clears it |
| `[reload]` | reloads the map once the dialogue is closed; dropped if a warp closes it |

A translation that loses a game tag of its source (`[flag=…]`) would change
the story in that language only: the dialogue logs it as an error.

## Quests

A quest is a list of objectives and of earnings:

```gdscript
Wildgrass.quests.start(&"bell")
Wildgrass.quests.complete(&"bell", 0)          # objective 0 done
Wildgrass.quests.record(&"obtain_item", &"potion", 1)   # counts for every quest
Wildgrass.quests.is_finished(&"bell")
Wildgrass.quests.claim(&"bell")                # its earnings, once
Wildgrass.quests.forget(&"bell")               # as never started; signal forgotten
Wildgrass.quests.ids()                         # every quest known
```

- **Defined** as a `WgQuest` resource the game registers
  (`Wildgrass.quests.register(quest)`), else found in `res://quests/*.tres`
  (paths, `quests`), else given by a source
  (`Wildgrass.quests.add_source(callable)`, returning an array of quests);
  named by its `id`, with `name`, `description`, `primary`, objectives and
  earnings. **A Studio project's `Data/Studio/quests/*.json` come from the
  Studio layer's source** (feature 10 bis) into the same resources: `id` is
  its `dbSymbol`, `primary` its `isPrimary`, its name and description the
  placeholders `{text:100045:<id>}` and `{text:100046:<id>}`, shown through
  `Wildgrass.texts.format()` so that they follow the language; an objective's
  kind is its method name without `objective_` (`speak_to`,
  `catch_pokemon`…), its target and amount taken from its arguments as each
  kind writes them, its arguments kept whole for the game's quest book.
- An objective has a `kind`, a `target`, an `amount` (1) and may start
  hidden. **Recorded by hand**: `complete()`, `add(quest, index, amount)`
  (Studio's `speak_to`, `beat_npc`, `custom`). **Recorded by events**:
  `record(kind, target, amount)` counts toward every active quest's visible
  objectives of that kind and target; the bag, battles and eggs call it in
  their features (`obtain_item`, `see_pokemon`, `beat_pokemon`,
  `catch_pokemon`, `obtain_egg`, `hatch_egg`). The filter hook
  `quest_match(matches, objective, target)` matches targets that are more than
  a name (a Pokémon of a type and level).
- What happens before `start()` does not count. A hidden objective counts
  for nothing, by hand or by event, until `reveal(quest, index)` (logged when
  completed by hand); a quest needs all its objectives, hidden ones included.
- **States**: active, finished, failed. `start()` refuses a quest unknown,
  active or finished; a failed one starts again, from nothing. It finishes
  **the moment** its last objective is done. `fail()` fails an active quest.
- **Earnings** (`kind`, `args`) are given by `claim()`, once, through
  `Wildgrass.quests.add_earning(&"money", callable)`: the bag adds money and
  items (feature 8), Pokémon data adds Pokémon and eggs. A kind nobody gives is
  logged, and the others given.
- Signals `started`, `objective_done(quest, index)`, `finished`, `failed`:
  a game shows its banner and its quest book from them.
- Condition terms: `quest:bell` (finished), `quest_active:bell`,
  `quest_failed:bell`.
- `state()`, `restore()`, `reset()`, as the story state. A quest the game
  registers under a Studio quest's id wins; a file that is not a quest, an
  unknown objective kind, an unknown quest or objective are logged.

## Studio projects, as they really are

Read from a real Studio project, things feature 5 missed were fixed, now in
the Studio layer (feature 10 bis): every JSON file of a Studio project has a
`"klass"` key, which the layer ignores; a Studio text not translated holds
`[~ 0]`, `[~ 1]`…, read as an empty cell, so the fallback applies; past the
fallback locale, the first column that has a text is said rather than
nothing.

## Later

- Found items (a flag per find, an item given): with the bag, feature 8.
- Badges: with trainers. Flags set at a given time: with day and night,
  feature 16.

## Tests

Maps, flags, characters and quests are built by the tests.
Covered: flags and their signal, values apart from flags and refused types,
local flags on a map shown as a neighbour; every kind of term, `!`, `,`,
`local:`, game terms and unknown ones; the state through JSON, `restored`;
values in texts; what does not show freed before the tree, on a reload, by a
local flag, on a neighbour loaded in the background; states and their order, a
state without its arrow, a sign's states and its local flag, questions for the
text or for one state, No; `[flag]`, `[unflag]`, `[reload]` and a warp
dropping it; a guarded passage's current text; translations losing tags; the
story's tags keeping no service alive; quests finishing at once, what counts
before start and while hidden, starting and restarting, earnings once and a
kind nobody gives, matched and empty targets, quest terms, progress through
JSON, wrong calls, quests registered, in the quests folder or from a source.
Studio quest files: feature 10 bis.
