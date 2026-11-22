## The `debug` config: when the Debug entry shows, and what the engine's
## tools cycle through.
class_name WgDebugConfig
extends WgConfig

## `"auto"`: in debug builds only; `"true"`, `"false"` (JSON's true and
## false too).
@export var enabled := "auto"
## The hours the Hour tool forces, in turn: `[moment, hour]`.
@export var hours: Array = [["dawn", 6.5], ["day", 12.0], ["dusk", 19.0], ["night", 23.0]]
## The game speeds the Speed tool cycles.
@export var speeds: Array = [1.0, 2.0, 4.0, 8.0]


## JSON's true and false read as "true" and "false".
func load_data(data: Dictionary, source: String) -> PackedStringArray:
	if data.get("enabled") is bool:
		data = data.duplicate()
		data["enabled"] = "true" if data["enabled"] else "false"
	return super.load_data(data, source)


func _validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if enabled not in ["auto", "true", "false"]:
		problems.append("enabled must be \"auto\", true or false, got \"%s\"; using \"auto\"" % enabled)
		enabled = "auto"
	var kept_hours := []
	for hour: Variant in hours:
		if not (hour is Array and hour.size() == 2 and (hour[1] is float or hour[1] is int) and float(hour[1]) >= 0.0 and float(hour[1]) < 24.0):
			problems.append("hours: each is [moment, hour from 0 to 24], got %s; left out" % JSON.stringify(hour))
		elif kept_hours.any(func(kept: Array) -> bool: return is_equal_approx(kept[1], float(hour[1]))):
			problems.append("hours: %s is there already; left out" % float(hour[1]))
		else:
			kept_hours.append([str(hour[0]), float(hour[1])])
	hours = kept_hours
	var kept_speeds := []
	for speed: Variant in speeds:
		if (speed is float or speed is int) and float(speed) > 0.0:
			kept_speeds.append(float(speed))
		else:
			problems.append("speeds must be positive, got %s; left out" % JSON.stringify(speed))
	speeds = kept_speeds if not kept_speeds.is_empty() else [1.0]
	return problems
