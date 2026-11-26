## The experience curves: how much experience a Pokémon has at a level, by
## its species' `growth_rate`.
class_name WgExperience
extends RefCounted

## The curves, by number (a species form's `growth_rate`); any other number counts as `NORMAL`.
enum Growth { FAST, NORMAL, SLOW, PARABOLIC, ERRATIC, FLUCTUATING }

@warning_ignore_start("integer_division")


## The experience a Pokémon of `curve` has on reaching `level`.
static func total(curve: int, level: int) -> int:
	var cube := level * level * level
	match curve:
		Growth.FAST:
			return 4 * cube / 5
		Growth.SLOW:
			return 5 * cube / 4
		Growth.PARABOLIC:
			return 1 if level <= 1 else 6 * cube / 5 - 15 * level * level + 100 * level - 140
		Growth.ERRATIC:
			return _erratic(level, cube)
		Growth.FLUCTUATING:
			if level <= 15:
				return cube * (24 + (level + 1) / 3) / 50
			if level <= 35:
				return cube * (14 + level) / 50
			return cube * (32 + level / 2) / 50
	return cube


static func _erratic(level: int, cube: int) -> int:
	if level <= 50:
		return cube * (100 - level) / 50
	if level <= 68:
		return cube * (150 - level) / 100
	if level <= 98:
		return cube * ((1911 - 10 * level) / 3) / 500
	if level <= 100:
		return cube * (160 - level) / 100
	return int(600000 + 103364 * (level - 100) + cos(level) * 30000)
