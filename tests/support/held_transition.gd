## A transition that stays covering the screen until `release`.
extends WgTransition

signal release


func uncover() -> void:
	await release
