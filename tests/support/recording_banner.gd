## A game's banner: records the styles it is asked to draw.
extends WgLocationBanner

var styles: Array[StringName] = []


func _show_style(banner_style: StringName) -> void:
	styles.append(banner_style)
