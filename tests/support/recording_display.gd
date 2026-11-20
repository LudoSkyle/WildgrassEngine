## A game's display service that records what the engine asks it to apply.
extends "res://addons/wildgrass/core/display/display.gd"

var applied: Array[WgDisplayConfig] = []


func apply(config: WgDisplayConfig, _window: Window) -> void:
	applied.append(config)
