## The `log` config: minimum log levels, globally and per channel.
class_name WgLogConfig
extends WgConfig

const Log := preload("res://addons/wildgrass/core/log/log.gd")

@export var level: Log.Level = Log.Level.INFO
## Channel name to level name, e.g. {"screens": "debug"}.
@export var channels: Dictionary[String, String] = {}


func _validate() -> PackedStringArray:
	var problems := PackedStringArray()
	for channel: String in channels.keys():
		if level_of(channels[channel]) < 0:
			problems.append("channels.%s: unknown level '%s'" % [channel, channels[channel]])
			channels.erase(channel)
	return problems


## The level named `level_name` (debug, info, warn, error), or -1.
static func level_of(level_name: String) -> int:
	return Log.Level.keys().find(level_name.to_upper())
