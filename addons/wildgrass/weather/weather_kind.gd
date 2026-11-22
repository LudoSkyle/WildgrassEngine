## A weather: what falls and how, what drifts over the map, and the tone it
## gives the screen. Its pictures are the game's.
class_name WgWeather
extends Resource

@export var id: StringName = &""
## A label, shown through `Wildgrass.texts.label()`.
@export var name := ""
## `none`, `rain`, `hail`, `sandstorm`, `sun`, `fog`: what battles will read.
@export var category: StringName = &"none"

@export_group("Particles")
## The pictures that fall; a particle's picture follows its rank.
@export var particles: Array[Texture2D] = []
## Pixels per second, along which they fall: the slope of their pictures.
@export var particle_velocity := Vector2.ZERO
@export var particle_count := 60
## A splash's pictures; with them, a share of the particles are splashes.
@export var splashes: Array[Texture2D] = []
## The share of particles that are splashes: 0.5, every second one.
@export var splash_share := 0.5
## Snow: each fall wavers, faster low on the view, a step aside.
@export var floating := false

@export_group("Layer")
## A picture tiled over the map, drifting.
@export var layer: Texture2D
@export var layer_velocity := Vector2.ZERO

@export_group("Tone")
## Added to the screen, each channel from -1 to 1.
@export var tone := Vector3.ZERO
## The colour taken from the screen first, 0 to 1.
@export var gray := 0.0
## How far the tone's strength beats over `pulse_seconds`, each way.
@export var pulse := 0.0
@export var pulse_seconds := 0.8
## The tone fades as night falls: the sun's.
@export var sunlight := false


## True if particle `rank` is a splash.
func is_splash(rank: int) -> bool:
	if splashes.is_empty() or splash_share <= 0.0:
		return false
	var period := maxi(roundi(1.0 / splash_share), 1)
	return rank % period == period - 1


## The picture of particle `rank`, or null.
func picture(rank: int) -> Texture2D:
	if is_splash(rank):
		return splashes[rank % splashes.size()]
	return particles[rank % particles.size()] if not particles.is_empty() else null
