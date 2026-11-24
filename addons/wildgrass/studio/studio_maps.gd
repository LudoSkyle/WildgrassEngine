## Studio's maps made Godot maps, once (feature 10 ter): a Tiled `.tmx` and
## its tilesets become a `WgMap` scene, one `TileMapLayer` per Tiled layer,
## and the TileSet every map shares, its textures halved to 16 px. The rules
## are Studio's: layer levels, special layers, each tile's priority.
extends RefCounted

## The engine's cell, and Studio's tiles: 16 px pictures drawn doubled.
const CELL := 16
const STUDIO_CELL := 32
## The special layers and their tileset; never drawn.
const SPECIAL: Dictionary[String, String] = {
	"passages": "passages.tsx",
	"systemtags": "systemtags.tsx",
	"systemtags_bridge1": "systemtags.tsx",
	"systemtags_bridge2": "systemtags.tsx",
	"terrain_tag": "terrain_tag.tsx",
}
## The scene nodes of the special layers, in tree order: the last is read
## first, so a bridge's tags win over the ground's.
const SPECIAL_NODES: Dictionary[String, String] = {
	"passages": "Passages",
	"terrain_tag": "TerrainTags",
	"systemtags": "SystemTags",
	"systemtags_bridge1": "SystemTagsBridge1",
	"systemtags_bridge2": "SystemTagsBridge2",
}
## A system tag is this plus its tile in `systemtags.tsx`.
const TAG_BASE := 384
## The passage bits: each blocks a side, both ways.
const BLOCKS: Dictionary[int, Vector2i] = {0x01: Vector2i.DOWN, 0x02: Vector2i.LEFT, 0x04: Vector2i.RIGHT, 0x08: Vector2i.UP}
const BUSH := 0x40
const COUNTER := 0x80
## Width of an edge strip, in px: the engine probes 2 px each side.
const EDGE := 3
## Tiled's flip bits, in the top nibble of a gid.
const FLIP_H := 8
const FLIP_V := 4
const FLIP_D := 2

## System tags by number: their name, given as data `system_tag`.
const TAG_NAMES: Dictionary[int, String] = {
	384: "empty", 385: "ice", 386: "wet_sand", 387: "waterfall", 388: "headbutt", 389: "grass", 390: "tall_grass", 391: "cave",
	392: "jump_right", 393: "rapids_left", 394: "rapids_down", 395: "rapids_up", 396: "rapids_right", 397: "mountain", 398: "sand", 399: "pond",
	400: "jump_left", 401: "stop_slide", 402: "bridge_up_down", 403: "puddle", 404: "bridge_left_right", 405: "sea", 406: "under_water", 407: "snow",
	408: "jump_down", 409: "cracked_soil", 410: "hole", 411: "acro_bike_up_down", 412: "acro_bike_left_right", 413: "mach_bike", 414: "acro_bike", 415: "slopes_left",
	416: "jump_up", 417: "stairs_left", 418: "stairs_down", 419: "stairs_up", 420: "stairs_right", 421: "swamp_border", 422: "deep_swamp", 423: "slopes_right",
	424: "height_0", 425: "height_1", 426: "height_2", 427: "height_3", 428: "height_4", 429: "height_5", 430: "height_6", 431: "road",
	432: "rocket_left", 433: "rocket_down", 434: "rocket_up", 435: "rocket_right", 436: "rocket_rotating_left", 437: "rocket_rotating_down", 438: "rocket_rotating_up", 439: "rocket_rotating_right",
	445: "whirlpool", 446: "rock_climb",
}
## The tags an encounter group names, as the Studio layer names them.
const ENCOUNTERS: Dictionary[int, String] = {
	385: "ice", 389: "grass", 390: "tall_grass", 391: "cave", 397: "mountain", 398: "sand", 399: "pond", 405: "ocean", 406: "under_water", 407: "snow",
}
const JUMPS: Dictionary[int, Vector2i] = {392: Vector2i.RIGHT, 400: Vector2i.LEFT, 408: Vector2i.DOWN, 416: Vector2i.UP}
## A bridge's deck: crossed up and down, or left and right.
const BRIDGES: Array[int] = [402, 404]
## The height tags; from height 2 up, a walker on them stands above the
## ground, as at a bridge's end.
const HEIGHT_0 := 424
const HEIGHT_6 := 430
## The engine's level of a bridge's deck.
const DECK := 1
## A Studio map link's lists, in the order Studio reads them, and the side
## of the map each touches.
const SIDES: Dictionary[String, WgMapLink.Side] = {
	"northMaps": WgMapLink.Side.NORTH, "eastMaps": WgMapLink.Side.EAST,
	"southMaps": WgMapLink.Side.SOUTH, "westMaps": WgMapLink.Side.WEST,
}
## A map's sounds in its Studio record: the engine's folder (the `audio`
## config's defaults) and Studio's, inside its `audio` folder.
const SOUNDS: Dictionary[String, Array] = {"bgm": ["music", "bgm"], "bgs": ["ambience", "bgs"]}
## The extensions Studio tries, in order, for a sound named without one.
const STUDIO_SOUND_FORMATS: Array[String] = ["ogg", "mp3", "wav", "mid", "aac", "wma", "it", "xm", "mod", "s3m", "midi", "flac"]
## Those Godot plays.
const PLAYED_FORMATS: Array[String] = ["ogg", "mp3", "wav"]
## Studio counts an animated tile's frames in steps of this many game
## frames (at 60 a second), unless its display config says otherwise.
const IDLE_FRAMES := 6
## The key of an animated tileset's own source, after its file name.
const ANIMATED := "#animated"
## The data layers the TileSet carries, and their type.
const DATA: Dictionary[String, int] = {
	"covers": TYPE_BOOL, "ice": TYPE_BOOL, "jump": TYPE_VECTOR2I, "encounter": TYPE_STRING, "system_tag": TYPE_STRING,
	"terrain_tag": TYPE_INT, "bush": TYPE_BOOL, "counter": TYPE_BOOL, "floor": TYPE_INT, "ramp": TYPE_BOOL,
}

const _StudioEvents := preload("res://addons/wildgrass/studio/studio_events.gd")

## Problems met, each a line: a map or a tileset missing, a layer unread.
var problems: Array[String] = []
## The Studio project's `Data` folder.
var data_folder := ""
## Where maps go; the TileSet and the textures beside them.
var target_folder := "res://maps"
## Where the maps' music and ambiences go, each in its kind's folder.
var audio_folder := "res://audio"
## Where common events go.
var common_events_folder := "res://common_events"
## Gives the texture of a picture written, by its path. Default: `load()`,
## once Godot imported it.
var texture_of := Callable()
## The physics layers (1 to 32) of the solid tiles and of the edges.
var solid_layer := 1
var edge_layer := 4

var _tile_set: TileSet
## Source id of each Tiled tileset, by its file name.
var _sources: Dictionary[String, int] = {}
## Zone id of each map id.
var _zones: Dictionary[int, StringName] = {}
## Each `.tsx` read, by its path.
var _tilesets: Dictionary[String, Dictionary] = {}
var _idle_frames := 0
## The dbSymbol of each map id; the project's map links, by id.
var _symbols: Dictionary[int, String] = {}
var _events: _StudioEvents
var _map_links: Array[Dictionary] = []


func _init(data: String, target := "res://maps") -> void:
	data_folder = data
	target_folder = target
	texture_of = func(path: String) -> Texture2D: return load(path) as Texture2D


## The dbSymbols of the project's maps, sorted.
func map_symbols() -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(data_folder.path_join("Studio/maps")):
		if file.ends_with(".json"):
			found.append(file.get_basename())
	found.sort()
	return found


## The Studio record of a map, or {} with a problem.
func map_record(symbol: String) -> Dictionary:
	var path := data_folder.path_join("Studio/maps/%s.json" % symbol)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not parsed is Dictionary:
		problems.append("%s: no Studio map record" % symbol)
		return {}
	return parsed


## The `.tmx` of a map record.
func tmx_path(record: Dictionary) -> String:
	return data_folder.path_join("Tiled/Maps/%s.tmx" % str(record.get("tiledFilename", "")))


## Writes the textures the maps `symbols` need: each art tileset's picture,
## its key colour made transparent, halved. Returns the pictures written.
func write_textures(symbols: Array[String]) -> Array[String]:
	var written: Array[String] = []
	var done: Dictionary[String, bool] = {}
	DirAccess.make_dir_recursive_absolute(_tiles_folder())
	for symbol in symbols:
		var record := map_record(symbol)
		if record.is_empty():
			continue
		var map := read_tmx(tmx_path(record))
		for tileset: Dictionary in map.get("tilesets", []):
			var tsx_path: String = tileset["path"]
			if done.has(tsx_path):
				continue
			done[tsx_path] = true
			var tsx := read_tsx(tsx_path)
			if tsx.is_empty():
				continue
			var png := _texture_path(tsx)
			var strip := _strip_path(tsx)
			var image_time := FileAccess.get_modified_time(tsx["image"])
			var base_stale := not _is_fresh(png, image_time)
			var strip_stale := not (tsx["animated"] as Array).is_empty() \
				and not _is_fresh(strip, maxi(image_time, FileAccess.get_modified_time(tsx_path)))
			if not base_stale and not strip_stale:
				continue
			var picture := halved(tsx["image"], tsx["trans"])
			if picture == null:
				continue
			if base_stale and picture.save_png(png) == OK:
				_keep_alpha(png)
				written.append(png)
			if strip_stale and animated_strip(tsx, picture).save_png(strip) == OK:
				_keep_alpha(strip)
				written.append(strip)
	return written


## Copies the music and ambiences the maps `symbols` name into the game's
## audio folder, once each. Returns the files written.
func write_sounds(symbols: Array[String]) -> Array[String]:
	var written: Array[String] = []
	for symbol in symbols:
		var record := map_record(symbol)
		for key: String in SOUNDS:
			var found := find_sound(key, record)
			var source: String = found.get("source", "")
			if source.is_empty() or not found.get("problem", "").is_empty():
				continue
			var target := sound_path(key, source)
			if _is_fresh(target, FileAccess.get_modified_time(source)):
				continue
			DirAccess.make_dir_recursive_absolute(target.get_base_dir())
			if DirAccess.copy_absolute(source, ProjectSettings.globalize_path(target)) == OK:
				written.append(target)
	return written


## The sound `key` ("bgm", "bgs") of a map record, found as Studio finds it
## in its folder: the name as given or in lower case, then with each of its
## extensions. {name, source, problem}: no name, no source.
func find_sound(key: String, record: Dictionary) -> Dictionary:
	var sound: Variant = record.get(key, {})
	var name := str((sound as Dictionary).get("name", "")) if sound is Dictionary else ""
	if name.is_empty():
		return {}
	var folder := data_folder.path_join("../audio").simplify_path().path_join(SOUNDS[key][1])
	var files: Dictionary[String, String] = {}
	for file in DirAccess.get_files_at(folder) if DirAccess.dir_exists_absolute(folder) else PackedStringArray():
		files[file.to_lower()] = file
	var found := ""
	for candidate: String in [name] + STUDIO_SOUND_FORMATS.map(func(format: String) -> String: return name + "." + format):
		if files.has(candidate.to_lower()):
			found = files[candidate.to_lower()]
			break
	if found.is_empty():
		return {"name": name, "problem": "its %s '%s' is in no file of audio/%s: silent" % [SOUNDS[key][0], name, SOUNDS[key][1]]}
	var source := folder.path_join(found)
	if found.get_extension().to_lower() not in PLAYED_FORMATS:
		return {"name": name, "source": source, "problem": "its %s '%s' is %s, which Godot does not play: silent" % [SOUNDS[key][0], found, found.get_extension().to_upper()]}
	return {"name": name, "source": source}


## Where the sound copied from `source` goes in the game.
func sound_path(key: String, source: String) -> String:
	return audio_folder.path_join(SOUNDS[key][0]).path_join(source.get_file())


static func _is_fresh(path: String, source_time: int) -> bool:
	return FileAccess.file_exists(path) and FileAccess.get_modified_time(path) >= source_time


## The frames of a tileset's animated tiles, from its `halved_picture`: a
## row each, in the order of `animated`, its frames side by side, as Godot
## plays a tile's animation along a row.
static func animated_strip(tsx: Dictionary, halved_picture: Image) -> Image:
	var animated: Array = tsx["animated"]
	var animations: Dictionary = tsx["animations"]
	var longest := 1
	for id: int in animated:
		longest = maxi(longest, (animations[id] as Array).size())
	var strip := Image.create(longest * CELL, maxi(1, animated.size()) * CELL, false, Image.FORMAT_RGBA8)
	var columns: int = tsx["columns"]
	for row in animated.size():
		var frames: Array = animations[animated[row]]
		for index in frames.size():
			var tile: int = frames[index][0]
			@warning_ignore("integer_division")
			var from := Rect2i(tile % columns * CELL, tile / columns * CELL, CELL, CELL)
			strip.blit_rect(halved_picture, from, Vector2i(index * CELL, row * CELL))
	return strip


## Tells Godot to import `png` as it is: its alpha border left alone, as
## the faint shadows of Studio's tiles are pixels of a colour all but clear.
static func _keep_alpha(png: String) -> void:
	var settings := ConfigFile.new()
	settings.load(png + ".import")
	if not settings.has_section_key("remap", "importer"):
		settings.set_value("remap", "importer", "texture")
		settings.set_value("remap", "type", "CompressedTexture2D")
	settings.set_value("params", "process/fix_alpha_border", false)
	settings.set_value("params", "compress/mode", 0)
	settings.set_value("params", "mipmaps/generate", false)
	settings.save(png + ".import")


## The picture at `path`, `key` (a colour, or null) made transparent, then
## halved, as Studio's doubled tiles are 16 px pictures.
static func halved(path: String, key: Variant) -> Image:
	var picture := Image.load_from_file(path)
	if picture == null:
		return null
	picture.convert(Image.FORMAT_RGBA8)
	picture.resize(maxi(1, picture.get_width() / 2), maxi(1, picture.get_height() / 2), Image.INTERPOLATE_NEAREST)
	if key is Color:
		var bytes := picture.get_data()
		var r := (key as Color).r8
		var g := (key as Color).g8
		var b := (key as Color).b8
		for at in range(0, bytes.size(), 4):
			if bytes[at] == r and bytes[at + 1] == g and bytes[at + 2] == b:
				bytes[at + 3] = 0
		picture.set_data(picture.get_width(), picture.get_height(), false, Image.FORMAT_RGBA8, bytes)
	return picture


## Imports the map `symbol`: its scene, and its tiles into the TileSet.
## Call `save_tile_set()` once the maps are imported.
func import_map(symbol: String) -> bool:
	var record := map_record(symbol)
	if record.is_empty():
		return false
	var map := read_tmx(tmx_path(record))
	if map.is_empty():
		return false
	var tile_set := tile_set()
	var firsts: Array[Dictionary] = []
	for tileset: Dictionary in map["tilesets"]:
		var tsx := read_tsx(tileset["path"])
		if tsx.is_empty():
			continue
		var name: String = tileset["path"].get_file()
		if not _sources.has(name):
			_sources[name] = _add_source(tile_set, name, tsx)
		var entry := {"first": tileset["first"], "source": _sources[name], "name": name, "columns": tsx["columns"], "tsx": tsx}
		if not (tsx["animated"] as Array).is_empty():
			if not _sources.has(name + ANIMATED):
				_sources[name + ANIMATED] = _add_animated_source(tile_set, name, tsx)
			entry["animated_source"] = _sources[name + ANIMATED]
		firsts.append(entry)
	firsts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["first"] > b["first"])
	var width: int = map["width"]
	var height: int = map["height"]
	var regular: Array[Dictionary] = []
	var special: Dictionary[String, PackedInt32Array] = {}
	for layer: Dictionary in map["layers"]:
		var name: String = layer["name"]
		if SPECIAL.has(name):
			if special.has(name):
				problems.append("%s: a second layer '%s', left out" % [symbol, name])
				continue
			special[name] = _special_values(symbol, layer, firsts, SPECIAL[name])
		else:
			regular.append(layer)
	var root := WgMap.new()
	root.name = symbol
	root.size = Vector2i(width, height)
	root.zone = _zone_of(int(record.get("id", 0)))
	root.links = links_of(symbol, int(record.get("id", 0)))
	_set_sounds(root, symbol, record)
	# The entities of neighbouring maps sort together, as Studio draws its
	# linked maps as one.
	root.y_sort_enabled = true
	var entities := Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	# Each tile of each layer, under the priority Studio gives it on its cell.
	var cells_of: Array[Dictionary] = []
	for layer in regular:
		cells_of.append({})
	for y in height:
		for x in width:
			var at := y * width + x
			var drawn: Array[int] = []
			for index in regular.size():
				if (regular[index]["gids"] as PackedInt64Array)[at] != 0:
					drawn.append(index)
			if drawn.is_empty():
				# A tag or a passage on a cell with no tile is dropped.
				for name: String in special:
					special[name][at] = 0
				continue
			var bridge := (special.has("systemtags_bridge1") and special["systemtags_bridge1"][at] != 0) \
				or (special.has("systemtags_bridge2") and special["systemtags_bridge2"][at] != 0)
			var highest := 0
			for index in drawn:
				highest = maxi(highest, regular[index]["z"])
			for index in drawn:
				var z: int = regular[index]["z"]
				var priority := z
				if bridge and z > 0:
					priority = 3 if z <= 3 else 5
				elif z >= 2:
					priority = highest
				var cells: Dictionary = cells_of[index]
				if not cells.has(priority):
					cells[priority] = []
				(cells[priority] as Array).append(Vector2i(x, y))
	for index in regular.size():
		var layer := regular[index]
		var natural: int = layer["z"]
		var cells: Dictionary = cells_of[index]
		var priorities: Array = cells.keys()
		priorities.sort()
		for priority: int in priorities:
			var node := TileMapLayer.new()
			node.name = layer["name"] if priority == natural else "%s p%d" % [layer["name"], priority]
			node.tile_set = tile_set
			for cell: Vector2i in cells[priority]:
				_paint(node, cell, (layer["gids"] as PackedInt64Array)[cell.y * width + cell.x], firsts, symbol)
			if priority == 0:
				node.z_index = -1
				root.add_child(node)
			else:
				node.y_sort_enabled = true
				node.y_sort_origin = CELL * priority - 1
				entities.add_child(node)
	for event in _events_reader().events_of(int(record.get("id", 0))):
		entities.add_child(_events_reader().build_event(event, CELL))
	root.add_child(entities)
	for name: String in SPECIAL_NODES:
		if not special.has(name):
			continue
		var node := TileMapLayer.new()
		node.name = SPECIAL_NODES[name]
		node.tile_set = tile_set
		node.visible = false
		var source := _sources.get(SPECIAL[name], -1) as int
		var columns := (tile_set.get_source(source) as TileSetAtlasSource).get_atlas_grid_size().x if source >= 0 else 1
		var values := special[name]
		for at in values.size():
			# Values are tile indices plus one: 0 is no tile.
			var index := values[at] - 1
			# No passage bit, no terrain tag: nothing to paint.
			if index < 0 or source < 0 or (index == 0 and not name.begins_with("systemtags")):
				continue
			node.set_cell(Vector2i(at % width, at / width), source, Vector2i(index % columns, index / columns))
		root.add_child(node)
	_own(root, root)
	var scene := PackedScene.new()
	if scene.pack(root) != OK:
		problems.append("%s: the scene cannot be packed" % symbol)
		root.free()
		return false
	root.free()
	DirAccess.make_dir_recursive_absolute(target_folder)
	return ResourceSaver.save(scene, target_folder.path_join("%s.tscn" % symbol)) == OK


## The TileSet the maps share: the one saved, else a new one.
func tile_set() -> TileSet:
	if _tile_set != null:
		return _tile_set
	var path := tile_set_path()
	if ResourceLoader.exists(path):
		_tile_set = load(path) as TileSet
	if _tile_set == null:
		_tile_set = TileSet.new()
		_tile_set.tile_size = Vector2i(CELL, CELL)
		_tile_set.add_physics_layer()
		_tile_set.set_physics_layer_collision_layer(0, 1 << (solid_layer - 1))
		_tile_set.add_physics_layer()
		_tile_set.set_physics_layer_collision_layer(1, 1 << (edge_layer - 1))
		# Its path now, before any map is packed: maps refer to it, never
		# hold a copy.
		_tile_set.take_over_path(path)
	# The data layers, those a TileSet saved by an older importer lacks too.
	for data: String in DATA:
		if _tile_set.get_custom_data_layer_by_name(data) == -1:
			_tile_set.add_custom_data_layer()
			var at := _tile_set.get_custom_data_layers_count() - 1
			_tile_set.set_custom_data_layer_name(at, data)
			_tile_set.set_custom_data_layer_type(at, DATA[data])
	var known: Variant = _tile_set.get_meta(&"studio_sources", {})
	if known is Dictionary:
		for name: String in known:
			_sources[name] = int(known[name])
	# The tags' data again: setting it twice changes nothing.
	if _sources.has("systemtags.tsx") and _tile_set.has_source(_sources["systemtags.tsx"]):
		_make_tags(_tile_set.get_source(_sources["systemtags.tsx"]) as TileSetAtlasSource)
	return _tile_set


func tile_set_path() -> String:
	return target_folder.path_join("studio_tiles.tres")


## Saves the TileSet, with the sources' names.
func save_tile_set() -> bool:
	var tile_set := tile_set()
	tile_set.set_meta(&"studio_sources", _sources.duplicate())
	return ResourceSaver.save(tile_set, tile_set_path()) == OK


## A `.tmx`: `width`, `height`, `tilesets` (`first`, `path`) and its layers
## read (`name`, `z`, `gids`), in document order. {} with a problem if it
## cannot be read.
func read_tmx(path: String) -> Dictionary:
	var parser := XMLParser.new()
	if not FileAccess.file_exists(path) or parser.open(path) != OK:
		problems.append("%s: no such map" % path.get_file())
		return {}
	var map := {"width": 0, "height": 0, "tilesets": [], "layers": []}
	# The level of each group entered, and whether it is read.
	var groups: Array[Dictionary] = [{"z": 0, "read": true}]
	var layer := {}
	var in_data := false
	var encoding := ""
	var compression := ""
	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var tag := parser.get_node_name()
				match tag:
					"map":
						if parser.get_named_attribute_value_safe("infinite") == "1":
							problems.append("%s: an infinite map is not read" % path.get_file())
							return {}
						map["width"] = parser.get_named_attribute_value_safe("width").to_int()
						map["height"] = parser.get_named_attribute_value_safe("height").to_int()
					"tileset":
						var source := parser.get_named_attribute_value_safe("source")
						if source.is_empty():
							problems.append("%s: a tileset inside the map is not read" % path.get_file())
							continue
						(map["tilesets"] as Array).append({"first": parser.get_named_attribute_value_safe("firstgid").to_int(), "path": path.get_base_dir().path_join(source).simplify_path()})
					"group":
						var name := parser.get_named_attribute_value_safe("name")
						var parent: Dictionary = groups.back()
						var z: int = parent["z"]
						if name.begins_with("z="):
							z = name.split("=")[1].to_int() - 1
						var read: bool = parent["read"] and (parser.get_named_attribute_value_safe("visible") != "0" or name.begins_with("system"))
						groups.append({"z": z, "read": read})
						if parser.is_empty():
							groups.pop_back()
					"layer":
						var name := parser.get_named_attribute_value_safe("name")
						var parent: Dictionary = groups.back()
						var read: bool = parent["read"] and (parser.get_named_attribute_value_safe("visible") != "0" or SPECIAL.has(name))
						layer = {"name": name, "z": level_of(name, parent["z"]), "read": read, "gids": PackedInt64Array()} if read else {}
					"data":
						in_data = not layer.is_empty()
						encoding = parser.get_named_attribute_value_safe("encoding")
						compression = parser.get_named_attribute_value_safe("compression")
			XMLParser.NODE_TEXT:
				if in_data:
					layer["gids"] = _decode(parser.get_node_data(), encoding, compression, path)
			XMLParser.NODE_ELEMENT_END:
				match parser.get_node_name():
					"data":
						in_data = false
					"layer":
						if not layer.is_empty() and (layer["gids"] as PackedInt64Array).size() == int(map["width"]) * int(map["height"]):
							(map["layers"] as Array).append(layer)
						elif not layer.is_empty():
							problems.append("%s: layer '%s' has not one tile per cell, left out" % [path.get_file(), layer["name"]])
						layer = {}
					"group":
						if groups.size() > 1:
							groups.pop_back()
	return map


## The level of a layer named `name` in a group of level `inherited`: its
## last character, a digit from 1 to 6, minus one; else the group's.
static func level_of(name: String, inherited: int) -> int:
	var last := name.right(1)
	return last.to_int() - 1 if last in ["1", "2", "3", "4", "5", "6"] else inherited


## A `.tsx`: its `image` (a path), `trans` (a Color or null), `columns` of
## 32 px tiles, its `animations` (a tile's frames, each [tile, ms]) and the
## `animated` tiles, sorted. {} with a problem if it cannot be read.
func read_tsx(path: String) -> Dictionary:
	if _tilesets.has(path):
		return _tilesets[path]
	var parser := XMLParser.new()
	if not FileAccess.file_exists(path) or parser.open(path) != OK:
		problems.append("%s: no such tileset" % path.get_file())
		return {}
	var tsx := {}
	var size := Vector2i.ZERO
	var animations: Dictionary[int, Array] = {}
	var tile := -1
	while parser.read() == OK:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		match parser.get_node_name():
			"image":
				if not tsx.is_empty():
					continue
				var trans := parser.get_named_attribute_value_safe("trans")
				size = Vector2i(parser.get_named_attribute_value_safe("width").to_int(), parser.get_named_attribute_value_safe("height").to_int())
				var image := path.get_base_dir().path_join(parser.get_named_attribute_value_safe("source")).simplify_path()
				if size.x <= 0 or size.y <= 0:
					var picture := Image.load_from_file(image)
					size = picture.get_size() if picture != null else Vector2i.ZERO
				tsx = {"image": image, "trans": Color.html(trans) if trans.is_valid_html_color() else null, "columns": maxi(1, size.x / STUDIO_CELL)}
			"tile":
				tile = parser.get_named_attribute_value_safe("id").to_int()
			"frame":
				if not animations.has(tile):
					animations[tile] = []
				animations[tile].append([parser.get_named_attribute_value_safe("tileid").to_int(), parser.get_named_attribute_value_safe("duration").to_int()])
	if tsx.is_empty():
		problems.append("%s: a tileset with no picture" % path.get_file())
		return {}
	@warning_ignore("integer_division")
	var count: int = tsx["columns"] * maxi(1, size.y / STUDIO_CELL)
	var animated: Array[int] = []
	for id: int in animations.keys():
		var outside: Array = animations[id].filter(func(frame: Array) -> bool: return frame[0] < 0 or frame[0] >= count)
		if id < 0 or id >= count or not outside.is_empty():
			problems.append("%s: tile %d's animation shows a tile outside the picture, left still" % [path.get_file(), id])
			animations.erase(id)
		else:
			animated.append(id)
	animated.sort()
	tsx["animations"] = animations
	tsx["animated"] = animated
	_tilesets[path] = tsx
	return tsx


## How long Studio shows a frame of `ms`: whole steps of its idle frames, at
## least one, the rest dropped.
func frame_seconds(ms: int) -> float:
	var idle := idle_frames()
	@warning_ignore("integer_division")
	var step := maxi(1, idle * 1000 / 60)
	@warning_ignore("integer_division")
	return maxi(1, ms / step) * idle / 60.0


## The game frames of a step of animated tiles: the display config's, else 6.
func idle_frames() -> int:
	if _idle_frames > 0:
		return _idle_frames
	_idle_frames = IDLE_FRAMES
	var path := data_folder.path_join("configs/display_config.json")
	var config: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if config is Dictionary and config.get("tilemapSettings") is Dictionary:
		var given: Variant = config["tilemapSettings"].get("autotileIdleFrameCount")
		if (given is float or given is int) and int(given) >= 1:
			_idle_frames = int(given)
	return _idle_frames


static func _decode(text: String, encoding: String, compression: String, path: String) -> PackedInt64Array:
	var gids := PackedInt64Array()
	if encoding == "csv":
		for value in text.strip_edges().replace("\n", "").replace("\r", "").split(",", false):
			gids.append(value.strip_edges().to_int())
		return gids
	var bytes := Marshalls.base64_to_raw(text.strip_edges())
	if compression == "gzip":
		bytes = bytes.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	elif compression == "zlib":
		bytes = bytes.decompress_dynamic(-1, FileAccess.COMPRESSION_DEFLATE)
	elif not compression.is_empty():
		push_error("%s: layers compressed with %s are not read" % [path.get_file(), compression])
		return gids
	for at in range(0, bytes.size() - 3, 4):
		gids.append(bytes.decode_u32(at))
	return gids


func _special_values(symbol: String, layer: Dictionary, firsts: Array[Dictionary], tileset: String) -> PackedInt32Array:
	var values := PackedInt32Array()
	var gids: PackedInt64Array = layer["gids"]
	values.resize(gids.size())
	var first := -1
	for entry in firsts:
		if entry["name"] == tileset:
			first = entry["first"]
	if first < 0:
		problems.append("%s: layer '%s' without its tileset %s" % [symbol, layer["name"], tileset])
		return values
	# The tile index plus one, 0 for none: a system tag's first tile, "empty",
	# is a value of its own.
	for at in gids.size():
		var gid := gids[at] & 0x0FFFFFFF
		values[at] = gid - first + 1 if gid >= first else 0
	return values


## Paints the tile of `raw` (a gid, flips in its top nibble) on `cell`.
func _paint(node: TileMapLayer, cell: Vector2i, raw: int, firsts: Array[Dictionary], symbol: String) -> void:
	var gid := raw & 0x0FFFFFFF
	var flips := (raw >> 28) & 15
	for entry in firsts:
		if gid < int(entry["first"]):
			continue
		var index := gid - int(entry["first"])
		var tsx: Dictionary = entry["tsx"]
		var animated: Array = tsx["animated"]
		var row := animated.bsearch(index)
		if entry.has("animated_source") and row < animated.size() and animated[row] == index:
			node.set_cell(cell, entry["animated_source"], _animated_tile(entry["animated_source"], row, tsx["animations"][index]), _alternative(flips))
			return
		var source := _tile_set.get_source(entry["source"]) as TileSetAtlasSource
		var coords := Vector2i(index % int(entry["columns"]), index / int(entry["columns"]))
		if coords.x >= source.get_atlas_grid_size().x or coords.y >= source.get_atlas_grid_size().y:
			problems.append("%s: tile %d is outside %s" % [symbol, index, entry["name"]])
			return
		if not source.has_tile(coords):
			source.create_tile(coords)
		node.set_cell(cell, entry["source"], coords, _alternative(flips))
		return


## Tiled's flips as a Godot alternative tile.
static func _alternative(flips: int) -> int:
	var alternative := 0
	if flips & FLIP_H:
		alternative |= TileSetAtlasSource.TRANSFORM_FLIP_H
	if flips & FLIP_V:
		alternative |= TileSetAtlasSource.TRANSFORM_FLIP_V
	if flips & FLIP_D:
		alternative |= TileSetAtlasSource.TRANSFORM_TRANSPOSE
	return alternative


## The tile of the animated source `source_id` on `row`, made the first time
## with its `frames`: Godot plays it as Studio does, each frame for its
## steps, every tile of a same rhythm in step.
func _animated_tile(source_id: int, row: int, frames: Array) -> Vector2i:
	var source := _tile_set.get_source(source_id) as TileSetAtlasSource
	var coords := Vector2i(0, row)
	if not source.has_tile(coords):
		source.create_tile(coords)
		source.set_tile_animation_columns(coords, 0)
		source.set_tile_animation_frames_count(coords, frames.size())
		for index in frames.size():
			source.set_tile_animation_frame_duration(coords, index, frame_seconds(frames[index][1]))
	return coords


## Adds the atlas source of a Tiled tileset; the special ones get their
## tiles and data at once.
func _add_source(tile_set: TileSet, name: String, tsx: Dictionary) -> int:
	var source := TileSetAtlasSource.new()
	source.resource_name = name.get_basename()
	source.texture = texture_of.call(_texture_path(tsx))
	source.texture_region_size = Vector2i(CELL, CELL)
	var id := tile_set.add_source(source)
	match name:
		"passages.tsx":
			_make_passages(source)
		"systemtags.tsx":
			_make_tags(source)
		"terrain_tag.tsx":
			for index in _tiles_in(source):
				var data := _tile(source, index)
				data.set_custom_data("terrain_tag", index)
	return id


## Adds the source of a tileset's animated tiles: its strip of frames.
func _add_animated_source(tile_set: TileSet, name: String, tsx: Dictionary) -> int:
	var source := TileSetAtlasSource.new()
	source.resource_name = name.get_basename() + " animated"
	source.texture = texture_of.call(_strip_path(tsx))
	source.texture_region_size = Vector2i(CELL, CELL)
	return tile_set.add_source(source)


func _tiles_in(source: TileSetAtlasSource) -> Array[int]:
	var count := source.get_atlas_grid_size().x * source.get_atlas_grid_size().y
	var indices: Array[int] = []
	for index in range(1, count):
		indices.append(index)
	return indices


func _tile(source: TileSetAtlasSource, index: int) -> TileData:
	var columns := source.get_atlas_grid_size().x
	var coords := Vector2i(index % columns, index / columns)
	if not source.has_tile(coords):
		source.create_tile(coords)
	return source.get_tile_data(coords, 0)


func _make_passages(source: TileSetAtlasSource) -> void:
	var half := CELL / 2.0
	for passage in _tiles_in(source):
		var data := _tile(source, passage)
		var sides := passage & 0x0F
		if sides == 0x0F:
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]))
		else:
			for bit: int in BLOCKS:
				if sides & bit == 0:
					continue
				var side := BLOCKS[bit]
				var strip := PackedVector2Array()
				match side:
					Vector2i.DOWN:
						strip = [Vector2(-half, half - EDGE), Vector2(half, half - EDGE), Vector2(half, half), Vector2(-half, half)]
					Vector2i.UP:
						strip = [Vector2(-half, -half), Vector2(half, -half), Vector2(half, -half + EDGE), Vector2(-half, -half + EDGE)]
					Vector2i.LEFT:
						strip = [Vector2(-half, -half), Vector2(-half + EDGE, -half), Vector2(-half + EDGE, half), Vector2(-half, half)]
					Vector2i.RIGHT:
						strip = [Vector2(half - EDGE, -half), Vector2(half, -half), Vector2(half, half), Vector2(half - EDGE, half)]
				var at := data.get_collision_polygons_count(1)
				data.add_collision_polygon(1)
				data.set_collision_polygon_points(1, at, strip)
		if passage & BUSH:
			data.set_custom_data("bush", true)
		if passage & COUNTER:
			data.set_custom_data("counter", true)


func _make_tags(source: TileSetAtlasSource) -> void:
	for index: int in [0] + _tiles_in(source):
		var tag := TAG_BASE + index
		var data := _tile(source, index)
		if tag == TAG_BASE:
			data.set_custom_data("covers", true)
		if TAG_NAMES.has(tag):
			data.set_custom_data("system_tag", TAG_NAMES[tag])
		if ENCOUNTERS.has(tag):
			data.set_custom_data("encounter", ENCOUNTERS[tag])
		if tag == 385:
			data.set_custom_data("ice", true)
		if JUMPS.has(tag):
			data.set_custom_data("jump", JUMPS[tag])
		# A bridge's deck is a floor above the ground; a height from 2 up is
		# the ramp to it: a walker steps onto the deck from there, and off it
		# back there, as in Studio.
		if tag in BRIDGES:
			data.set_custom_data("floor", DECK)
		if tag >= HEIGHT_0 + 2 and tag <= HEIGHT_6:
			data.set_custom_data("floor", DECK)
			data.set_custom_data("ramp", true)


## A map's music and ambience, by the name of the file copied; with none,
## the one playing goes on, as Studio plays a map's sound only if it names
## one. A sound not found or not played by Godot: silence, as in Studio.
func _set_sounds(root: WgMap, symbol: String, record: Dictionary) -> void:
	for key: String in SOUNDS:
		var found := find_sound(key, record)
		var kind: String = SOUNDS[key][0]
		var sound_name := &""
		if found.has("problem"):
			problems.append("%s: %s" % [symbol, found["problem"]])
		elif found.has("source"):
			sound_name = StringName((found["source"] as String).get_file())
			var settings: Dictionary = record[key]
			if int(settings.get("volume", 100)) != 100 or int(settings.get("pitch", 100)) != 100:
				problems.append("%s: its %s '%s' at volume %d and pitch %d: played at 100" % [symbol, kind, found["name"], int(settings.get("volume", 100)), int(settings.get("pitch", 100))])
		root.set(kind, sound_name)
		root.set("keep_" + kind, found.is_empty())


## The events of the maps `symbols`, written into their scenes by
## `import_map`; here the report, `events.txt` beside the maps: how many events
## and commands, and each command the engine has no class for yet, with its
## count. Returns {events, commands, raw}.
func write_event_report(symbols: Array[String]) -> Dictionary[String, int]:
	var events := _new_events_reader()
	var counts: Dictionary[String, int] = {"events": 0, "commands": 0, "raw": 0}
	var raw: Dictionary[String, int] = {}
	for symbol in symbols:
		var record := map_record(symbol)
		if record.is_empty():
			continue
		var before := events.raw_counts.duplicate()
		events.raw_counts.clear()
		for event in events.events_of(int(record.get("id", 0))):
			counts["events"] += 1
			for page: Dictionary in event.get("pages", []):
				var built := events.build_commands(page.get("list", []))
				counts["commands"] += built.size()
		for what: String in events.raw_counts:
			raw[what] = raw.get(what, 0) + events.raw_counts[what]
		events.raw_counts = before
	for what: String in events.messages.counts:
		raw[what] = raw.get(what, 0) + events.messages.counts[what]
	var ordered := raw.keys()
	ordered.sort_custom(func(a: String, b: String) -> bool: return raw[a] > raw[b] or (raw[a] == raw[b] and a < b))
	var lines: Array[String] = ["Studio events, as the importer writes them.",
		"%d events on %d maps, %d commands." % [counts["events"], symbols.size(), counts["commands"]],
		"What the engine does not run yet, by count:"]
	for what: String in ordered:
		counts["raw"] += raw[what]
		lines.append("  %d %s" % [raw[what], what])
	DirAccess.make_dir_recursive_absolute(target_folder)
	var file := FileAccess.open(target_folder.path_join("events.txt"), FileAccess.WRITE)
	if file == null:
		problems.append("events.txt cannot be written in %s" % target_folder)
	else:
		file.store_string("\n".join(lines) + "\n")
		file.close()
	return counts


## Copies the character sheets the events of the maps `symbols` show into the
## game, once each. Returns the files written.
func write_sheets(symbols: Array[String]) -> Array[String]:
	var events := _events_reader()
	var written: Array[String] = []
	var names: Array[String] = []
	for symbol in symbols:
		var record := map_record(symbol)
		if not record.is_empty():
			for name in events.sheets_of(events.events_of(int(record.get("id", 0)))):
				if not name in names:
					names.append(name)
	var folder := data_folder.path_join("../graphics/characters").simplify_path()
	for name in names:
		var source := folder.path_join(name + ".png")
		var target := events.sheet_path(name)
		if not FileAccess.file_exists(source):
			problems.append("no character sheet graphics/characters/%s.png" % name)
			continue
		if _is_fresh(target, FileAccess.get_modified_time(source)):
			continue
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		if DirAccess.copy_absolute(source, ProjectSettings.globalize_path(target)) == OK:
			written.append(target)
	return written


## Writes Studio's common events as the engine's, `<number>.tres` in
## `common_events_folder`. Returns how many.
func write_common_events() -> int:
	var events := _events_reader()
	var count := 0
	DirAccess.make_dir_recursive_absolute(common_events_folder)
	var commons := events.common_events()
	for number: int in commons:
		var entry: Dictionary = commons[number]
		var common := WgCommonEvent.new()
		common.trigger = clampi(int(entry.get("trigger", 0)), 0, 2) as WgCommonEvent.Trigger
		common.switch = StringName("switch_%d" % int(entry.get("switch_id", 0)))
		common.commands = events.build_commands(entry.get("list", []))
		if ResourceSaver.save(common, common_events_folder.path_join("%d.tres" % number)) == OK:
			count += 1
	return count


## Writes the words of the messages and choices imported so far into the
## translation file `dialogs.csv` beside the maps, which the game lists in its
## localization settings. Returns its path, or "".
func write_translations() -> String:
	var path := target_folder.path_join("dialogs.csv")
	return path if _events_reader().messages.write_translations(path) else ""


func _events_reader() -> _StudioEvents:
	if _events == null:
		_events = _new_events_reader()
	return _events


## A reader of events that knows the text variables every script sets.
func _new_events_reader() -> _StudioEvents:
	var made := _StudioEvents.new(data_folder)
	made.texture_of = texture_of
	var lists: Array = []
	for symbol in map_symbols():
		var record := map_record(symbol)
		for event in made.events_of(int(record.get("id", 0))):
			for page: Dictionary in event.get("pages", []):
				lists.append(page.get("list", []))
	var commons := made.common_events()
	for number: int in commons:
		lists.append(commons[number].get("list", []))
	made.gather_text_variables(lists)
	return made


## The maps shown against the sides of map `map_id`: those of the first
## map link (by id) Studio keeps for it. A link to no map, to the map itself,
## or to a map already linked is a problem, left out.
func links_of(symbol: String, map_id: int) -> Array[WgMapLink]:
	var found: Array[WgMapLink] = []
	var record := {}
	for map_link in _links():
		if int(map_link.get("mapId", -1)) == map_id:
			record = map_link
			break
	var linked: Array[StringName] = []
	for key: String in SIDES:
		var side := key.trim_suffix("Maps")
		var listed: Variant = record.get(key, [])
		for entry: Variant in listed if listed is Array else []:
			var other := int((entry as Dictionary).get("mapId", 0)) if entry is Dictionary else 0
			var other_symbol := _symbol_of(other)
			if other_symbol.is_empty():
				problems.append("%s: linked %s to map %d, which is no map; left out" % [symbol, side, other])
			elif other == map_id:
				problems.append("%s: linked %s to itself; left out" % [symbol, side])
			elif StringName(other_symbol) in linked:
				problems.append("%s: linked %s to %s, already linked; left out" % [symbol, side, other_symbol])
			else:
				var link := WgMapLink.new()
				link.side = SIDES[key]
				link.map = StringName(other_symbol)
				link.offset = int((entry as Dictionary).get("offset", 0))
				found.append(link)
				linked.append(link.map)
	return found


## The project's map links, sorted by id.
func _links() -> Array[Dictionary]:
	if _map_links.is_empty():
		var folder := data_folder.path_join("Studio/maplinks")
		for file in DirAccess.get_files_at(folder) if DirAccess.dir_exists_absolute(folder) else PackedStringArray():
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(file))) if file.ends_with(".json") else null
			if parsed is Dictionary:
				_map_links.append(parsed)
		_map_links.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("id", 0)) < int(b.get("id", 0)))
	return _map_links


## The dbSymbol of map `map_id`, or "" if no map has it.
func _symbol_of(map_id: int) -> String:
	if _symbols.is_empty():
		for symbol in map_symbols():
			var path := data_folder.path_join("Studio/maps/%s.json" % symbol)
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary and parsed.has("id"):
				_symbols[int(parsed["id"])] = symbol
	return _symbols.get(map_id, "")


func _zone_of(map_id: int) -> StringName:
	if _zones.is_empty():
		var folder := data_folder.path_join("Studio/zones")
		for file in DirAccess.get_files_at(folder) if DirAccess.dir_exists_absolute(folder) else PackedStringArray():
			var zone: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(file)))
			if zone is Dictionary:
				for listed: Variant in zone.get("maps", []):
					_zones[int(listed)] = StringName(str(zone.get("dbSymbol", "")))
	return _zones.get(map_id, &"")


func _tiles_folder() -> String:
	return target_folder.path_join("tiles")


func _texture_path(tsx: Dictionary) -> String:
	return _tiles_folder().path_join((tsx["image"] as String).get_file().get_basename() + ".png")


func _strip_path(tsx: Dictionary) -> String:
	return _tiles_folder().path_join((tsx["image"] as String).get_file().get_basename() + "-animated.png")


static func _own(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_own(child, owner)
