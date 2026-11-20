# Wildgrass Engine

Godot 4 engine for Pokémon fan games. Reads Pokémon Studio data.
GDScript only, ships no assets.

## Status

In development: only the foundation exists.

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

## License

[CC BY-NC-SA 4.0](LICENSE): non-commercial use only.

Not affiliated with Nintendo, Creatures Inc., GAME FREAK inc., The Pokémon
Company or Pokémon Workshop.
