# Feature 8 — Items and bag

Status: implemented.

What the player carries: items and their data, the bag and its pockets,
money, items given in dialogue and found on maps, the bag screen. Using an
item on a Pokémon waits for Pokémon (feature 12); saving is feature 9's.

## Items

```gdscript
var potion := Wildgrass.items.item(&"potion")   # a WgItem
potion.name                                     # through Wildgrass.texts.format()
```

`WgItem` (`Resource`): `id`, `kind` (items that work alike share one),
`name`, `description`, `plural`, `pocket`, `position` (its
place when a pocket is sorted), `price`, `icon` (`Texture2D`), `consumed`
(used up when used; one that is not is kept once, never tossed, shown
without a count: key items, TMs), `usable` (outside battle), `data` (what a
kind adds). `name_for(count)`: its plural when more than one, if it has one.

- A game registers its own (`Wildgrass.items.register(item)`), or **a Studio
  project's `Data/Studio/items/<id>.json` is read as it is**, the first time
  that item is asked for (no reading of every file, no icon loaded before it
  shows): `dbSymbol` is the id; the kind is its `klass` without `Item`, in
  snake case (`ConstantHealItem` → `constant_heal`, `RepelItem` → `repel`,
  `Item` → none); name, description and plural are
  placeholders of Studio texts `100012`, `100013`, `9001`; `socket` gives the
  pocket; `isLimited` is consumed, `isMapUsable` usable; the icon is
  `graphics/icons/<icon>.png`; the fields of its kind go to `data`. A game's
  item wins.
- An unknown item is logged; an icon missing is reported once.

## Pockets

`bag_config.json`; by default, Studio's pockets in Studio's order:

```json
{
	"pockets": [
		{ "id": "items", "name": "{text:100015:4|Other Items}", "socket": 1 },
		{ "id": "balls", "name": "{text:100015:1|Poké Balls}", "socket": 2 },
		{ "id": "medicine", "name": "{text:100015:0|Medicine}", "socket": 6 },
		{ "id": "tms", "name": "{text:100015:5|TMs}", "socket": 3 },
		{ "id": "key_items", "name": "{text:100015:8|Key Items}", "socket": 5, "reveal": true },
		{ "id": "berries", "name": "{text:100015:3|Berries}", "socket": 4 }
	],
	"maxCount": 99,
	"maxMoney": 999999
}
```

- A game's item names its pocket by id; a Studio item by `socket`. An item
  of a pocket the config does not have is in the bag, in no pocket shown
  (Studio's letters).
- `consumed` decides counts and tossing; `reveal` is the pocket's: giving one
  of its items shows it on the `item_reveal` screen.
- `maxCount` 0: no limit.

## The bag and money

```gdscript
Wildgrass.bag.add(&"potion", 3)       # false if refused: unknown, full
Wildgrass.bag.remove(&"potion")       # false if not enough
Wildgrass.bag.count(&"potion")
Wildgrass.bag.items(&"items")         # ids of a pocket, in the order received
Wildgrass.bag.sort(&"items")          # by position, ties in the order received
Wildgrass.bag.money
Wildgrass.bag.add_money(500)
Wildgrass.bag.spend(200)              # false if not enough
Wildgrass.bag.can_use(&"potion")      # held, usable, with a use
await Wildgrass.bag.use(&"potion")    # false if not used
```

- `add()` refuses what would go past `maxCount`, or past 1 for an item not
  consumed, rather than adding part of it. Money stops at `maxMoney` and 0.
- Signals `changed(id, count)`, `money_changed(money)`.
- Adding records `obtain_item` for quests. Quests' `money` and `item`
  earnings are given here; quests gain a check per kind of earning, and
  `claim()` gives nothing, and stays to claim, while one would not fit.
- Condition terms: `has:potion`, `has:potion*3`, `money:500` (at least).
- `state()`, `restore()`, `reset()`.

## In dialogue

| Tag | When writing reaches it |
|---|---|
| `[give=potion]`, `[give=potion*3]` | puts it in the bag; an item of a `reveal` pocket is shown on the `item_reveal` screen, and writing waits for it; refused, logged |
| `[take=potion]`, `[take=potion*3]` | takes it from the bag; not enough takes nothing, logged |

`[give]` refused (the bag full) is logged, and the message goes on.

**A message holding `[give]` is the game's voice, not the character's**
("You got a Potion!"): it shows no speaker, from its first letter, wherever
the tag stands in it; the next message shows the speaker again. Tags gain
this as an option: `Wildgrass.dialogue.add_tag(&"give", callable, true)`
declares a tag that narrates; a game may declare others.

**An item of a `reveal` pocket** is shown on `item_reveal`, a replaceable
screen (the engine's: its icon in a panel) while the message is written; once
written, the message stays `revealSeconds` (1), then goes on by itself, the
key not hurrying it, and the screen closes. A dialogue closed meanwhile
closes it too. For this, messages gain the option `locked`: once written, the
key does nothing (with `auto`).

Signal `Wildgrass.bag.given(id, count)`, from `[give]`, item balls and quest
earnings: a game plays its jingle (an item, a key item, a berry, a TM). What
the box says ("You got a Potion!") is the game's text.

## Found on a map

`WgItemBall` (`WgInteractable`): `item`, `count`, `text` (`"Found {item}!"`
by default), `full_text` (`"No room for {item}."`), `invisible`.

- A visible one blocks its cell until taken; an invisible one blocks nothing
  and shows nothing. For this, interactables gain `blocks` (feature 4).
- Interacted with: the item goes in the bag, its local flag `taken` is set,
  the text is said, then the ball is freed; the player is not held after.
  The bag full: `full_text`, and the ball stays.
- Taken, it is freed when its map is built, before the tree, neighbours
  included: it carries a `WgShowIf` on `!local:taken`, an internal child
  named by Godot, that the map never saves; a child of the ball may bear any
  name.
- `{item}` is the item's name (its plural when `count` is more than 1),
  `{count}` the count. They are this message's own values: `say()` gains the
  option `values`, a dictionary of placeholders for one message, whose values
  may hold placeholders themselves (a Studio name).

## The bag screen

A replaceable screen, `bag` (`WgBagScreen`), the engine's in Godot's theme:
pockets, the list of the pocket with counts, the icon and description of the
item under the cursor; on an item: Use (if usable and a use is registered),
Toss (a consumed item only; how many, then Yes / No), Cancel.

- Every pocket of the config shows, an empty one included; left and right
  turn them, wrapping; up and down move the cursor, stopping at the ends. Each
  pocket keeps its cursor while the screen is open. A config without pockets
  is logged, and the screen closes.
- The list is the pocket's in the order received; an item not consumed shows
  no count, and a long count widens its column. The screen follows the bag
  while open.
- The choices are asked in the message box ("{item} is selected."); the icon
  and description, which it covers, are hidden meanwhile. Toss asks how many
  only when there are more than one; the number cancelled, nothing more is
  asked. Keys wait while an item is in use; cancel closes the bag.
- Its texts (`selected_text`, the choices, `toss_count_text`,
  `toss_confirm_text`) are the scene's. Arguments of `open()`: `pocket`, the
  pocket shown first (the first); `bag`, `dialogue`, `texts` (the engine's).

- `Wildgrass.dialogue.ask_number(text, {min, max, default})` (feature 4's
  promise): up and down by one, left and right by ten, wrapping; returns the
  number, or `null` when cancelled, closed or cut by a warp.
- `Wildgrass.items.add_use(&"repel", callable)`: what using an item does,
  found by its id, else its kind; it may be a coroutine, awaited; it returns
  false if the item was not used up. Use shows only for an item usable
  outside battle with a use; a consumed item used is removed.
- The pause menu opens it (feature 10), or `Wildgrass.screens.open(&"bag")`.

## Later

- Using an item on a Pokémon, holding one: Pokémon (feature 12).
- Shops (buying, selling at half price): with the towns that have them.
- Registering an item to a key, favourites, sorting by name: with the options
  (feature 10).
- A TM's name with its move's: with moves (feature 12).
- Studio's `settings_config.json` (`maxBagItemCount` and Pokémon settings):
  with Pokémon (feature 12); until then `maxCount`.
- Filling the bag for testing: the debug tools (feature 20).

## Tests

Items, configs, Studio files, maps and screens are built by the tests; time is
advanced by hand and input simulated with Godot's input actions.
Covered: items registered and Studio items read once, on demand, their kind,
texts, pocket, flags, icon and data, a game's winning, unknown items and
missing icons logged once; pockets and limits from the config, no limit at 0;
adding and removing all or nothing, an item not consumed kept once, the order
received, a stable sort, money between 0 and its maximum, gifts announced and
refusals logged, `obtain_item` and quest earnings that would not fit, bag
terms, using an item (a use found by id or kind, a coroutine, not used up, not
usable), the bag through JSON; `[give]` narrating, refused, revealed while
written and closing with its dialogue, `[take]`, the tags keeping no service
alive; what blocks (the cells covered, on its level, never from inside a
walker), balls blocking or not, taken with their plural name, a full bag, gone
on every load with a single gate, children of any name; the bag screen's
pockets, counts and a long one, cursor and details, following the bag, the choices offered, tossing with and without a
number, cancelled, keys waiting for a use, letting go of the bag, the engine's
services, no pocket.
