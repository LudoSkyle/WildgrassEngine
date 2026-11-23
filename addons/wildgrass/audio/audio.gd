## What the game sounds like: music and ambience crossfaded, jingles that
## pause the music, effects over everything, cries, and the named sounds of
## the `audio` config. The engine ships no sound.
extends RefCounted

const _Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const _Log := preload("res://addons/wildgrass/core/log/log.gd")
const _ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const _SpeciesData := preload("res://addons/wildgrass/pokemon/species_data.gd")
const _Channel := preload("res://addons/wildgrass/audio/channel.gd")

## The formats looked for, in order.
const FORMATS: Array[String] = ["ogg", "wav", "mp3"]
## Effects playing at once.
const VOICES := 4

## A jingle ended, or was cut by another.
signal jingle_finished(sound_name: StringName)

@warning_ignore("shadowed_global_identifier")
var log: _Log
## The music and the ambience.
var music: _Channel
var ambience: _Channel
var jingle_player: AudioStreamPlayer
var cry_player: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []

var _paths: _Paths
var _config: _ConfigRegistry
var _species: _SpeciesData
var _host: Node
var _streams: Dictionary[String, AudioStream] = {}
var _warned: Dictionary[String, bool] = {}
## The music asked for during a jingle, and the jingle playing.
var _pending_music := {}
var _jingle: StringName = &""
var _jingles := 0
var _maps: Object
var _dialogue: Object
var _items: Object
var _traveller: WgWalker
var _bump_left := 0.0


func _init(paths: _Paths, logger: _Log, config_registry: _ConfigRegistry, species: _SpeciesData, host: Node) -> void:
	_paths = paths
	log = logger
	_config = config_registry
	_species = species
	_host = host


func config() -> WgAudioConfig:
	return _config.get_config(&"audio") as WgAudioConfig


## Adds the buses the game's layout lacks, then the players. Done once.
func setup() -> void:
	if music != null:
		return
	var buses := config().buses
	for kind: String in buses:
		var bus_name := buses[kind]
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, &"Master")
	music = _Channel.new(_host, StringName(buses.get("music", "Master")))
	ambience = _Channel.new(_host, StringName(buses.get("music", "Master")))
	jingle_player = _Channel.player_on(_host, StringName(buses.get("effects", "Master")))
	cry_player = _Channel.player_on(_host, StringName(buses.get("cries", "Master")))
	for voice in VOICES:
		voices.append(_Channel.player_on(_host, StringName(buses.get("effects", "Master"))))


## Plays each map's music and ambience once it shows: a warp, a reload,
## crossing into a linked map.
func follow(maps: Object) -> void:
	_maps = maps
	maps.map_changed.connect(_on_map_changed)


## Plays the engine's named sounds as the game goes: the screens' keys, the
## menu, the player bumping and jumping, doors, saving, items given; and the
## `[jingle=…]` and `[sound=…]` tags of messages.
func follow_game(screens: Object, dialogue: Object, save: Object, bag: Object, items: Object) -> void:
	_dialogue = dialogue
	_items = items
	screens.input_taken.connect(_on_input_taken)
	screens.screen_opened.connect(_on_screen_opened)
	_maps.door_used.connect(_on_door_used)
	_maps.traveller_arrived.connect(_on_traveller_arrived)
	save.written.connect(_on_written)
	bag.given.connect(_on_given)
	dialogue.add_tag(&"jingle", _jingle_tag)
	dialogue.add_tag(&"sound", _sound_tag)
	dialogue.add_tag(&"cry", _cry_tag)


func _on_map_changed(map: WgMap) -> void:
	_watch_traveller()
	if map == null:
		return
	play_music(map.music)
	play_ambience(map.ambience)


func _on_traveller_arrived(_direction: Vector2i, _point: Node2D) -> void:
	_watch_traveller()


## Listens to the traveller's bumps and jumps.
func _watch_traveller() -> void:
	var walker := _maps.traveller as WgWalker if _maps != null else null
	if walker == _traveller or walker == null:
		return
	_traveller = walker
	walker.bumped.connect(_on_bumped)
	walker.step_started.connect(_on_step_started)


func _on_bumped(_direction: Vector2i) -> void:
	play(&"bump")
	_bump_left = config().bump_seconds


func _on_step_started(_from: Vector2i, _to: Vector2i) -> void:
	if _traveller.is_jumping:
		play(&"jump")


func _on_input_taken(event: InputEvent) -> void:
	if _dialogue.is_action(event, "confirm"):
		play(&"confirm")
	elif _dialogue.is_action(event, "cancel"):
		play(&"cancel")
	elif _dialogue.is_action(event, "up") or _dialogue.is_action(event, "down") or _dialogue.is_action(event, "left") or _dialogue.is_action(event, "right"):
		play(&"cursor")


func _on_screen_opened(screen_name: StringName, _screen: WgScreen) -> void:
	if screen_name == &"menu":
		play(&"menu")


func _on_door_used(_door: WgDoor) -> void:
	play(&"door")


func _on_written(_slot: int) -> void:
	play(&"save")


## An item given plays `key_item` for a pocket that reveals, else `item`; the
## message waits for it.
func _on_given(id: StringName, _count: int) -> void:
	var item: WgItem = _items.item(id)
	var reveals: bool = item != null and _items.bag_config().pocket(item.pocket).get("reveal", false)
	_hold_for(&"key_item" if reveals else &"item")


func _jingle_tag(value: String) -> void:
	jingle(StringName(value))
	if is_jingle_playing():
		_dialogue.hold_until(jingle_finished)


func _sound_tag(value: String) -> void:
	effect(StringName(value))


## `[cry=species]`, or `[cry=species:form]`: the cry, over any one playing.
func _cry_tag(value: String) -> void:
	var parts := value.split(":")
	cry(StringName(parts[0]), int(parts[1]) if parts.size() > 1 else 0, 1.0, true)


## Plays the named jingle `role`; a message shown waits for it.
func _hold_for(role: StringName) -> void:
	play(role)
	if is_jingle_playing():
		_dialogue.hold_until(jingle_finished)


## Moves the crossfades on: the engine calls it each frame.
func advance(delta: float) -> void:
	if music == null:
		return
	var seconds := config().fade_seconds
	music.advance(delta, seconds)
	ambience.advance(delta, seconds)
	if is_instance_valid(_traveller) and _traveller.is_pushing() and _bump_left > 0.0:
		_bump_left -= delta
		if _bump_left <= 0.0:
			_on_bumped(Vector2i.ZERO)


## Plays music `sound_name`, crossfaded; asked during a jingle, once it ends.
## Empty: the music fades out.
func play_music(sound_name: StringName, volume := 1.0, pitch := 1.0) -> void:
	setup()
	if not _jingle.is_empty():
		_pending_music = {"name": sound_name, "volume": volume, "pitch": pitch}
		return
	music.change(sound_name, _stream(&"music", sound_name, true), volume, pitch)


func stop_music() -> void:
	play_music(&"")


## The music asked for.
func music_name() -> StringName:
	setup()
	return _pending_music.get("name", music.name) if not _jingle.is_empty() and not _pending_music.is_empty() else music.name


func play_ambience(sound_name: StringName, volume := 1.0, pitch := 1.0) -> void:
	setup()
	ambience.change(sound_name, _stream(&"ambience", sound_name, true), volume, pitch)


func stop_ambience() -> void:
	play_ambience(&"")


## Plays jingle `sound_name`, the music paused (the one fading out stops),
## and returns once it ends; the music goes on where it was.
func jingle(sound_name: StringName, volume := 1.0, pitch := 1.0) -> void:
	setup()
	var stream := _stream(&"jingles", sound_name, false)
	if stream == null:
		return
	if not _jingle.is_empty():
		jingle_finished.emit(_jingle)
	_jingles += 1
	var number := _jingles
	_jingle = sound_name
	music.cut_leaving()
	music.set_paused(true)
	jingle_player.stop()
	jingle_player.stream = stream
	jingle_player.volume_db = linear_to_db(maxf(volume, 0.0001))
	jingle_player.pitch_scale = pitch
	jingle_player.play()
	await jingle_player.finished
	if number != _jingles:
		return
	_jingle = &""
	music.set_paused(false)
	if not _pending_music.is_empty():
		var wanted := _pending_music
		_pending_music = {}
		play_music(wanted["name"], wanted["volume"], wanted["pitch"])
	jingle_finished.emit(sound_name)


## True while a jingle plays.
func is_jingle_playing() -> bool:
	return not _jingle.is_empty()


## Plays effect `sound_name` over everything, on a free voice, else the first.
func effect(sound_name: StringName, volume := 1.0, pitch := 1.0) -> void:
	setup()
	var stream := _stream(&"effects", sound_name, false)
	if stream == null:
		return
	var voice: AudioStreamPlayer = voices[0]
	for candidate in voices:
		if not candidate.playing:
			voice = candidate
			break
	voice.stream = stream
	voice.volume_db = linear_to_db(maxf(volume, 0.0001))
	voice.pitch_scale = pitch
	voice.play()


## Plays the cry of form `form` of `species`, one at a time: false if one
## plays and `force` is false, or it has none.
func cry(species: StringName, form := 0, volume := 1.0, force := false) -> bool:
	setup()
	if cry_player.playing and not force:
		return false
	var found := _species.form(species, form)
	var stream := found.cry() if found != null else null
	if stream == null:
		return false
	cry_player.stream = stream
	cry_player.volume_db = linear_to_db(maxf(volume, 0.0001))
	cry_player.play()
	return true


## Plays the named sound `role` of the config, as its kind does; awaited for a
## jingle. Silent if it has no name.
func play(role: StringName) -> void:
	var sound: Dictionary = config().sounds.get(str(role), {})
	var sound_name := StringName(str(sound.get("name", "")))
	if sound_name.is_empty():
		return
	var volume := float(sound.get("volume", 100)) / 100.0
	var pitch := float(sound.get("pitch", 100)) / 100.0
	match str(sound.get("kind", "effect")):
		"music":
			play_music(sound_name, volume, pitch)
		"ambience":
			play_ambience(sound_name, volume, pitch)
		"jingle":
			await jingle(sound_name, volume, pitch)
		_:
			effect(sound_name, volume, pitch)


## The file of `sound_name` in the folder of `kind`: its name without the
## extension, a path inside it, or a full path; "" if none.
func path_of(kind: StringName, sound_name: StringName) -> String:
	var text := str(sound_name)
	if text.begins_with("res://") or text.begins_with("user://") or text.is_absolute_path():
		return text
	var base := _paths.resolve(&"audio", config().folders.get(str(kind), str(kind)) + "/" + text)
	if not text.get_extension().is_empty():
		return base
	for format in FORMATS:
		var path := base + "." + format
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			return path
	return base + "." + FORMATS[0]


## The stream of a sound, loaded once; null, reported once, if missing.
func _stream(kind: StringName, sound_name: StringName, looping: bool) -> AudioStream:
	if sound_name.is_empty():
		return null
	var path := path_of(kind, sound_name)
	if not _streams.has(path):
		var loaded := load_stream(path)
		if loaded == null:
			if path.get_extension().to_lower() in ["mid", "midi"]:
				_warn_once("%s: Godot does not play MIDI" % path.get_file())
			else:
				_paths.report_missing(path, "audio")
		elif looping:
			_set_loop(loaded)
		_streams[path] = loaded
	return _streams[path]


## A stream from a file, imported or plain; null if it cannot be read.
static func load_stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	if not FileAccess.file_exists(path):
		return null
	match path.get_extension().to_lower():
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		"mp3":
			return AudioStreamMP3.load_from_file(path)
		"wav":
			return AudioStreamWAV.load_from_file(path)
	return null


static func _set_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			if wav.loop_end == 0:
				wav.loop_end = int(wav.get_length() * wav.mix_rate)
	elif "loop" in stream:
		stream.set(&"loop", true)


func _warn_once(message: String) -> void:
	if _warned.has(message):
		return
	_warned[message] = true
	log.warn(&"audio", message)
