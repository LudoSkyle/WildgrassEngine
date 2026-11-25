## An event (feature 21): a walker with pages. It shows the last page whose
## condition holds, chosen again whenever the story changes; no page: it is
## not there, it neither blocks nor starts. Put it in a map's `Entities`.
class_name WgEvent
extends WgWalker

## Its number on the map: what commands and conditions name.
@export var event_id := 0
@export var pages: Array[WgEventPage] = []
## Blocks and is bumped into, even with nothing to show.
@export var invisible_blocker := false

## The page shown, or null.
var page: WgEventPage
## Erased by a command: no page until its map is built again.
var erased := false
## Started, waiting for the events service to run it.
var starting := false
## The column of its sheet it shows at rest: its page's, or a route's.
var pattern := 0

var _locked := false
var _before_lock := Vector2i.ZERO
## The direction of the page shown last: a new page turns the event only
## when its own direction differs.
var _page_direction := Vector2i.ZERO
## The sheet it shows: its page's, or a route's.
var _sheet: Texture2D


func _ready() -> void:
	super()
	apply_page(page)


## Shows `shown` (or nothing): its look, its way of blocking. Called by the
## events service when the page changes.
func apply_page(shown: WgEventPage) -> void:
	page = shown
	starting = false
	walk_animation = shown == null or shown.walk_animation
	always_stepping = shown != null and shown.step_animation
	fixed_direction = shown != null and shown.fixed_direction
	passes_walls = shown != null and shown.through
	on_top = shown != null and shown.always_on_top
	var sprite_node := get_node_or_null(sprite)
	if sprite_node is CanvasItem:
		(sprite_node as CanvasItem).modulate.a = shown.opacity if shown != null else 1.0
	if shown != null and shown.direction != _page_direction:
		_page_direction = shown.direction
		facing = shown.direction
	show_graphic(shown.sheet if shown != null else null, facing, shown.pattern if shown != null else 0)


## Shows `sheet` (none: nothing), facing `direction`, column `pattern` at
## rest; it blocks when it shows one and is not through.
func show_graphic(sheet: Texture2D, direction: Vector2i, column: int) -> void:
	_sheet = sheet
	pattern = column
	facing = direction
	var sprite_node := get_node_or_null(sprite)
	if sprite_node is WgCharacterSprite:
		(sprite_node as WgCharacterSprite).sheet = sheet
	if sprite_node is CanvasItem:
		(sprite_node as CanvasItem).visible = page != null and sheet != null
	through = page == null or passes_walls or (sheet == null and not invisible_blocker)
	if is_inside_tree() and walkers != null:
		_animate()


## True while it runs a list the player started.
func is_locked() -> bool:
	return _locked


## True when the player starts it by stepping onto its cell, false when by
## bumping into it.
func is_stepped_on() -> bool:
	if page == null:
		return false
	if invisible_blocker or (_sheet != null and not passes_walls):
		return false
	return walkers == null or not walkers.tiles.is_solid(cell, level)


## Faces the player while it runs, as it was started by the player.
func lock(player: Node2D) -> void:
	if _locked:
		return
	_before_lock = facing
	_locked = true
	if player is WgWalker:
		var offset := (player as WgWalker).cell - cell
		if offset != Vector2i.ZERO:
			turn(Vector2i(signi(offset.x), 0) if absi(offset.x) >= absi(offset.y) else Vector2i(0, signi(offset.y)))


func unlock() -> void:
	if not _locked:
		return
	_locked = false
	if _before_lock != Vector2i.ZERO:
		turn(_before_lock)


func _animate() -> void:
	super()
	if page == null or pattern == 0 or is_moving or always_stepping or _sprite == null or _sprite.sprite_frames == null:
		return
	var walk := "walk_" + DIRECTION_NAMES[facing]
	if _sprite.sprite_frames.has_animation(walk) and pattern < _sprite.sprite_frames.get_frame_count(walk):
		_sprite.animation = walk
		_sprite.frame = pattern
		_sprite.pause()
