## Engine logger: levels, channels, coloured console output.
extends RefCounted

## Emitted for every message that passes the level filter.
signal logged(level: Level, channel: StringName, message: String)

enum Level { DEBUG, INFO, WARN, ERROR }

const COLORS: Dictionary[Level, String] = {
	Level.DEBUG: "gray",
	Level.INFO: "cyan",
	Level.WARN: "orange",
	Level.ERROR: "red",
}

## Minimum level for channels without their own.
var level := Level.INFO
## Minimum level per channel, overriding `level`.
var channel_levels: Dictionary[StringName, Level] = {}
## Print to the console. Off in tests that only check `logged`.
var echo := true


func debug(channel: StringName, message: String) -> void:
	write(Level.DEBUG, channel, message)


func info(channel: StringName, message: String) -> void:
	write(Level.INFO, channel, message)


func warn(channel: StringName, message: String) -> void:
	write(Level.WARN, channel, message)


func error(channel: StringName, message: String) -> void:
	write(Level.ERROR, channel, message)


func is_enabled(message_level: Level, channel: StringName) -> bool:
	return message_level >= channel_levels.get(channel, level)


func write(message_level: Level, channel: StringName, message: String) -> void:
	if not is_enabled(message_level, channel):
		return
	logged.emit(message_level, channel, message)
	if not echo:
		return
	var head := "[%s] [%s] [%s]" % [Time.get_time_string_from_system(), Level.keys()[message_level], channel]
	print_rich("[color=%s][b]%s[/b][/color] %s" % [COLORS[message_level], head, message])
	if message_level == Level.WARN:
		push_warning("%s %s" % [head, message])
	elif message_level == Level.ERROR:
		push_error("%s %s" % [head, message])

