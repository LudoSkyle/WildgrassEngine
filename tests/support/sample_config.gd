## Every kind of field a config can have.
extends WgConfig

enum Mode { SLOW, FAST_FORWARD }

const SampleSub := preload("res://tests/support/sample_sub_config.gd")

@export var count := 1
@export var ratio := 0.5
@export var enabled := false
@export var title := "default"
@export var id := &"default"
@export var size := Vector2i(1, 1)
@export var offset := Vector2(0.5, 0.5)
@export var tint := Color.WHITE
@export var tags: Array[String] = ["a"]
@export var weights: Array[int] = [1]
@export var labels: Dictionary[String, int] = {}
@export var mode := Mode.SLOW
@export var layer_2_name := ""
@export var sub: SampleSub = SampleSub.new()

## Not exported: internal state, never read from JSON.
var internal := 0
