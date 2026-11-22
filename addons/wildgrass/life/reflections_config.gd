## The `reflections` config: how a walker's reflection in water looks.
class_name WgReflectionsConfig
extends WgConfig

## Multiplies the reflection: paler and bluer than the walker.
@export var tint := Color(0.6, 0.8, 1.0, 0.45)
## How far the reflection rises back towards the feet, in pixels: the bottom
## rows of a character's picture are usually empty, and the mirror doubles
## the gap.
@export var lift := 5.0
