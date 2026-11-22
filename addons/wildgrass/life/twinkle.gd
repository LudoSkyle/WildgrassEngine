## A twinkle, put on any drawing (a sprite, a polygon): it swells and pales
## by turns, a beat of `period` seconds with a slower one under it, so that
## something shining gets noticed. It changes only its size and opacity,
## around those of the scene.
class_name WgTwinkle
extends Node2D

## One beat, in seconds.
@export var period := 1.1
## How much it swells and shrinks around its size: 0.35, from 65 % to 135 %.
@export var swell := 0.35
## Its opacity at its palest, 0 to 1.
@export var dim := 0.35

var _clock := 0.0
var _rest := Vector2.ONE
var _tint := Color.WHITE


func _ready() -> void:
	_rest = scale
	_tint = modulate


func _process(delta: float) -> void:
	advance(delta)


## Twinkles on by `delta` seconds.
func advance(delta: float) -> void:
	_clock += delta
	# A beat, and a second one over three times slower: never twice the same.
	var beat := 0.5 + 0.5 * sin(TAU * _clock / period)
	var slow := 0.5 + 0.5 * sin(TAU * _clock / (period * 3.3))
	var glow := clampf(0.7 * beat + 0.3 * slow, 0.0, 1.0)
	scale = _rest * (1.0 - swell + 2.0 * swell * glow)
	modulate = Color(_tint.r, _tint.g, _tint.b, _tint.a * (dim + (1.0 - dim) * glow))
