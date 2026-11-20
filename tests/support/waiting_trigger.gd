## A trigger that lasts until `release` is emitted, and counts its runs.
extends WgTrigger

signal release

var runs := 0


func _triggered(_walker: WgWalker) -> void:
	runs += 1
	await release
