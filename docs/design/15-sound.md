# Feature 15 — Sound

Status: implemented.

What the game sounds like: the music of each place, crossfaded, an ambience
under it, jingles that pause the music, sound effects over it, Pokémon
cries, the sounds the engine plays itself (a menu, a bump, a door, a save),
and their volumes in the options. The engine ships no sound: every one is
the game's file, or silence.

## Sounds

```gdscript
Wildgrass.audio.play_music(&"new_bark_town")     # crossfaded over the config's fade_seconds
Wildgrass.audio.play_ambience(&"rain")
await Wildgrass.audio.jingle(&"key_item")        # the music pauses, then goes on where it was
Wildgrass.audio.effect(&"bump")
Wildgrass.audio.cry(&"pikachu")                  # its form's cry (feature 12)
Wildgrass.audio.play(&"confirm")                 # a named sound of the config
```

| Kind | Folder | Plays |
|---|---|---|
| music | `music/` | looping; a new one crossfades with the old one |
| ambience | `ambience/` | looping, under the music, crossfaded |
| jingle | `jingles/` | pauses the music, which goes on where it was once it ends |
| effect | `effects/` | over everything, several at once |
| cry | the species' (feature 12) | one at a time; `force` cuts the one playing |

- A sound is its file's name without the extension, in its kind's folder of
  paths `audio` (`res://audio/`), in the formats Godot plays (OGG, WAV,
  MP3); or a path, `audio/se/select.wav`. A missing one is reported once,
  and silence.
- **Music**: asking for the music already playing changes nothing; coming
  back to the one fading out brings it back up where it was; a third one
  during a crossfade cuts the one leaving. `stop_music()` fades it out.
  `music` is the one asked for.
- **Jingles**: `jingle()` returns when it ends. A jingle cuts a crossfade
  short: the music leaving stops, the other waits paused. Music asked for
  during a jingle starts once it ends. Signal `jingle_finished(name)`.
- Each kind plays on its own audio bus, `Music`, `Effects` (effects and
  jingles), `Cries`, under `Master`; the engine adds those a game's bus
  layout lacks.

## Named sounds

The `audio` config's `sounds`: a role and what it plays, `{kind, name,
volume, pitch}` (volume and pitch in percent, 100). The engine plays these
roles itself; an empty name is silence, as all of them are by default:

| Role | Kind | When |
|---|---|---|
| `cursor` | effect | a screen takes a direction (signal `input_taken` of the screens) |
| `confirm`, `cancel` | effect | a screen takes confirm, cancel; a message goes on |
| `menu` | effect | the pause menu opens |
| `bump` | effect | the player walks into something, again every `bump_seconds` while it goes on |
| `jump` | effect | a ledge's jump starts |
| `door` | effect | a door is used (signal `door_used` of the maps) |
| `save` | jingle | the game is written |
| `item`, `key_item` | jingle | a message gives an item; `key_item` for a pocket that reveals |

A game adds its own roles and plays them with `play(role)`.

## Places

`WgMap` gains `music` and `ambience` (names; empty: silence). A warp, a
reload or crossing into a linked map plays them; two maps with the same
music keep it going. The title plays the `title` config's `music` (feature
11), crossfaded into the first map's.

## In messages

- `[jingle=name]` plays a jingle; the message does not go on before it ends,
  the key still finishing writing it (`Wildgrass.dialogue.hold_until()`).
  An item given waits for its jingle the same way.
- `[sound=name]` plays an effect.

## Volumes

Three options (feature 10), kept on the player's machine, 0 to 100 by 5,
each the volume of its bus: `music_volume` (Music), `effects_volume`
(Effects), `cries_volume` (Cries). `volume` (Master) stays. The `options`
config's default order becomes `message_speed`, `message_frame`,
`music_volume`, `effects_volume`, `cries_volume`, `language`.

## The `audio` config

`config/audio.json`:

| Field | Default | |
|---|---|---|
| `fade_seconds` | 1.0 | a crossfade |
| `bump_seconds` | 0.3 | how often walking into something sounds while it goes on |
| `folders` | `{music: "music", ambience: "ambience", jingles: "jingles", effects: "effects"}` | inside paths `audio` |
| `buses` | `{music: "Music", effects: "Effects", cries: "Cries"}` | |
| `sounds` | every role above, silent | the named sounds |

## A Studio project

| Studio | Engine |
|---|---|
| `audio/bgm`, `bgs`, `me`, `se` | `folders`: `bgm`, `bgs`, `me`, `se` |
| `sound_design_config`: `soundEffects` (`decision`, `cancel`, `cursor`, `bump`, `jump`, `save`…), `musicEffects` (`receiveItem`, `receiveKeyItem`…), `name`, `volume`, `pitch` | `sounds`, each file's path in the project: `decision` → `confirm`, `cancel`, `cursor`, `bump`, `jump`, `save` (an effect in Studio), `receiveItem` → `item`, `receiveKeyItem` → `key_item`; every other one kept under its own name, in snake case (`battle_start`, `level_up`); one without a file left out |
| `backgroundMusic` (`surf`, bikes, battles…) | roles of kind music, in snake case, for their features |
| `scene_title_config`: `bgmName` | the `title` config's `music` |
| the `volume` option | `volume` (Master) |
| `.mid` files | not played by Godot: reported once, silence |

A map's music, in Studio's RPG Maker data: with the map importer.

## Pokémon Mirage, step by step

| In Pokémon Mirage | In the engine |
|---|---|
| `assets/audio/music`, `jingles`, `sfx`, `cries/<id>` | the `audio` config's `folders`; cries from the species |
| `metadata/music` on a map; the same music kept between maps | `WgMap.music` |
| a one-second fade in, a crossfade, back to the music leaving where it was, a third change cutting the one leaving | the same, `fade_seconds` 1 |
| the title's music, faded into the first map's | the `title` config's `music` |
| jingles pausing the music, the message waiting for them (`@sound:`), the next place's music after one | `jingle()`, `[jingle=…]` |
| `key_item`, `item`, `healed`, `bell`, `save` | roles `key_item`, `item`, `save`; `healed`, `bell` in messages |
| `cursor`, `confirm`, `cancel`, `menu`, `bump` at the pace of steps, `jump`, `door`, `door_exit` | the same roles; `door_exit` a game's role |
| `cry(species, volume, force)`, one at a time | `cry()` |
| three volumes: music, cries, other sounds | `music_volume`, `cries_volume`, `effects_volume` |
| silent tests | the tests' headless audio |

## Later

- Loop points (Studio's `bgmDuration`, a game's own): with an importer of
  loops; Godot's loop settings on the files meanwhile.
- Battle music and the bike's, surfing's: with their features, from the
  roles.
- A map's music from Studio's maps: with the map importer.

## Tests

Sounds are silent WAV files the tests write; crossfades are advanced by
hand, the audio driver headless.
Covered: the buses added and played on; music crossfading, the same one
going on, the one leaving coming back where it was, a third cutting it,
stopping, looping; ambience apart; names, paths inside a folder and full
paths, the folders of the config; a missing sound reported once, MIDI
refused once; a jingle pausing the music and letting it go on, music asked
meanwhile starting after, a jingle cutting a crossfade short, a jingle cut
by another; effects on free voices;
a cry one at a time unless forced, none without one; named sounds by kind
with their volume and pitch, silent roles; the config keeping the engine's
roles; the three volumes on their buses and the default order. Each map's
music and ambience, two maps keeping one, silence; the title's music into
the first map's; crossing into a linked map. The screens' keys, the menu,
a door, a save, an item given and the message waiting for its jingle, the
tags, bumping again while it goes on and not after, a jump. Studio's sound
design and title music.
