## A Pokémon flying over the map: living scenery, with no body, nothing to
## bump into or talk to. Its picture is its species' `character` sheet (four
## rows, down, left, right, up, of four columns), drawn `lift` pixels above
## a shadow; over water one sees oneself in (tile data `reflects`), the
## shadow takes the water's colour.
##
## It flies legs of one to three cells in a straight line within its `zone`,
## never turning back unless cornered, hovering between legs. With `drift`,
## the wind carries it across its zone instead, and back in from the other
## side; flyers sharing a `seed` keep their gap, a flock.
class_name WgFlyer
extends Node2D

const _TileReader := preload("res://addons/wildgrass/life/tile_reader.gd")

const DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const MAX_STRIDE := 3
const BEATS_PER_SECOND := 5.0
const CRY_RETRY := 1.0
## Carried by the wind: how far past the zone it goes before coming back
## from the other side, in cells.
const EDGE := 1.5
## Its pace varies by a quarter, its way waves a cell around its row, its
## picture bobs two pixels.
const GUST_SWING := 0.25
const GUST_BEAT := 0.5
const LANE_SWING := 1.0
const LANE_BEAT := 0.3
const BOB := 2.0
const BOB_BEAT := 2.2

## Its species, and the form.
@export var species: StringName = &""
@export var form := 0
## How high its picture is drawn above its shadow, in pixels.
@export var lift := 14.0
## The cells it keeps within: top left corner and size.
@export var zone := Rect2i(0, 0, 10, 10)
## Cells per second.
@export var pace := 2.5
## Seconds it hovers between legs: at least, at most.
@export var rest := Vector2(0.3, 1.6)
## The seed of its flight; 0: chance.
@export var seed := 0
## Seconds between cries: at least, at most; (0, 0): silent.
@export var cry_every := Vector2(10.0, 24.0)
## It cries only within this many cells of the player.
@export var cry_range := 4.0
## Its cry's volume, 0 to 1.
@export var cry_volume := 0.45
## The wind carrying it: 1 east, -1 west; 0: it flies by itself.
@export var drift := 0
## Its shadow's colour on land and over water.
@export var shadow_land := Color(0.0, 0.0, 0.0, 0.26)
@export var shadow_water := Color(0.0, 0.33, 0.4, 0.33)
## Where its shadow lies below its origin, in pixels.
@export var shadow_offset := 6.0

## The engine, or what stands for it: its `species`, `audio`, `dialogue`,
## `maps` and `tiles`. The autoload's unless set before entering the tree.
var wildgrass: Object
## The way of the leg under way or the last one.
var heading := Vector2i.DOWN
## The cells of the leg under way or the last one.
var stride := 0
## True while it flies a leg.
var gliding := false

var sprite: Sprite2D
var shadow: Polygon2D

var _random := RandomNumberGenerator.new()
## Its own chance, never seeded: its bob and its cries, apart from its flock.
var _own := RandomNumberGenerator.new()
var _target := Vector2.ZERO
var _wait := 0.0
var _clock := 0.0
var _cry_wait := 0.0
var _lane := 0.0
var _gust := 0.0
var _bob := 0.0


func _ready() -> void:
	if wildgrass == null:
		wildgrass = get_node_or_null(^"/root/Wildgrass")
	sprite = get_node_or_null(^"Sprite") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite"
		add_child(sprite)
	sprite.position = Vector2(0.0, -lift)
	sprite.region_enabled = true
	shadow = get_node_or_null(^"Shadow") as Polygon2D
	if shadow == null:
		shadow = Polygon2D.new()
		shadow.name = "Shadow"
		shadow.polygon = PackedVector2Array([Vector2(-7, 0), Vector2(-5, -2), Vector2(0, -3), Vector2(5, -2), Vector2(7, 0), Vector2(5, 2), Vector2(0, 3), Vector2(-5, 2)])
		add_child(shadow)
		move_child(shadow, 0)
	shadow.position = Vector2(0.0, shadow_offset)
	var found: WgSpeciesForm = wildgrass.species.form(species, form) if wildgrass != null else null
	sprite.texture = found.picture(&"character") if found != null else null
	if seed != 0:
		_random.seed = seed
	else:
		_random.randomize()
	_own.randomize()
	# Each starts at its own time, or every flyer of the map would move as one.
	_wait = _random.randf() * rest.y
	_clock = _random.randf()
	_cry_wait = _next_cry() * _own.randf()
	if drift != 0:
		heading = Vector2i(clampi(drift, -1, 1), 0)
		_lane = position.y
		# The wind comes from the seed, the same for the flock; the bob is its own.
		_gust = _random.randf() * 100.0
		_bob = _own.randf() * 100.0
	_flap()


func _process(delta: float) -> void:
	advance(delta)


## Flies on by `delta` seconds.
func advance(delta: float) -> void:
	_clock += delta
	_flap()
	_shade()
	_call(delta)
	if drift != 0:
		_float(delta)
		return
	if gliding:
		position = position.move_toward(_target, delta * _grid() * pace)
		if position.distance_to(_target) < 0.01:
			position = _target
			gliding = false
			_wait = rest.x + _random.randf() * maxf(rest.y - rest.x, 0.0)
		return
	_wait -= delta
	if _wait <= 0.0:
		_launch()


## The next leg: a way that is not turning back, one to three cells, cut
## short at the zone's edge. Cornered, it goes back the way it came.
func _launch() -> void:
	var cell := Vector2i((position / _grid()).floor())
	var back := -heading
	var ways: Array[Vector2i] = DIRECTIONS.filter(func(way: Vector2i) -> bool: return way != back)
	for index in range(ways.size() - 1, 0, -1):
		var other := _random.randi_range(0, index)
		var kept := ways[index]
		ways[index] = ways[other]
		ways[other] = kept
	ways.append(back)
	for way in ways:
		var wanted := _random.randi_range(1, MAX_STRIDE)
		var steps := 0
		while steps < wanted and zone.has_point(cell + way * (steps + 1)):
			steps += 1
		if steps == 0:
			continue
		heading = way
		stride = steps
		_target = position + Vector2(way * steps) * _grid()
		gliding = true
		return
	# A zone of one cell: it hovers.
	_wait = rest.y


## Carried by the wind: on without stopping, faster or slower with the gust,
## its way waving; out of one side of its zone, back in from the other.
func _float(delta: float) -> void:
	_gust += delta
	var speed := pace * (1.0 + GUST_SWING * sin(_gust * GUST_BEAT))
	var x := position.x + heading.x * speed * _grid() * delta
	var left := (zone.position.x - EDGE) * _grid()
	var right := (zone.end.x + EDGE) * _grid()
	if heading.x > 0 and x > right:
		x -= right - left
	if heading.x < 0 and x < left:
		x += right - left
	position = Vector2(x, _lane + LANE_SWING * _grid() * sin(_gust * LANE_BEAT))
	sprite.position = Vector2(0.0, -lift + BOB * sin((_clock + _bob) * BOB_BEAT))


## Its cry now and then, over the player, never during a message; out of
## reach or with another crying, it tries again a second later.
func _call(delta: float) -> void:
	if cry_every.y <= 0.0 or wildgrass == null:
		return
	_cry_wait -= delta
	if _cry_wait > 0.0:
		return
	var player: Node2D = wildgrass.maps.traveller
	var near := player != null and player.is_inside_tree() and global_position.distance_to(player.global_position) <= cry_range * _grid()
	if near and not wildgrass.dialogue.is_open() and wildgrass.audio.cry(species, form, cry_volume):
		_cry_wait = _next_cry()
	else:
		_cry_wait = CRY_RETRY


func _next_cry() -> float:
	return cry_every.x + _own.randf() * maxf(cry_every.y - cry_every.x, 0.0)


## Its picture now: the row of its way, and its wings beating, columns 0 and
## 2 (in the air it does not hop).
func _flap() -> void:
	if sprite.texture == null:
		return
	var beat := int(_clock * BEATS_PER_SECOND) % 2
	var row := 0
	match heading:
		Vector2i.LEFT:
			row = 1
		Vector2i.RIGHT:
			row = 2
		Vector2i.UP:
			row = 3
	var size := sprite.texture.get_size() / 4.0
	sprite.region_rect = Rect2(beat * 2 * size.x, row * size.y, size.x, size.y)


## The shadow's colour: the water's over a tile that `reflects`.
func _shade() -> void:
	var node: Node = get_parent()
	while node != null and not node is WgMap:
		node = node.get_parent()
	var under := global_position + Vector2(0.0, shadow_offset + 1.0)
	var water: bool = node != null and _TileReader.top_data(node, under, "reflects", false) == true
	shadow.color = shadow_water if water else shadow_land


func _grid() -> float:
	return float(wildgrass.tiles.tile_size()) if wildgrass != null else 16.0
