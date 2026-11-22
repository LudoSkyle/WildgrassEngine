## A light that comes on as night falls and goes out as it leaves: its energy
## is `brightness` times the moment's light (`Wildgrass.daytime`). Without a
## texture, the engine gives it a soft round glow, made in code.
class_name WgNightLight
extends PointLight2D

const Daytime := preload("res://addons/wildgrass/daytime/daytime.gd")

## Its energy at full night.
@export var brightness := 1.0
## How much its energy wavers: a flame; 0: steady.
@export var flicker := 0.08
## How much its reach wavers with it.
@export var reach := 0.04
## The glow's radius, in pixels, when the engine makes it.
@export var radius := 64

## The day and night it follows; the engine's if not set.
var daytime: Daytime

var _time := 0.0
var _phase := 0.0


func _ready() -> void:
	if texture == null:
		texture = glow(radius)
	_phase = fmod(global_position.x * 0.37 + global_position.y * 0.61, TAU)
	if daytime == null:
		var engine := get_node_or_null(^"/root/Wildgrass")
		daytime = engine.get(&"daytime") if engine != null else null
	advance(0.0)


func _process(delta: float) -> void:
	advance(delta)


## Moves it on by `delta` seconds: its energy follows the night, wavering.
func advance(delta: float) -> void:
	_time += delta
	var night := daytime.map_light() if daytime != null else 0.0
	var wave := sin(_time * 2.3 + _phase) * 0.6 + sin(_time * 3.7 + _phase * 1.7) * 0.4
	energy = brightness * night * (1.0 + flicker * wave)
	texture_scale = 1.0 + reach * wave
	enabled = energy > 0.0


## A round glow of `size` pixels' radius, from half strength at its heart to
## nothing at its edge.
static func glow(size: int) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.5))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var made := GradientTexture2D.new()
	made.gradient = gradient
	made.fill = GradientTexture2D.FILL_RADIAL
	made.fill_from = Vector2(0.5, 0.5)
	made.fill_to = Vector2(1.0, 0.5)
	made.width = size * 2
	made.height = size * 2
	return made
