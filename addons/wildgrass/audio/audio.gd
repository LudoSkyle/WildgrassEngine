## What the game sounds like: music and ambience crossfaded, jingles that
## pause the music, effects over everything, cries, and the named sounds of
## the `audio` config. The engine ships no sound.
extends RefCounted

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")
const ConfigRegistry := preload("res://addons/wildgrass/core/config/config_registry.gd")
const SpeciesData := preload("res://addons/wildgrass/pokemon/species_data.gd")
const Channel := preload("res://addons/wildgrass/audio/channel.gd")

## The formats looked for, in order.
const FORMATS: Array[String] = ["ogg", "wav", "mp3"]
## Effects playing at once.
const VOICES := 4

## A jingle ended, or was cut by another.
signal jingle_finished(sound_name: StringName)

@warning_ignore("shadowed_global_identifier")
var log: Log
## The music and the ambience.
var music: Channel
var ambience: Channel
var jingle_player: AudioStreamPlayer
var cry_player: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []

var _paths: Paths
var _config: ConfigRegistry
var _species: SpeciesData
var _host: Node
var _streams: Dictionary[String, AudioStream] = {}
var _warned: Dictionary[String, bool] = {}
## The music asked for during a jingle, and the jingle playing.
var _pending_music := {}
var _jingle: StringName = &""
var _jingles := 0


func _init(paths: Paths, logger: Log, config_registry: ConfigRegistry, species: SpeciesData, host: Node) -> void:
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
	music = Channel.new(_host, StringName(buses.get("music", "Master")))
	ambience = Channel.new(_host, StringName(buses.get("music", "Master")))
	jingle_player = Channel.player_on(_host, StringName(buses.get("effects", "Master")))
	cry_player = Channel.player_on(_host, StringName(buses.get("cries", "Master")))
	for voice in VOICES:
		voices.append(Channel.player_on(_host, StringName(buses.get("effects", "Master"))))


## Plays each map's music and ambience once it shows: a warp, a reload,
## crossing into a linked map.
func follow(maps: Object) -> void:
	maps.map_changed.connect(_on_map_changed)


func _on_map_changed(map: WgMap) -> void:
	if map == null:
		return
	play_music(map.music)
	play_ambience(map.ambience)


## Moves the crossfades on: the engine calls it each frame.
func advance(delta: float) -> void:
	if music == null:
		return
	var seconds := config().fade_seconds
	music.advance(delta, seconds)
	ambience.advance(delta, seconds)


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
