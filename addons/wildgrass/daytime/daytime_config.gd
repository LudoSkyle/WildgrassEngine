## The `daytime` config: where the hour comes from, and the moments of the
## day with their tint and light.
class_name WgDaytimeConfig
extends WgConfig

## `real`: the player's clock; `game`: an hour of the game's own.
@export_enum("real", "game") var source := "real"
## Where a new game's own hour starts.
@export var start_hour := 12.0
## Game minutes for each second of the game clock.
@export var minutes_per_second := 1.0
## moment -> `{tint, light}`: a colour (or "#rrggbb", or [r, g, b]) and the
## strength of lights at night, 0 to 1.
@export var moments: Dictionary[String, Dictionary] = {
	"night": {"tint": Color(0.38, 0.44, 0.78), "light": 1.0},
	"dawn": {"tint": Color(0.96, 0.86, 0.92), "light": 0.0},
	"day": {"tint": Color(1, 1, 1), "light": 0.0},
	"dusk": {"tint": Color(1, 0.76, 0.58), "light": 0.0},
}
## The day as marks `[hour, moment]`, in order; between two the tint glides,
## two of the same moment make a plateau.
@export var keys: Array = [[0.0, "night"], [5.5, "night"], [6.5, "dawn"], [7.5, "day"], [17.5, "day"], [19.0, "dusk"], [20.5, "night"], [24.0, "night"]]


## The colour of a written tint.
static func color_of(written: Variant) -> Color:
	if written is Color:
		return written
	if written is String and Color.html_is_valid(written):
		return Color.html(written)
	if written is Array and written.size() >= 3:
		return Color(float(written[0]), float(written[1]), float(written[2]))
	return Color.WHITE


func _validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if minutes_per_second < 0.0:
		problems.append("minutes_per_second cannot be negative, got %s; using 1" % minutes_per_second)
		minutes_per_second = 1.0
	if start_hour < 0.0 or start_hour >= 24.0:
		problems.append("start_hour must be from 0 to 24, got %s; using 12" % start_hour)
		start_hour = 12.0
	var kept := []
	var last := -1.0
	for key: Variant in keys:
		if not key is Array or key.size() != 2 or not (key[0] is float or key[0] is int) or not moments.has(str(key[1])):
			problems.append("keys: %s is not [hour, a moment]; left out" % JSON.stringify(key))
		elif float(key[0]) < last or float(key[0]) < 0.0 or float(key[0]) > 24.0:
			problems.append("keys: %s is out of order; left out" % JSON.stringify(key))
		else:
			last = float(key[0])
			kept.append([float(key[0]), str(key[1])])
	keys = kept
	if keys.is_empty():
		var first: String = "day" if moments.has("day") else (str(moments.keys()[0]) if not moments.is_empty() else "")
		if not first.is_empty():
			problems.append("keys needs a mark; using %s all day" % first)
			keys = [[0.0, first]]
	return problems
