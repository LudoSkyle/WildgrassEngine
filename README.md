# Wildgrass Engine

Godot 4 engine for Pokémon fan games. Reads Pokémon Studio data.
GDScript only, ships no assets.

## Status

In development: the foundation, maps and doors, linked maps, tiles, walking.

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

## License

[CC BY-NC-SA 4.0](LICENSE): non-commercial use only.

Not affiliated with Nintendo, Creatures Inc., GAME FREAK inc., The Pokémon
Company or Pokémon Workshop.
