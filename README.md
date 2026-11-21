# Wildgrass Engine

Godot 4 engine for Pokémon fan games. Reads Pokémon Studio data.
GDScript only, ships no assets.

## Status

In development: the foundation, maps and doors, linked maps, tiles, walking,
dialogue, texts, characters, story, bag, save, menu and options.

## Install

1. Copy `addons/wildgrass/` into your project.
2. Enable **Wildgrass Engine** in *Project Settings → Plugins*.

## Usage

Everything goes through the `Wildgrass` autoload.

**Configs** are JSON files in `Data/configs/`. Only set what you change.

`display_config.json` (without it, the window is left as your project sets it):

```json
{ "resolution": { "x": 320, "y": 240 }, "windowScale": 4, "fullscreen": false }
```

`log_config.json`:

```json
{ "level": "info", "channels": { "screens": "debug" } }
```

**Folders** default to `res://Data/`, `res://graphics/` and `res://audio/`.
Change them in *Project Settings → wildgrass/paths*.

**Hooks**:

```gdscript
Wildgrass.hooks.add(&"engine_ready", &"my_game", _on_engine_ready)
```

**Game time**: `Wildgrass.clock.seconds` in code, the `game_time` global in
shaders.

**Maps** are scenes in `res://maps/`, named by id (`town.tscn` → `town`). Their
root is a `WgMap`, with an `Entities` node for the player. Add `WgSpawnPoint`
and `WgDoor` nodes anywhere in them.

```gdscript
Wildgrass.maps.traveller = player
await Wildgrass.maps.go_to(&"town", &"Spawn")
await Wildgrass.maps.use(door)
```

`map_config.json`: `{ "tileSize": 16, "fadeSeconds": 0.25 }`.

**Linked maps** show against each other's sides and are walked into with no
transition. On each `WgMap`, set `size` (in tiles) and add a `WgMapLink` per
side: the other map, its side and its offset. Each map links back to the
other. Give ground layers a negative `z_index`, or a neighbour's ground hides
the player at the seam. After each step of the player:

```gdscript
Wildgrass.maps.cross()
```

**Tiles**: draw collisions as physics polygons in the TileSet editor, on
physics layer 1 (layer 4 for edges between two cells: cliff tops, fences).
Add custom data layers for what the ground is (`sand`, `water`…).

```gdscript
var cell := Wildgrass.tiles.cell_of(player.global_position)
var free := Wildgrass.tiles.can_step(cell, Vector2i.DOWN)
var sandy: Variant = Wildgrass.tiles.data(cell, &"sand")
```

**Walking**: make the player a scene whose root is a `WgWalker`, with an
`AnimatedSprite2D` named `Sprite` (animations `idle_down`, `walk_left`,
`run_up`…), a `WgCamera` and a `WgPlayerInput`. Make it the traveller; it
walks, runs, jumps ledges, slides on ice, takes doors and crosses linked maps
by itself. Add a `run` action to the input map. Paces and actions:
`movement_config.json`.

```gdscript
Wildgrass.maps.traveller = player
await Wildgrass.maps.go_to(&"town", &"Spawn")
```

**Dialogue**: messages are written letter by letter in a box, page by page,
with Godot's BBCode. Questions return the index of the choice taken.

```gdscript
await Wildgrass.dialogue.say("Hello!", {"speaker": "Alix"})
var choice := await Wildgrass.dialogue.ask("Which one?", ["Bulbasaur", "Charmander"])
var saving := await Wildgrass.dialogue.confirm("Save the game?")
```

The player talks to what it faces with `ui_accept`: put a `WgSign` on a map,
or a `WgInteractable` with your own `_interact()`. A `message` custom data
layer makes a tile say its text (bookshelves); a `counter` one reaches across
it. To restyle the box, inherit `addons/wildgrass/dialogue/message_box.tscn`
and set *wildgrass/screens/message_box* to your scene; a sign's frame is the
`MessageFrame_sign` theme type variation. Paces and actions:
`dialogue_config.json`.

**Texts**: translate your game as any Godot project (`.po` or `.csv` in
*Project Settings → Localization*). Studio's text files in
`Data/Text/Dialogs/` are read as data; the plugin keeps Godot from importing
them as translations.

```gdscript
Wildgrass.texts.language = "fr"
var name := Wildgrass.texts.studio(100000, 25)   # file, line: "Pikachu"
Wildgrass.texts.set_value(&"player", "Ludo")
await Wildgrass.dialogue.say("Welcome, {player}! Press {key:ui_accept}.")
```

`language_config.json` (Studio's): `defaultLanguage`,
`choosableLanguageCode`, `choosableLanguageTexts`.

**Characters**: a scene whose root is a `WgWalker`, with a
`WgCharacterSprite` (a 4 × 4 character sheet), a controller (`WgWander` in an
area or on tiles carrying some data, `WgPatrol` along a route) and a `WgTalk`
for what it says. Put a `WgRoadblock` beside a guard to keep a passage
closed, or your own `WgTrigger` on cells that react when the player steps on
them. Move characters in scenes:

```gdscript
await Wildgrass.walkers.walk(guard, [Vector2i.LEFT, Vector2i.UP])
await Wildgrass.walkers.walk_to(guard, Vector2i(12, 7))
```

**Story**: flags and values, and conditions written in the inspector
(`bell_told, !bell_hung, badges >= 3, local:taken`). A `WgShowIf` child keeps
its parent off a map unless its condition holds; `states` on `WgTalk` and
`WgSign` (`condition => text`) and `ask` make what is said follow the story;
messages set flags with `[flag=name]`.

```gdscript
Wildgrass.story.set_flag(&"bell_told")
Wildgrass.quests.start(&"bell")
Wildgrass.quests.complete(&"bell", 0)
```

Quests are `WgQuest` resources you register, or a Studio project's
`Data/Studio/quests/*.json`, read as they are.

**Bag**: items are `WgItem` resources you register, or a Studio project's
`Data/Studio/items/*.json`, read when first asked for. Pockets and limits:
`bag_config.json`. Messages give and take with `[give=potion*3]` and
`[take=potion]`; a `WgItemBall` lays an item on a map. The `bag` screen lists
the pockets, and uses and tosses items.

```gdscript
Wildgrass.bag.add(&"potion", 3)
Wildgrass.items.add_use(&"repel", _repel)   # what using it does
Wildgrass.screens.open(&"bag")
```

**Save**: games are JSON files in slots, as Studio's `save_config.json`
sets them. The story, quests, the bag, the play time and where everyone
stands are saved; add your own parts. The `save` screen asks before writing,
`save_slots` chooses a game.

```gdscript
Wildgrass.save.add_part(&"pokedex", _state, _restore, _reset)
Wildgrass.save.write()
await Wildgrass.save.load_game(1)
Wildgrass.screens.open(&"save_slots")
```

**Menu and options**: the `menu` action (Escape by default) opens the pause
menu: Bag, Options, Save, Exit; add your entries, each shown while its story
condition holds. Options (text speed, message frame, volume, language, and
yours) are kept on the player's machine, in the order of Studio's
`game_options_config.json`. Labels are Studio's texts, with English
fallbacks: `{text:100014:2|Bag}`.

```gdscript
Wildgrass.menu.add_entry(&"pokedex", "Pokédex", _open_dex, "has_dex", &"bag")
Wildgrass.options.add_option(&"auto_run", {"values": [false, true], "default": false, "apply": _set_auto_run})
```

## License

[CC BY-NC-SA 4.0](LICENSE): non-commercial use only.

Not affiliated with Nintendo, Creatures Inc., GAME FREAK inc., The Pokémon
Company or Pokémon Workshop.
