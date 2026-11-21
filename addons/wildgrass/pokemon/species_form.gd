## What can differ from one form of a species to the next: its size, types,
## stats, breeding, abilities, evolutions, moves, pictures and cry.
class_name WgSpeciesForm
extends Resource

## The picture kinds; each has `_shiny`, `_female` and `_shiny_female`
## variants.
const KINDS: Array[StringName] = [&"icon", &"front", &"back", &"footprint", &"character"]

## Its number: 0, 1…
@export var form := 0
## Empty: the species'.
@export var name := ""
## Empty: the species'.
@export_multiline var description := ""
## In metres.
@export var height := 0.0
## In kilograms.
@export var weight := 0.0
## One or two type ids.
@export var types: Array[StringName] = []
## `{hp, attack, defense, special_attack, special_defense, speed}`.
@export var base_stats: Dictionary[StringName, int] = {}
## The effort it gives, as `base_stats`.
@export var effort: Dictionary[StringName, int] = {}
@export var catch_rate := 0
@export var base_experience := 0
## The experience curve's number, 0 to 5.
@export var growth_rate := 0
@export var base_friendship := 0
## Percent of females; -1: no gender.
@export var female_rate := 50.0
@export var egg_groups: Array[int] = []
@export var hatch_steps := 0
## The species and form its eggs hatch into.
@export var baby: StringName = &""
@export var baby_form := 0
## `[{item, chance}]`, held in the wild.
@export var held_items: Array[Dictionary] = []
## Ability ids: two, then the hidden one.
@export var abilities: Array[StringName] = []
## `[{species, form, conditions: [{type, value}]}]`.
@export var evolutions: Array[Dictionary] = []
## `[{move, how, level}]`: `how` is `level`, `tm`, `tutor`, `egg` or
## `evolution`.
@export var moves: Array[Dictionary] = []
## `{kind: Texture2D or path}`, the kinds of `KINDS` and their variants; and
## `cry`: an `AudioStream` or a path.
@export var pictures: Dictionary[StringName, Variant] = {}
## The front picture's lift, in pixels.
@export var front_offset_y := 0
## Called with the path of a picture or a cry that is missing.
var on_missing := Callable()


## The picture of `kind` asked, else without `_female`, else without
## `_shiny`, else the plain one; null if none. A path is loaded the first
## time it shows.
func picture(kind: StringName, shiny := false, female := false) -> Texture2D:
	var names: Array[StringName] = []
	if shiny and female:
		names.append(StringName("%s_shiny_female" % kind))
	if shiny:
		names.append(StringName("%s_shiny" % kind))
	if female:
		names.append(StringName("%s_female" % kind))
	names.append(kind)
	for key in names:
		var found := _loaded(key) as Texture2D
		if found != null:
			return found
	return null


## Its cry; null if none.
func cry() -> AudioStream:
	return _loaded(&"cry") as AudioStream


## What `pictures[key]` holds, its path loaded once; a missing file is
## reported and forgotten.
func _loaded(key: StringName) -> Resource:
	if not pictures.has(key):
		return null
	var held: Variant = pictures[key]
	if held is Resource:
		return held
	var path := str(held)
	var found := _load(path)
	if found == null:
		pictures.erase(key)
		if on_missing.is_valid():
			on_missing.call(path)
		return null
	pictures[key] = found
	return found


static func _load(path: String) -> Resource:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		return load(path)
	if not FileAccess.file_exists(path):
		return null
	match path.get_extension().to_lower():
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		"mp3":
			return AudioStreamMP3.load_from_file(path)
		"wav":
			return AudioStreamWAV.load_from_file(path)
	var image := Image.load_from_file(path)
	return ImageTexture.create_from_image(image) if image != null else null
