## The `title` config: what comes before the first map, and where a new game
## starts.
class_name WgTitleConfig
extends WgConfig

## True: the engine shows the title once ready; else the game calls
## `Wildgrass.title.start()`, or never.
@export var show_at_start := false
## The map a new game starts on.
@export var start_map := ""
## Its point; empty: the map's first spawn point.
@export var start_point := ""
## Images shown one after the other before the title.
@export var splashes: Array[String] = []
## True: the language is asked at first launch.
@export var choose_language := false
## True: the title waits for a key before going on.
@export var show_prompt := true
## True: the title offers its choices; false: the key goes straight to Play.
@export var show_choices := true
## Seconds before the title's choices take a key.
@export var controls_delay := 0.0
## The fade from the title to the map, in seconds.
@export var fade_seconds := 0.6
## The game's name, shown by the engine's screen without a logo; empty: the
## project's name.
@export var name := ""
## The engine's screen's pictures.
@export var background := ""
@export var logo := ""


## The name shown: `name`, else the project's.
func game_name() -> String:
	return name if not name.is_empty() else str(ProjectSettings.get_setting("application/config/name", ""))


func _validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if controls_delay < 0.0:
		problems.append("controls_delay cannot be negative, got %s; using 0" % controls_delay)
		controls_delay = 0.0
	if fade_seconds < 0.0:
		problems.append("fade_seconds cannot be negative, got %s; using 0" % fade_seconds)
		fade_seconds = 0.0
	return problems
