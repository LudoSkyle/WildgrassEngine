## The `audio` config: the crossfade, the folders and buses of each kind of
## sound, and the named sounds the engine and the game play.
class_name WgAudioConfig
extends WgConfig

## The roles the engine plays itself; all silent by default.
const ROLES: Dictionary[String, String] = {
	"cursor": "effect", "confirm": "effect", "cancel": "effect", "menu": "effect",
	"bump": "effect", "jump": "effect", "door": "effect",
	"save": "jingle", "item": "jingle", "key_item": "jingle",
}

## A crossfade, in seconds.
@export var fade_seconds := 1.0
## Each kind's folder, inside paths `audio`.
@export var folders: Dictionary[String, String] = {"music": "music", "ambience": "ambience", "jingles": "jingles", "effects": "effects"}
## Each kind's audio bus.
@export var buses: Dictionary[String, String] = {"music": "Music", "effects": "Effects", "cries": "Cries"}
## role -> `{kind, name, volume, pitch}`; volume and pitch in percent.
@export var sounds: Dictionary[String, Dictionary] = _silent_roles()


static func _silent_roles() -> Dictionary[String, Dictionary]:
	var roles: Dictionary[String, Dictionary] = {}
	for role: String in ROLES:
		roles[role] = {"kind": ROLES[role], "name": ""}
	return roles


func _validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if fade_seconds < 0.0:
		problems.append("fade_seconds cannot be negative, got %s; using 0" % fade_seconds)
		fade_seconds = 0.0
	for role: String in sounds.keys():
		if str(sounds[role].get("kind", "")) not in ["music", "ambience", "jingle", "effect"]:
			problems.append("sounds.%s: kind must be music, ambience, jingle or effect; left out" % role)
			sounds.erase(role)
	for role: String in ROLES:
		if not sounds.has(role):
			sounds[role] = {"kind": ROLES[role], "name": ""}
	return problems
