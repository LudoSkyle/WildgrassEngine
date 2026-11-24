# Wildgrass Engine

Godot 4 engine for Pokémon fan games. Runs Pokémon Studio projects too.
GDScript only, ships no assets.

## Status

In development: the foundation, maps and doors, linked maps, tiles, walking,
dialogue, texts, characters, story, bag, save, menu and options, the Studio
layer, the title screen, Pokémon species and types, the Pokédex, wild
encounters, sound, day and night, weather, life on the maps, followers, and
the debug tools.

## Install

1. Copy `addons/wildgrass/` into your project.
2. Enable **Wildgrass Engine** in *Project Settings → Plugins*.

## Usage

Everything goes through the `Wildgrass` autoload.

**Configs** are files in `res://config/`, one per name: a resource
(`display.tres`, a `WgConfig` edited in the inspector) or JSON
(`display.json`), the resource winning. Keys are the fields' names. Only set
what you change.

`config/display.json` (without it: 320 × 240 game pixels, window twice as
large, unless your project set its window in Godot's settings, which then
stand):

```json
{ "resolution": { "x": 320, "y": 240 }, "window_scale": 4, "fullscreen": false }
```

`config/log.json`:

```json
{ "level": "info", "channels": { "screens": "debug" } }
```

**Folders** default to `res://config/`, `res://graphics/`, `res://audio/`,
`res://maps/`, `res://items/`, `res://quests/`, `res://pokemon/`,
`res://types/`, `res://dex/` and `res://encounters/`. Change them in *Project
Settings → wildgrass/paths*.

**Studio projects**: a project with a `project.studio` file runs as it is.
The Studio layer (`Wildgrass.studio`) reads its configs, texts, items, pockets
and quests from `Data/` and gives them to the engine; a file of your own in
`res://config/` wins field by field. Setting *wildgrass/studio/enabled*:
`auto`, `on`, `off`. Its maps are imported once into Godot scenes, tiles,
passages and tags as Studio reads them, with their links and music
([feature 10 ter](docs/design/10c-studio-maps.md)):

```bash
godot --headless --path <game> -s res://addons/wildgrass/studio/import_maps.gd -- <Studio Data folder>
```

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

`config/map.json`: `{ "tile_size": 16, "fade_seconds": 0.25 }`.

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
`config/movement.json`.

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
`config/dialogue.json`.

**Texts**: translate your game as any Godot project (`.po` or `.csv` in
*Project Settings → Localization*). The engine writes none of its own
words: each is a key (`wg.menu.bag`) your translations give, the same way
([the keys](docs/design/05b-text-keys.md)); the sample project gives them all. In a Studio project, the Studio layer reads
`Data/Text/Dialogs/` as data (the plugin keeps Godot from importing them as
translations) and shows most keys in Studio's words.

```gdscript
Wildgrass.texts.language = "fr"
var bag := Wildgrass.texts.label("wg.menu.bag")
Wildgrass.texts.set_value(&"player", "Ludo")
await Wildgrass.dialogue.say("Welcome, {player}! Press {key:ui_accept}.")
```

`config/language.json`: `default`, `choosable`, `names`.

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

Quests are `WgQuest` resources you register or put in `res://quests/`; a
Studio project's come from the Studio layer.

**Bag**: items are `WgItem` resources you register or put in
`res://items/<id>.tres`, read when first asked for; a Studio project's come
from the Studio layer. Pockets and limits: `config/bag.json`. Messages give and take with `[give=potion*3]` and
`[take=potion]`; a `WgItemBall` lays an item on a map. The `bag` screen lists
the pockets, and uses and tosses items.

```gdscript
Wildgrass.bag.add(&"potion", 3)
Wildgrass.items.add_use(&"repel", _repel)   # what using it does
Wildgrass.screens.open(&"bag")
```

**Save**: games are JSON files in slots (`user://saves/game-1.json`), as
`config/save.json` sets them (`slots`, `file`, `save_anywhere`). The story, quests, the bag, the play time and where everyone
stands are saved, with who follows; add your own parts. The `save` screen asks before writing,
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
yours) are kept on the player's machine, shown in the order of
`config/options.json`.

```gdscript
Wildgrass.menu.add_entry(&"pokedex", "Pokédex", _open_dex, "has_dex", &"bag")
Wildgrass.options.add_option(&"auto_run", {"values": [false, true], "default": false, "apply": _set_auto_run})
```

**Title**: splashes, the language at first launch, the title screen and
its choices (Play, Options, Quit, and yours), a new game on the start map,
a game continued, back to the title. `config/title.json`:

```json
{ "show_at_start": true, "start_map": "bedroom", "splashes": ["res://graphics/titles/studio.png"] }
```

```gdscript
Wildgrass.maps.traveller = player              # before a new game
Wildgrass.title.add_choice(&"credits", "Credits", _roll_credits)
Wildgrass.menu.add_entry(&"title", "Back to title", Wildgrass.title.back)
```

Your own title is a scene extending `WgTitleScreen` (*wildgrass/screens/title*);
your choice of a game one extending `WgSaveSlotsScreen`.

**Species and types**: `WgSpecies` resources (a national number, texts, and
`WgSpeciesForm`s: types, stats, breeding, abilities, evolutions, moves,
pictures, cry) you register or put in `res://pokemon/<id>.tres`; `WgType`
resources in `res://types/`. The engine ships none; a Studio project's come
from the Studio layer.

```gdscript
var form := Wildgrass.species.form(&"rattata", 1)
form.picture(&"front", true)                        # shiny, a Texture2D
Wildgrass.types.factor(&"fire", form.types)         # how hard fire hits it
```

**Pokédex**: what is seen and caught, form by form, saved with the game;
Pokédexes (`WgDex`, a region's species in order) in `res://dex/`, the
national one made by the engine; the `pokedex` screen from the pause menu.
`config/pokedex.json` sets the Pokédexes of a new game.

```gdscript
Wildgrass.pokedex.see(&"rattata", 1)
Wildgrass.pokedex.catch(&"pikachu")
Wildgrass.pokedex.add_dex(&"national")
```

**Wild encounters**: tile data `encounter` (`grass`…) marks where Pokémon
live; a map's `WgEncounters` node gives its chance per step walked and run,
and its `WgEncounterTable`s (species, levels, weights). A wild Pokémon is
seen in the Pokédex; the engine says it appeared until battles come.

```gdscript
Wildgrass.encounters.start = _start_battle       # what follows a wild Pokémon
Wildgrass.hooks.add(&"wild_encounter", &"repel", _repel)
```

**Sound**: music and ambience crossfaded (a map's `music`, `ambience`, or
the ones playing kept; the title's `music`), jingles that pause the music, effects, cries; files in
`res://audio/music`, `jingles`, `effects`, `ambience`. `config/audio.json`
names the sounds the engine plays (`confirm`, `bump`, `door`, `save`…),
silent by default. Messages play `[jingle=…]` and `[sound=…]`. Three
volumes in the options: music, effects, cries.

```gdscript
Wildgrass.audio.play_music(&"route_1")
await Wildgrass.audio.jingle(&"key_item")
Wildgrass.audio.cry(&"pikachu")
```

**Day and night**: the hour is the player's clock, or the game's own
(`config/daytime.json`); moments (night, dawn, day, dusk by default) tint
the maps marked `outside`, times their `shade`; `WgNightLight` comes on at
night; `time:night` in a story condition; the shader globals `day_tint`
and `night_light` for a game's shaders.

```gdscript
Wildgrass.daytime.moment()         # &"dusk"
Wildgrass.daytime.forced_hour = 23.0
```

**Weather**: `WgWeather` resources in `res://weather/` with the game's
pictures (what falls, a drifting layer, the screen's tone), drawn over the
maps outside: the one on (`Wildgrass.weather.current`), or a map's own
(`weather`). Particles live and die on their own, anchored to the map.

```gdscript
Wildgrass.weather.current = &"rain"
```

**Life on the maps**, from tile data: tall grass hiding legs and rustling
(`front_source`, `rustle`), footprints in sand (`footprints`), walkers'
reflections in water (`reflects`). `WgFlyer`, a Pokémon flying over the
map with its shadow; `WgTwinkle` on anything that shines. `WgZone`
resources in `res://zones/` name the places: arriving in another, the
`location_banner` slides down.

**Followers**: the player's Pokémon walks behind it, replaying its steps one
behind, and anyone else in line before it: a scene whose root is a
`WgFollower`. Hidden on arrival, they unfold as the player walks. The
Pokémon shows its species' `character` sheet; set
*wildgrass/followers/pokemon_scene* to draw it your way.

```gdscript
Wildgrass.followers.follow_pokemon(&"wingull")
Wildgrass.followers.add(friend)
Wildgrass.followers.enabled = false
```

**Debug tools**: in debug builds, the pause menu's Debug entry opens the
engine's tools (fill the bag, quests, hour, weather, the species view, fill
the Pokédex, speed, warp, walk through walls…) and the game's own, apart.
`config/debug.json`: `enabled` (`"auto"`, true, false), `hours`, `speeds`.

```gdscript
Wildgrass.debug.add_tool(&"rod", "Give the rod", _give_rod)   # in Game
Wildgrass.debug.add_page(&"bell", "Bell quest", {"lines": _bell_lines})
```

## License

[CC BY-NC-SA 4.0](LICENSE): non-commercial use only.

Not affiliated with Nintendo, Creatures Inc., GAME FREAK inc., The Pokémon
Company or Pokémon Workshop.
