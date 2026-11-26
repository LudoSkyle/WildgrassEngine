# The keys of the engine's words

The engine writes none of its words (feature 5): each is a key, and the game
gives its text in each language, in its translations (`.po` or `.csv`). This
is every key, with the English the engine's tests use and, in a Studio
project, the line of `Data/Text/Dialogs/` that gives it (feature 10 bis). A
key with no Studio line is the game's to give, in a Studio project too.

A text may hold placeholders, filled when shown: `{item}`, `{count}`,
`{slot}`, `{place}`, `{time}`, `{name}`, `{dex}`, `{seen}`, `{caught}`,
`{height}`, `{weight}`, `{key:action}`, `{player}` (the trainer's name); the debug tools add `{quest}`,
`{moment}`, `{speed}`, `{count}`, `{missing}`.

## Choices

| Key | English | Studio line |
|---|---|---|
| `wg.yes` | Yes | `100011:27` |
| `wg.no` | No | `100011:28` |
| `wg.cancel` | Cancel | `100022:7` |
| `wg.back` | Back | — |

## The trainer

| Key | English | Studio line |
|---|---|---|
| `wg.trainer.boy` | the boy's name at a new game | `9000:2` |
| `wg.trainer.girl` | the girl's name at a new game | `9000:3` |

## Pause menu

| Key | English | Studio line |
|---|---|---|
| `wg.menu.pokedex` | Pokédex | `100014:1` |
| `wg.menu.bag` | Bag | `100014:2` |
| `wg.menu.save` | Save | `100014:4` |
| `wg.menu.options` | Options | `100014:5` |
| `wg.menu.debug` | Debug | — |
| `wg.menu.exit` | Exit | `9000:26` |

## Title

| Key | English | Studio line |
|---|---|---|
| `wg.title.play` | Play | `100032:77` |
| `wg.title.options` | Options | `100014:5` |
| `wg.title.quit` | Quit | `9000:26` |
| `wg.title.prompt` | Press {key:ui_accept} | `100032:113` |

## Options

| Key | English | Studio line |
|---|---|---|
| `wg.options.text_speed` | Text speed | `100042:3` |
| `wg.options.text_speed_help` | Choose how fast messages are written. | `100042:7` |
| `wg.options.slow` | Slow | `100042:4` |
| `wg.options.normal` | Normal | `100042:5` |
| `wg.options.fast` | Fast | `100042:6` |
| `wg.options.message_frame` | Message frame | `9000:165` |
| `wg.options.message_frame_help` | Choose the frame of the message box. | `9000:166` |
| `wg.options.frame_sample` | This is how messages look. | — |
| `wg.options.volume` | Volume | `9000:29` |
| `wg.options.volume_help` | Set the volume of the music and sound effects. | `9000:30` |
| `wg.options.music` | Music | — |
| `wg.options.music_help` | Set the volume of the music. | — |
| `wg.options.effects` | Sound effects | — |
| `wg.options.effects_help` | Set the volume of the sound effects and jingles. | — |
| `wg.options.cries` | Cries | — |
| `wg.options.cries_help` | Set the volume of the Pokémon's cries. | — |
| `wg.options.language` | Language | `9000:167` |
| `wg.options.language_help` | Choose the language of the game. | `9000:168` |

## Saving

| Key | English | Studio line |
|---|---|---|
| `wg.save.question` | Would you like to save the game? | `100026:15` |
| `wg.save.overwrite` | There is already a saved file. Is it OK to overwrite it? | — |
| `wg.save.saved` | The game was saved. | — |
| `wg.save.failed` | The game could not be saved. | `100026:19` |
| `wg.save.which_file` | Save in which file? | — |
| `wg.save.file_choice` | File {slot}: {place}, {time} | — |
| `wg.save.new_file_choice` | File {slot}: new | — |

## Choosing a game

| Key | English | Studio line |
|---|---|---|
| `wg.slots.card` | File {slot}<br>{place}   {time} | — |
| `wg.slots.empty_card` | File {slot}<br>New game | — |
| `wg.slots.damaged_card` | File {slot}<br>This file is damaged. | — |
| `wg.slots.options` | Options | `100014:5` |
| `wg.slots.continue` | Continue | `100025:0` |
| `wg.slots.new_game` | New game | `9000:0` |
| `wg.slots.erase` | Erase | `9000:22` |
| `wg.slots.erase_question` | Erase file {slot}? | — |
| `wg.slots.load_failed` | This file could not be loaded. | — |

## Bag

| Key | English | Studio line |
|---|---|---|
| `wg.bag.selected` | {item} is selected. | — |
| `wg.bag.use` | Use | `100022:0` |
| `wg.bag.toss` | Toss | `100022:1` |
| `wg.bag.toss_count` | Toss how many {item}? | — |
| `wg.bag.toss_confirm` | Throw away {count} {item}? | — |

## Pockets

| Key | English | Studio line |
|---|---|---|
| `wg.pocket.items` | Items | `100015:4` |
| `wg.pocket.medicine` | Medicine | `100015:0` |
| `wg.pocket.balls` | Poké Balls | `100015:1` |
| `wg.pocket.tms` | TMs | `100015:5` |
| `wg.pocket.berries` | Berries | `100015:3` |
| `wg.pocket.key_items` | Key Items | `100015:8` |

## Items on the map

| Key | English | Studio line |
|---|---|---|
| `wg.item.found` | Found {item}! | — |
| `wg.item.no_room` | No room for {item}. | — |

## Pokédex

| Key | English | Studio line |
|---|---|---|
| `wg.pokedex.national` | National Pokédex | `100063:0` |
| `wg.pokedex.header` | {dex}   Seen {seen}   Caught {caught} | — |
| `wg.pokedex.size` | Height {height} m   Weight {weight} kg | — |

## Wild Pokémon

| Key | English | Studio line |
|---|---|---|
| `wg.wild.appeared` | A wild {name} appeared! | — |

## Weather

| Key | English | Studio line |
|---|---|---|
| `wg.weather.clear` | Clear | — |

## Debug tools

Shown only in debug builds, as the rest: the game gives them (the sample
project does).

| Key | English | Studio line |
|---|---|---|
| `wg.debug.title` | Debug | — |
| `wg.debug.engine` | Engine | — |
| `wg.debug.game` | Game | — |
| `wg.debug.fill_bag` | Fill the bag | — |
| `wg.debug.bag_filled` | Test items were added to the bag. | — |
| `wg.debug.empty_bag` | Empty the bag | — |
| `wg.debug.bag_emptied` | The bag was emptied. | — |
| `wg.debug.quests` | Quests | — |
| `wg.debug.quest_start_over` | Start over | — |
| `wg.debug.quest_next` | Next objective | — |
| `wg.debug.quest_finish` | Finish | — |
| `wg.debug.quest_started_over` | {quest}: started over. | — |
| `wg.debug.quest_not_started` | {quest} has not started. | — |
| `wg.debug.quest_already_done` | {quest} is already done. | — |
| `wg.debug.quest_finished` | {quest} is finished. | — |
| `wg.debug.quest_advanced` | {quest}: one objective more. | — |
| `wg.debug.hour_real` | Hour: real | — |
| `wg.debug.hour` | Hour: {moment} | — |
| `wg.debug.moment.dawn` | dawn | — |
| `wg.debug.moment.day` | day | — |
| `wg.debug.moment.dusk` | dusk | — |
| `wg.debug.moment.night` | night | — |
| `wg.debug.weather` | Weather: {name} | — |
| `wg.debug.weather_here` | (this map: {name}) | — |
| `wg.debug.species` | Species | — |
| `wg.debug.fill_pokedex` | Fill the Pokédex | — |
| `wg.debug.pokedex_filled` | The Pokédex was filled. | — |
| `wg.debug.empty_pokedex` | Empty the Pokédex | — |
| `wg.debug.pokedex_emptied` | The Pokédex was emptied. | — |
| `wg.debug.speed` | Speed: x{speed} | — |
| `wg.debug.warp` | Warp | — |
| `wg.debug.reload` | Reload the map | — |
| `wg.debug.walls_on` | Through walls: on | — |
| `wg.debug.walls_off` | Through walls: off | — |
| `wg.debug.encounters_always` | Encounters: always | — |
| `wg.debug.encounters_never` | Encounters: never | — |
| `wg.debug.encounters_chance` | Encounters: chance | — |
| `wg.debug.followers_on` | Followers: on | — |
| `wg.debug.followers_off` | Followers: off | — |
| `wg.debug.save_here` | Save here | — |
| `wg.debug.species_heading` | Species: {count}, {missing} incomplete | — |
| `wg.debug.no_species` | No species. | — |
| `wg.debug.generation` | Generation | — |
| `wg.debug.no_name` | no name | — |
| `wg.debug.no_description` | no description | — |
| `wg.debug.no_picture` | No picture: | — |
