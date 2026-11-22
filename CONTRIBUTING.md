# Contributing

## Principles

- **English only**: code, comments, docs, commits.
- **No assets**: code and texture-free scenes only. No images, sounds, fonts
  or tilesets.
- **Godot first**: maps, TileSets and scenes are made in Godot's own editor
  and work as they are. Pokémon Studio support is added on top, never instead.
- **Pokémon Studio formats** for game data.
- **Extensible**: configs, replaceable screens, hooks, conventional paths
  (see `docs/design/00-foundation.md`).

## Features

One feature at a time:

1. Write its design in `docs/design/`, get it approved.
2. Implement it in `addons/wildgrass/`.
3. Test it.
4. Update the README if it changes how the engine is used.

## Code

- Statically typed GDScript. Untyped declarations are errors.
- Classes prefixed with `Wg`. A `class_name` only for types a game extends or
  declares; everything else is reached through `Wildgrass` and `preload`.
- A preloaded script's constant starts with `_` (`const _Maps := preload(…)`):
  Godot lets a game's global class of the same name win over it in types, so
  a game's `class_name Weather` would break the engine.
- Never a class name Godot already uses.
- One class per file, `snake_case` file names.
- Signals in the past tense, methods in the imperative.

## Tests

- One test, one behaviour, named after what it guarantees.
- No duplicates: check that no other test already covers it.
- No obsolete tests: when behaviour changes, fix or delete them.
- Cover edge cases: empty, missing, wrong type, duplicates, order, limits,
  replacement by a game.
- Only useful tests: each one must be able to fail on a real regression.
- Every claim in a design doc has a test, or leaves the doc.

Run them:

```bash
tools/install_gdunit4.sh
GODOT=/path/to/godot tools/run_tests.sh
```

## Docs

- Short, clear, straight to the point. No filler.
- The README is the user guide until a docs site exists: install and usage
  only.

## Git

- Work on `develop`; one branch and one commit per pull request.
- Commit titles: `type(scope): imperative message` (`feat`, `fix`,
  `refactor`, `docs`, `test`, `chore`).
