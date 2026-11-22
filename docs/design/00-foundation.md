# Feature 0 — Foundation

Status: implemented.

Nothing on screen. Gives every other feature a way to be extensible: config,
replaceable screens, hooks, conventional paths, a logger, a game clock.

## Layout

```
addons/wildgrass/          the addon, the only thing a game installs
├── plugin.cfg, plugin.gd  editor plugin: autoload, shader global, path settings
├── wildgrass.gd           the "Wildgrass" autoload
└── core/
    ├── clock/  config/  display/  hooks/  log/  paths/  screens/
tests/                     gdUnit4 tests
tools/                     install_gdunit4.sh, run_tests.sh
```

## Autoload

```gdscript
Wildgrass.paths  .log  .config  .display  .hooks  .clock  .screens
```

- Built in that order; each one statically typed.
- Replace one with a subclass: project setting `wildgrass/services/<name>`
  (e.g. `wildgrass/services/display`). A script that does not extend the
  service is refused.
- `engine_ready` hooks, then the `ready_for_game` signal, run once every
  autoload and the main scene are ready, so they can add hooks first.
- From Kotlin or C#: `getNode("/root/Wildgrass")`, then `call()`.

## Config

One file per system in the `config` folder (paths, `res://config/`): a
resource (`display.tres`, a `WgConfig` edited in the inspector) or JSON
(`display.json`), the resource winning. A game only sets what it changes.

```gdscript
class_name WgDisplayConfig
extends WgConfig

@export var resolution := Vector2i(320, 240)
@export var window_scale := 2
@export var fullscreen := false
```

- A field is an `@export` variable. JSON keys are its own name
  (`window_scale`).
- Read: `bool`, `int` (whole numbers only), `float`, `String`, `StringName`,
  `Vector2`, `Vector2i` (`{"x", "y"}`), `Color` (`"#rrggbb"`), typed arrays and
  dictionaries, enums by name, sub-configs (an exported `WgConfig` with a
  default instance).
- Missing key: default kept. Unknown key, wrong type, wrong element: logged,
  value kept. `_validate()` then resets impossible values; its messages name
  the field (`window_scale must be at least 1`).

```gdscript
Wildgrass.config.register(&"display", WgDisplayConfig, "display")
var display := Wildgrass.config.get_config(&"display") as WgDisplayConfig
Wildgrass.config.add_source(&"display", func() -> Dictionary: return {"window_scale": 3})
```

- Loaded once, on first access. Unknown name: `null`, logged.
- Order: the defaults, then what sources give (a plugin reading another
  tool's files, as the Studio layer, feature 10 bis), then the project's own
  file, field by field. `is_given(name)`: a file or a source gives values.
- A game extends an engine config by registering a subclass under the same
  name. A script that does not extend the registered one is refused.

## Display

The `display` config is applied at start **only if it is given** (a file or
a source).
Then:

- window = resolution × window scale, or fullscreen;
- the game works in game pixels but is drawn at window size (`canvas_items`):
  a `Node2D` at x = 10.25 lands on screen pixel 41, so movement stays smooth
  at any refresh rate. Controls stay snapped to game pixels;
- aspect ratio kept, height filled, bars on the sides; nearest filtering.

## Screens

```gdscript
Wildgrass.screens.register(&"bag", "res://addons/wildgrass/bag/bag.tscn")
var bag := Wildgrass.screens.open(&"bag", {"pocket": &"items"})
if bag and not bag.is_closed():
	await bag.closed
```

- Scene used, first match wins: `set_scene()` during play, project setting
  `wildgrass/screens/<name>`, the registered default.
- `open()` returns `null`, logged, if the name is unknown, the scene missing,
  or its root not a `WgScreen`.
- `WgScreen`: override `_on_open(args)`, `_on_close()`, `_on_input(event)`;
  call `close()`; signal `closed`, emitted once. A screen freed or removed
  without `close()` still closes. One that closes in `_on_open` comes back
  closed and is not announced.
- Screens stack. Only the top one gets `_on_input`, mouse and focus.
- `took_input()`: true in the frame a screen handled an input event, even if
  it closed since; the game does not act on that press too.
- Signals `screen_opened(name, screen)`, `screen_closed(name)`.

## Hooks

Signals notify. Hooks let others take part, in order, and be replaced by name.

```gdscript
Wildgrass.hooks.add(&"new_game", &"bag", _init_bag)         # priority 0
Wildgrass.hooks.add(&"new_game", &"bag", _my_bag)           # replaces it, same place
Wildgrass.hooks.remove(&"new_game", &"bag")
Wildgrass.hooks.run(&"new_game", [state])
var rate := Wildgrass.hooks.filter(&"encounter_rate", 10, [map])
```

- Order: priority (lowest first), then first insertion.
- Changes made while running apply from the next run.
- A handler whose object was freed is dropped.
- Foundation hook: `engine_ready`.

## Paths

| Key | Default |
|---|---|
| `config` | `res://config/` |
| `graphics` | `res://graphics/` |
| `audio` | `res://audio/` |
| `maps` | `res://maps/` (feature 1) |
| `saves` | `user://` (feature 9) |
| `items`, `quests` | `res://items/`, `res://quests/` (features 8, 7) |
| `pokemon`, `types` | `res://pokemon/`, `res://types/` (feature 12) |
| `dex` | `res://dex/` (feature 13) |
| `encounters` | `res://encounters/` (feature 14) |
| `data`, `studio` | `res://Data/`, `res://`: the Studio layer's (feature 10 bis) |

- Settings `wildgrass/paths/<key>`; a game can add keys.
- `resolve(key, relative)`, `exists(path)`.
- `report_missing(path, requester)`: logged once per path. A missing asset is
  never an error.
- `user_file(name)`: player files; `test_` prefix when launched with
  `-- --test`.

## Log

```gdscript
Wildgrass.log.info(&"screens", "Opening bag")
```

- Levels `debug`, `info`, `warn`, `error`; each message has a channel.
- Minimum level, globally and per channel: `config/log.json`
  (`{"level": "info", "channels": {"screens": "debug"}}`).
- Signal `logged(level, channel, message)`.

## Clock

- `seconds`: game time, from frame deltas. Stops while the tree is paused.
- `speed`: `Engine.time_scale`, so movement and timers stay in step. Never
  negative.
- Shader global `game_time`, declared by the plugin (or at start if missing).

## Tests

- No asset needed: tests write their JSON files and scenes to `user://` and
  delete them.
- gdUnit4 is not committed: `tools/install_gdunit4.sh` downloads a pinned,
  checksummed version.
- `tools/run_tests.sh` never hangs on a script error, and does not import
  while an editor is open on the project.
