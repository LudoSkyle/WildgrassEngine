# Feature 19 — Followers

Status: implemented.

The Pokémon walking behind the player, and anyone else the story puts in
line behind them: a friend walking along. They walk the player's steps,
one behind; they stop no one and nothing stops them.

## A follower

`WgFollower` extends `WgWalker` (feature 3): a character scene like any
other, its root a `WgFollower` instead of a `WgWalker`.

```gdscript
Wildgrass.followers.follow_pokemon(&"wingull")           # form 0, not shiny
Wildgrass.followers.follow_pokemon(&"vulpix", 1, true, true)   # form, shiny, female
Wildgrass.followers.stop_pokemon()
Wildgrass.followers.pokemon            # the WgFollower showing it, or null
Wildgrass.followers.add(friend)        # a WgFollower scene, after the people already there
Wildgrass.followers.remove(friend)
Wildgrass.followers.line               # Array[WgFollower], the first behind the traveller
Wildgrass.followers.enabled = false    # no one follows; saved
```

Signal `line_changed`.

- **The line**: each follower follows the one before it, the first follows
  the traveller. People first, in the order added; the Pokémon last. One
  joining waits on the traveller's cell, hidden, the others walking on;
  one removed ends its step and shows, not freed; one freed leaves the
  line, which closes up.
- **Which Pokémon**: the one the game names. There is no party yet; when
  there is, a game names its first Pokémon able to fight there.
- **On every map**, unless the filter hook `followers_shown(shown, map)`
  says no: the line waits off that map (a big Pokémon indoors, a gym).
- A follower is `through` (feature 3): it blocks no one and walks into
  anyone; it triggers nothing, opens no door, meets no wild Pokémon.

## How it walks

**It replays its leader's steps, one behind.** When its leader starts a
step, the follower starts the step its leader made before, from the cell
it stands in to the cell its leader is leaving:

- the same kind of step: walking, running, jumping a ledge (two cells, in
  an arc, its shadow shown), sliding on ice (legs still); the same change of
  level;
- **lasting as long as the leader's new step**, so the line moves as one:
  a jump replayed while the leader walks is a quick hop;
- whatever stands there: no tile and no character refuses it, since its
  leader passed;
- in the same frame as its leader, never a frame behind (it is processed
  after it), and it ends with it.

The leader turning in place, bumping or using an exit door does not move
it. At rest, it **faces its leader**.

- **Arriving on a map** (a door, a warp, a loaded game), the line is on the
  traveller's cell, **hidden**; each follower shows on its first step, so
  the line unfolds out of the door.
- **Crossing into a linked map**, the line carries on in step, put in the
  new map with the traveller.
- **Out of place** (its leader put elsewhere by a scene, the follower moved
  by a script): once both stand still and it is neither on its leader's
  cell nor on the cell its leader's last step started from, it goes to its
  leader's cell hidden, on its leader's level, and shows on the next step.
  Behind a ledge just
  jumped, it is in place: it jumps on the next step. While a script walks
  a follower, it replays nothing, even taking over mid-replay; its walk
  over, it is out of place.
- **It never goes with a map**: as a map leaves (a warp, a reload, back to
  the title, a neighbour dropped), the line is taken out of it, and put back
  beside the traveller.
- **Drawn behind its leader** on the same row, and on its leader's level.
- Hidden, it leaves no prints, shows no reflection and rustles no grass;
  shown, it does as any walker (feature 18). `WgWalker` gains `prints` and
  `rustles` (true), beside `reflects`: a walker that leaves no prints, that
  rustles no grass.

## A Pokémon

`follow_pokemon()` makes the line's Pokémon from the scene of the setting
`wildgrass/followers/pokemon_scene` (`Wildgrass.followers.pokemon_scene`):
the engine's unless set, a `WgFollower` with a `WgCharacterSprite`; a scene
whose root is not a `WgFollower` is logged. Its `species`, `form`, `shiny`,
`female` set its sprite's sheet to the form's `character` picture (feature
12): four rows, down, left, right, up, of four columns. A game's scene adds
what it wants (a scale; a shadow always shown, under another name than
`Shadow`, which a walker shows only while jumping); a sprite that is not a
`WgCharacterSprite` is dressed by `_dress(form, shiny, female)`.

- `WgWalker` gains `always_stepping` (false; true for the Pokémon): its walk
  plays all the time, standing too, at the same cadence whatever its pace,
  as Pokémon do on the map; still while it slides.
- The engine's Pokémon walks at 6 frames a second (a drawing a third of a
  second, the little hop is in its sheet), and leaves no prints in sand, as
  following Pokémon never do.
- `WgCharacterSprite` keeps the feet on `foot_line` at any scale (they
  were raised by a scale under 1).
- An unknown species, or one with no `character` picture, is logged and
  nobody follows.

## Talking to it

What a follower says is its scene's: a `WgTalk` or a game's
`WgInteractable` (feature 6), talked to like any character, the player
facing it. The engine's Pokémon says nothing.

## Saved

Part `followers` (feature 9), restored before `map`: `enabled`, the
Pokémon (`species`, `form`, `shiny`, `female`), and the people's scenes, in
order. Where they stand is not, and the `map` part leaves them out: a
loaded game puts them on the traveller's cell, hidden. A person made in
code has no scene: it is not saved, and logged. Back at the title the line
leaves with the traveller; a new game empties it and turns following on.

## A Studio project

| Studio | Engine |
|---|---|
| a species' `character` picture (`graphics/characters`) | the Pokémon's sheet, already read (feature 12) |
| the follower switch and the counts of followers in its variables | with the event importer and the party |

## Pokémon Mirage, step by step

| In Pokémon Mirage | In the engine |
|---|---|
| `Follower`: one Pokémon, a cell behind, on the cell the player leaves, at its pace | the line's Pokémon, replaying the player's steps |
| during the player's jump, a cell at the jump's pace; two cells after it, caught up in the player's next step, gliding | as long as the jump; the two cells as a jump in an arc, in the same time |
| behind a ledge, put back on the player's cell if the player stops | in place: it jumps on the next step |
| no body: the player turning back walks through it | `through` |
| hidden on the player's cell on arrival, shown on the first step | the same |
| put back on the player's cell when the player is put elsewhere | the same, out of place |
| facing the player at rest | the same |
| always animated, same cadence walking or running; still while the player slides | `always_stepping`; still on the steps it slides |
| no prints, no rustle, no reflection (only the player and the characters have them) | Mirage's scene: `prints`, `rustles`, `reflects` off |
| `PokemonFrames`: the species' sheet, 6 frames a second, scaled 0.9, feet at the bottom of the cell; a shadow always shown | Mirage's scene: `WgCharacterSprite`, scale 0.9, its shadow |
| drawn behind the player on the same row | the same |
| `follower_species` of the scene manager | `follow_pokemon()` |

Better than Mirage: a line of several, people too; the jump drawn, and
waited for behind a ledge; the Pokémon saved with the game; the line kept
through a seam; a follower may rustle grass and show its reflection.

## Later

- The party's first Pokémon, fainted ones left out: with the party.
- Surfing, biking, flying: the line hidden or riding along, with them.
- Studio's follower switch and variables: with the event importer.

## Tests

Maps, tiles, sheets, species and followers are built by the tests; steps
are advanced by hand.
Covered: replaying the leader's step one behind, in the same frame and for
as long, even when a frame falls across two steps; running, a ledge jumped
in an arc, a slide with legs still all down the line, a level changed;
through a tile refused and a character, turning back through it; nothing on
a turn, a bump or an exit door; facing the leader at rest; a line of three
unfolding, each drawn over the next and processed after its leader, by the
tree too; one joining while the others walk, one removed mid-step, one
freed; hidden on arrival, shown on the first step, carried over a seam in
step, put back when out of place but not behind a ledge, taking its
leader's level while waiting, waiting while scripted, a script taking over
mid-replay; the line surviving a warp, a reload, the title and a neighbour
dropped, freed with the service once off the map; the filter hook and
`enabled`; leaving the line unfreed; no prints, rustle or reflection while
hidden, nor with `prints`, `rustles` or `reflects` off; the Pokémon's sheet
at the end of the line, leaving no prints, its form, shiny and female
pictures, one taking another's place, a game's scene, `_dress`, a wrong
scene, an unknown species and a missing picture leaving nobody;
`always_stepping`, its jump kept; feet at any scale; talked to through a
`WgTalk`; the part saved, put back hidden, disabled, and reset, a person
made in code and a lost scene logged, the followers left out of the `map`
part, the part before `map`.
