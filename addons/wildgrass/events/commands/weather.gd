## Sets the weather of the maps outside (feature 17): `none`, `rain`,
## `storm`, `snow`, or any weather the game has. Its power and how long it
## fades in are the weather's own.
class_name WgEventWeather
extends WgEventCommand

@export var weather: StringName = &"none"
@export_range(0, 9) var power := 5
@export var seconds := 0.0


func run(running: _Run) -> bool:
	var service: Object = running.events.get(&"weather")
	if service != null:
		service.set(&"current", weather)
	return true
