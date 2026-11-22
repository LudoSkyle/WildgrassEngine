## The debug tools as in a build that may not be a debug one.
extends "res://addons/wildgrass/debug/debug.gd"

var debug_build := true


func _is_debug_build() -> bool:
	return debug_build
