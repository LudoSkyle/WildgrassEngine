extends GdUnitTestSuite

# Studio's maps made Godot maps (feature 10 ter), on a tiny Studio project the
# tests write: a 4 × 4 map, an art tileset of two tiles, the special tilesets.

const World := preload("res://tests/support/walking_world.gd")
const StudioMaps := preload("res://addons/wildgrass/studio/studio_maps.gd")

## Tiled's first gid of each tileset in the test map.
const ART := 1
const PASSAGES := 3
const TAGS := 147
const TERRAIN := 275
const KEY := Color8(0xf0, 0x5b, 0xa1)

var _world: World
var _data := ""
var _importer: StudioMaps


func before_test() -> void:
	_world = World.new(self)
	_data = _world.sandbox.root + "Data/"
	_write_project()
	_importer = StudioMaps.new(_data, _world.sandbox.root + "maps")
	_importer.texture_of = func(path: String) -> Texture2D: return ImageTexture.create_from_image(Image.load_from_file(path))


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


## A picture of `columns` × `rows` Studio tiles (32 px), each 2 × 2 block of
## one colour, as Studio's are: `paint` gives the colour of a 16 px pixel.
func _picture(path: String, columns: int, rows: int, paint: Callable) -> void:
	var picture := Image.create(columns * 32, rows * 32, false, Image.FORMAT_RGBA8)
	for y in rows * 16:
		for x in columns * 16:
			var color: Color = paint.call(x, y)
			picture.fill_rect(Rect2i(x * 2, y * 2, 2, 2), color)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	picture.save_png(path)


func _tsx(name: String, image: String, columns: int, rows: int, trans: String) -> void:
	var key := ' trans="%s"' % trans if not trans.is_empty() else ""
	_world.sandbox.write("Data/Tiled/Tilesets/%s.tsx" % name, '<?xml version="1.0" encoding="UTF-8"?>\n<tileset version="1.10" name="%s" tilewidth="32" tileheight="32" tilecount="%d" columns="%d">\n <image source="../Assets/%s"%s width="%d" height="%d"/>\n</tileset>\n' % [name, columns * rows, columns, image, key, columns * 32, rows * 32])


## A layer of the 4 × 4 map: `cells` maps a cell to its gid.
func _csv(name: String, cells: Dictionary, extra := "") -> String:
	var rows: Array[String] = []
	for y in 4:
		var row: Array[String] = []
		for x in 4:
			row.append(str(cells.get(Vector2i(x, y), 0)))
		rows.append(",".join(row))
	return ' <layer name="%s" width="4" height="4"%s>\n  <data encoding="csv">\n%s\n</data>\n </layer>\n' % [name, extra, ",\n".join(rows)]


func _gzip(name: String, cells: Dictionary) -> String:
	var bytes := PackedByteArray()
	bytes.resize(64)
	for y in 4:
		for x in 4:
			bytes.encode_u32((y * 4 + x) * 4, cells.get(Vector2i(x, y), 0))
	return ' <layer name="%s" width="4" height="4">\n  <data encoding="base64" compression="gzip">%s</data>\n </layer>\n' % [name, Marshalls.raw_to_base64(bytes.compress(FileAccess.COMPRESSION_GZIP))]


func _write_project() -> void:
	var assets := _data + "Tiled/Assets/"
	# Tile 0 red; tile 1 half the key colour, half a faint shadow.
	_picture(assets + "art.png", 2, 1, func(x: int, _y: int) -> Color:
		if x < 16:
			return Color.RED
		return KEY if x < 24 else Color(0, 0, 0, 15.0 / 255.0))
	_picture(assets + "passages.png", 8, 18, func(_x: int, _y: int) -> Color: return Color.MAGENTA)
	_picture(assets + "prio_w.png", 8, 16, func(_x: int, _y: int) -> Color: return Color.WHITE)
	_picture(assets + "terrain_tag.png", 8, 2, func(_x: int, _y: int) -> Color: return Color.GRAY)
	_tsx("art", "art.png", 2, 1, "f05ba1")
	_tsx("passages", "passages.png", 8, 18, "ff00ff")
	_tsx("systemtags", "prio_w.png", 8, 16, "f05ba1")
	_tsx("terrain_tag", "terrain_tag.png", 8, 2, "")
	var ground := {}
	for y in 4:
		for x in 4:
			if Vector2i(x, y) != Vector2i(3, 3):
				ground[Vector2i(x, y)] = ART
	var tmx := '<?xml version="1.0" encoding="UTF-8"?>\n<map version="1.10" orientation="orthogonal" renderorder="right-down" width="4" height="4" tilewidth="32" tileheight="32" infinite="0">\n'
	tmx += ' <tileset firstgid="%d" source="../Tilesets/art.tsx"/>\n <tileset firstgid="%d" source="../Tilesets/passages.tsx"/>\n <tileset firstgid="%d" source="../Tilesets/systemtags.tsx"/>\n <tileset firstgid="%d" source="../Tilesets/terrain_tag.tsx"/>\n' % [ART, PASSAGES, TAGS, TERRAIN]
	tmx += _csv("Ground_1", ground)
	tmx += _csv("Hidden_1", {Vector2i(0, 0): ART + 1}, ' visible="0"')
	tmx += ' <group name="z=3">\n' + _csv("Roof", {Vector2i(1, 1): ART + 1, Vector2i(2, 1): ART + 1}) + _csv("Top_5", {Vector2i(1, 1): ART}) + ' </group>\n'
	tmx += _csv("Bridge_2", {Vector2i(0, 2): ART})
	tmx += _gzip("Flip_1", {Vector2i(2, 2): ART | 0x80000000})
	tmx += _csv("passages", {Vector2i(1, 0): PASSAGES + 15, Vector2i(2, 0): PASSAGES + 0x01, Vector2i(0, 1): PASSAGES + 0x80, Vector2i(3, 3): PASSAGES + 15}, ' visible="0"')
	tmx += _csv("systemtags", {Vector2i(0, 0): TAGS + 1, Vector2i(1, 2): TAGS + 8, Vector2i(2, 3): TAGS, Vector2i(0, 2): TAGS + 5, Vector2i(3, 3): TAGS + 1}, ' visible="0"')
	tmx += _csv("systemtags_bridge1", {Vector2i(0, 2): TAGS + 18}, ' visible="0"')
	tmx += _csv("terrain_tag", {Vector2i(2, 2): TERRAIN + 3}, ' visible="0"')
	tmx += "</map>\n"
	_world.sandbox.write("Data/Tiled/Maps/001 Test.tmx", tmx)
	_world.sandbox.write("Data/Tiled/Maps/002 Twin.tmx", tmx)
	for id: int in [1, 2]:
		_world.sandbox.write_json("Data/Studio/maps/map%03d.json" % id, {"klass": "Map", "id": id, "dbSymbol": "map%03d" % id, "tiledFilename": "00%d %s" % [id, "Test" if id == 1 else "Twin"]})
	_world.sandbox.write_json("Data/Studio/zones/zone_0.json", {"klass": "Zone", "id": 0, "dbSymbol": "snowfield", "maps": [1]})


## Imports `symbol` and shows it as the current map.
func _import(symbol := "map001") -> WgMap:
	_importer.write_textures([symbol])
	assert_bool(_importer.import_map(symbol)).is_true()
	_importer.save_tile_set()
	var map := (load(_world.sandbox.root + "maps/%s.tscn" % symbol) as PackedScene).instantiate() as WgMap
	_world.maps.host.add_child(map)
	_world.maps.current = map
	return map


func _names(node: Node) -> Array:
	return node.get_children().map(func(child: Node) -> String: return String(child.name))


func test_a_layer_s_level_is_its_last_digit_from_1_to_6_else_its_group_s() -> void:
	assert_array([StudioMaps.level_of("Tree2", 0), StudioMaps.level_of("Wall_6", 0), StudioMaps.level_of("Fence_7", 3), StudioMaps.level_of("Roof", 2), StudioMaps.level_of("Path_0", 1)]).is_equal([1, 5, 3, 2, 1])
	var map := _importer.read_tmx(_data + "Tiled/Maps/001 Test.tmx")
	var levels := {}
	for layer: Dictionary in map["layers"]:
		levels[layer["name"]] = layer["z"]
	# Hidden: left out; special ones read though hidden; a group "z=3" gives 2.
	assert_dict(levels).is_equal({"Ground_1": 0, "Roof": 2, "Top_5": 4, "Bridge_2": 1, "Flip_1": 0, "passages": 0, "systemtags": 0, "systemtags_bridge1": 0, "terrain_tag": 0})


func test_a_texture_is_its_picture_halved_the_key_colour_clear_a_faint_shadow_kept() -> void:
	var written := _importer.write_textures(["map001"])
	assert_array(written.map(func(path: String) -> String: return path.get_file())).contains_exactly_in_any_order(["art.png", "passages.png", "prio_w.png", "terrain_tag.png"])
	var art := Image.load_from_file(_world.sandbox.root + "maps/tiles/art.png")
	assert_that(art.get_size()).is_equal(Vector2i(32, 16))
	assert_that(art.get_pixel(3, 3)).is_equal(Color.RED)
	assert_float(art.get_pixel(18, 3).a).is_equal(0.0)
	assert_float(art.get_pixel(28, 3).a).is_equal_approx(15.0 / 255.0, 0.001)
	var settings := ConfigFile.new()
	settings.load(_world.sandbox.root + "maps/tiles/art.png.import")
	assert_bool(settings.get_value("params", "process/fix_alpha_border")).is_false()
	# Up to date: not written again.
	assert_array(_importer.write_textures(["map001"])).is_empty()


func test_the_scene_ground_under_the_entities_the_rest_among_them_the_special_layers_hidden() -> void:
	var map := _import()
	assert_that(map.size).is_equal(Vector2i(4, 4))
	assert_that(map.zone).is_equal(&"snowfield")
	assert_array(_names(map)).is_equal(["Ground_1", "Flip_1", "Entities", "Passages", "TerrainTags", "SystemTags", "SystemTagsBridge1"])
	assert_int((map.get_node(^"Ground_1") as TileMapLayer).z_index).is_equal(-1)
	assert_bool((map.get_node(^"Entities") as Node2D).y_sort_enabled).is_true()
	assert_bool((map.get_node(^"Passages") as CanvasItem).visible).is_false()
	# The ground's cell with no tile, and the hidden layer, are left out.
	assert_int((map.get_node(^"Ground_1") as TileMapLayer).get_used_cells().size()).is_equal(15)
	assert_object(map.get_node_or_null(^"Hidden_1")).is_null()
	var flipped := map.get_node(^"Flip_1") as TileMapLayer
	assert_int(flipped.get_cell_alternative_tile(Vector2i(2, 2))).is_equal(TileSetAtlasSource.TRANSFORM_FLIP_H)


func test_each_tile_hides_walkers_by_its_priority_cells_studio_decides_apart_moved() -> void:
	var entities := _import().get_node(^"Entities")
	# The roof's lone cell keeps its level, 2; on (1, 1), under a level-4 tile,
	# it takes 4; on a bridge cell, level 1 takes 3.
	assert_array(_names(entities)).is_equal(["Roof", "Roof p4", "Top_5", "Bridge_2 p3"])
	var origins := entities.get_children().map(func(layer: TileMapLayer) -> int: return int(layer.y_sort_origin))
	assert_array(origins).is_equal([31, 63, 63, 47])
	assert_array((entities.get_node(^"Roof") as TileMapLayer).get_used_cells()).is_equal([Vector2i(2, 1)])
	assert_array((entities.get_node(^"Roof p4") as TileMapLayer).get_used_cells()).is_equal([Vector2i(1, 1)])
	assert_bool((entities.get_node(^"Top_5") as TileMapLayer).y_sort_enabled).is_true()


func test_passages_block_whole_cells_or_sides_both_ways_and_a_counter_is_data() -> void:
	_import()
	var tiles := _world.tiles
	assert_bool(tiles.is_solid(Vector2i(1, 0))).is_true()
	assert_bool(tiles.can_step(Vector2i(0, 0), Vector2i.RIGHT)).is_false()
	assert_bool(tiles.can_step(Vector2i(2, 0), Vector2i.DOWN)).is_false()
	assert_bool(tiles.can_step(Vector2i(2, 1), Vector2i.UP)).is_false()
	assert_bool(tiles.can_step(Vector2i(2, 0), Vector2i.RIGHT)).is_true()
	assert_bool(tiles.can_step(Vector2i(2, 1), Vector2i.RIGHT)).is_true()
	assert_bool(tiles.data(Vector2i(0, 1), &"counter")).is_true()
	# Painted on the cell with no tile: dropped, as Studio drops it.
	assert_bool(tiles.is_solid(Vector2i(3, 3))).is_false()
	assert_bool(tiles.can_step(Vector2i(2, 3), Vector2i.RIGHT)).is_true()


func test_system_tags_are_data_a_bridge_s_over_the_ground_s_and_terrain_tags_too() -> void:
	_import()
	var tiles := _world.tiles
	assert_array([tiles.data(Vector2i(0, 0), &"system_tag"), tiles.data(Vector2i(0, 0), &"ice"), tiles.data(Vector2i(0, 0), &"encounter")]).is_equal(["ice", true, "ice"])
	assert_that(tiles.data(Vector2i(1, 2), &"jump")).is_equal(Vector2i.RIGHT)
	assert_array([tiles.data(Vector2i(2, 3), &"system_tag"), tiles.data(Vector2i(2, 3), &"covers")]).is_equal(["empty", true])
	assert_str(tiles.data(Vector2i(0, 2), &"system_tag")).is_equal("bridge_up_down")
	assert_int(tiles.data(Vector2i(2, 2), &"terrain_tag")).is_equal(3)
	assert_bool(tiles.data(Vector2i(3, 3), &"system_tag") in [null, ""]).is_true()


func test_maps_share_the_tile_set_and_what_is_missing_is_told() -> void:
	_import()
	var sources := _importer.tile_set().get_source_count()
	_importer.import_map("map002")
	assert_int(_importer.tile_set().get_source_count()).is_equal(sources)
	var twin := (load(_world.sandbox.root + "maps/map002.tscn") as PackedScene).instantiate() as WgMap
	assert_str((twin.get_node(^"Ground_1") as TileMapLayer).tile_set.resource_path).is_equal(_importer.tile_set_path())
	assert_that(twin.zone).is_equal(&"")
	twin.free()
	assert_bool(_importer.import_map("map404")).is_false()
	_world.sandbox.write_json("Data/Studio/maps/map005.json", {"id": 5, "tiledFilename": "005 Nowhere"})
	assert_bool(_importer.import_map("map005")).is_false()
	assert_array(_importer.problems).is_equal(["map404: no Studio map record", "005 Nowhere.tmx: no such map"])


## Tiled's first gid of the animated tileset in the water maps.
const WATER := 1
const WATER_COLOURS: Array[Color] = [Color.BLUE, Color.CYAN, Color.GREEN, Color.YELLOW]


## A tileset of four tiles, each a colour: tile 0 plays all four for 100,
## 300, 150 and 50 ms, tile 1 plays tiles 3 and 2, tile 2's animation shows a
## tile outside the picture. Two maps use it.
func _write_water() -> void:
	_picture(_data + "Tiled/Assets/water.png", 4, 1, func(x: int, _y: int) -> Color: return WATER_COLOURS[x / 16])
	var frames := func(tile: int, shown: Array) -> String:
		var lines := shown.map(func(frame: Array) -> String: return '   <frame tileid="%d" duration="%d"/>' % frame)
		return ' <tile id="%d">\n  <animation>\n%s\n  </animation>\n </tile>\n' % [tile, "\n".join(lines)]
	var tsx := '<?xml version="1.0" encoding="UTF-8"?>\n<tileset version="1.10" name="water" tilewidth="32" tileheight="32" tilecount="4" columns="4">\n <image source="../Assets/water.png" trans="f05ba1" width="128" height="32"/>\n'
	tsx += frames.call(0, [[0, 100], [1, 300], [2, 150], [3, 50]]) + frames.call(1, [[3, 100], [2, 100]]) + frames.call(2, [[9, 100]])
	_world.sandbox.write("Data/Tiled/Tilesets/water.tsx", tsx + "</tileset>\n")
	var tmx := '<?xml version="1.0" encoding="UTF-8"?>\n<map version="1.10" orientation="orthogonal" renderorder="right-down" width="4" height="4" tilewidth="32" tileheight="32" infinite="0">\n'
	tmx += ' <tileset firstgid="%d" source="../Tilesets/water.tsx"/>\n' % WATER
	tmx += _csv("Sea_1", {Vector2i(0, 0): WATER, Vector2i(1, 0): WATER | 0x80000000, Vector2i(2, 0): WATER + 1, Vector2i(3, 0): WATER + 2})
	tmx += _csv("Wave_3", {Vector2i(0, 1): WATER})
	_world.sandbox.write("Data/Tiled/Maps/003 Sea.tmx", tmx + "</map>\n")
	_world.sandbox.write("Data/Tiled/Maps/004 Bay.tmx", tmx + "</map>\n")
	for id: int in [3, 4]:
		_world.sandbox.write_json("Data/Studio/maps/map%03d.json" % id, {"klass": "Map", "id": id, "dbSymbol": "map%03d" % id, "tiledFilename": "00%d %s" % [id, "Sea" if id == 3 else "Bay"]})


## The id of the water tileset's animated source, -1 if none.
func _animated_id() -> int:
	var tile_set := _importer.tile_set()
	for index in tile_set.get_source_count():
		var id := tile_set.get_source_id(index)
		if tile_set.get_source(id).resource_name == "water animated":
			return id
	return -1


func test_an_animated_tileset_s_frames_are_a_row_each_in_a_texture_of_their_own() -> void:
	_write_water()
	var written := _importer.write_textures(["map003"])
	assert_array(written.map(func(path: String) -> String: return path.get_file())).contains_exactly_in_any_order(["water.png", "water-animated.png"])
	var strip := Image.load_from_file(_world.sandbox.root + "maps/tiles/water-animated.png")
	assert_that(strip.get_size()).is_equal(Vector2i(64, 32))
	var rows := [[0, 1, 2, 3], [3, 2]]
	for row: int in rows.size():
		for index: int in rows[row].size():
			assert_that(strip.get_pixel(index * 16 + 8, row * 16 + 8)).is_equal(WATER_COLOURS[rows[row][index]])
	assert_array(_importer.problems).is_equal(["water.tsx: tile 2's animation shows a tile outside the picture, left still"])
	# Up to date: not written again.
	assert_array(_importer.write_textures(["map003"])).is_empty()


func test_an_animated_tile_plays_its_frames_for_studio_s_steps_flipped_or_not() -> void:
	_write_water()
	var map := _import("map003")
	var sea := map.get_node(^"Sea_1") as TileMapLayer
	var animated := _animated_id()
	var source := _importer.tile_set().get_source(animated) as TileSetAtlasSource
	assert_int(sea.get_cell_source_id(Vector2i(0, 0))).is_equal(animated)
	assert_that(sea.get_cell_atlas_coords(Vector2i(0, 0))).is_equal(Vector2i(0, 0))
	# Whole steps of 100 ms, at least one: 150 shows 100, 50 shows 100.
	var durations := range(source.get_tile_animation_frames_count(Vector2i(0, 0))).map(func(index: int) -> float: return snappedf(source.get_tile_animation_frame_duration(Vector2i(0, 0), index), 0.001))
	assert_array(durations).is_equal([0.1, 0.3, 0.1, 0.1])
	assert_array([sea.get_cell_source_id(Vector2i(1, 0)), sea.get_cell_atlas_coords(Vector2i(1, 0)), sea.get_cell_alternative_tile(Vector2i(1, 0))]).is_equal([animated, Vector2i(0, 0), TileSetAtlasSource.TRANSFORM_FLIP_H])
	assert_that(sea.get_cell_atlas_coords(Vector2i(2, 0))).is_equal(Vector2i(0, 1))
	assert_int(source.get_tile_animation_frames_count(Vector2i(0, 1))).is_equal(2)
	# The tile whose animation is wrong stays still, from the tileset's source.
	assert_int(sea.get_cell_source_id(Vector2i(3, 0))).is_not_equal(animated)
	assert_that(sea.get_cell_atlas_coords(Vector2i(3, 0))).is_equal(Vector2i(2, 0))
	# Among the entities too, by its priority.
	var wave := map.get_node(^"Entities/Wave_3") as TileMapLayer
	assert_array([wave.get_cell_source_id(Vector2i(0, 1)), int(wave.y_sort_origin)]).is_equal([animated, 31])


func test_a_step_is_the_display_config_s_idle_frames() -> void:
	assert_array([_importer.idle_frames(), _importer.frame_seconds(299), _importer.frame_seconds(300)]).is_equal([6, 0.2, 0.3])
	_world.sandbox.write_json("Data/configs/display_config.json", {"tilemapSettings": {"autotileIdleFrameCount": 12}})
	var slower := StudioMaps.new(_data, _world.sandbox.root + "maps")
	# Steps of 200 ms: 100 shows 200, 450 shows 400.
	assert_array([slower.idle_frames(), slower.frame_seconds(100), slower.frame_seconds(450)]).is_equal([12, 0.2, 0.4])


func test_maps_share_the_animated_source_and_importing_again_adds_none() -> void:
	_write_water()
	_import("map003")
	var sources := _importer.tile_set().get_source_count()
	assert_bool(_importer.import_map("map004")).is_true()
	assert_int(_importer.tile_set().get_source_count()).is_equal(sources)
	_importer.save_tile_set()
	var again := StudioMaps.new(_data, _world.sandbox.root + "maps")
	again.texture_of = _importer.texture_of
	assert_bool(again.import_map("map003")).is_true()
	assert_int(again.tile_set().get_source_count()).is_equal(sources)


## Tags of the systemtags tileset, by their number.
const BRIDGE_UP_DOWN := TAGS + 402 - 384
const HEIGHT_0_TAG := TAGS + 424 - 384
const HEIGHT_4_TAG := TAGS + 428 - 384


## A 4 × 4 map, all ground: a bridge over water on column 1, from the ramp
## (1, 0) down to the ramp (1, 3), its deck over cells solid on the ground;
## a bridge on column 2 over walkable ground; height 0 at (0, 0).
func _write_bridge() -> void:
	var ground := {}
	for y in 4:
		for x in 4:
			ground[Vector2i(x, y)] = ART
	var tmx := '<?xml version="1.0" encoding="UTF-8"?>\n<map version="1.10" orientation="orthogonal" renderorder="right-down" width="4" height="4" tilewidth="32" tileheight="32" infinite="0">\n'
	tmx += ' <tileset firstgid="%d" source="../Tilesets/art.tsx"/>\n <tileset firstgid="%d" source="../Tilesets/passages.tsx"/>\n <tileset firstgid="%d" source="../Tilesets/systemtags.tsx"/>\n' % [ART, PASSAGES, TAGS]
	tmx += _csv("Ground_1", ground)
	tmx += _csv("Deck_3", {Vector2i(1, 1): ART, Vector2i(1, 2): ART, Vector2i(2, 1): ART, Vector2i(2, 2): ART})
	tmx += _csv("passages", {Vector2i(1, 1): PASSAGES + 15, Vector2i(1, 2): PASSAGES + 15}, ' visible="0"')
	tmx += _csv("systemtags", {Vector2i(1, 0): HEIGHT_4_TAG, Vector2i(1, 3): HEIGHT_4_TAG, Vector2i(0, 0): HEIGHT_0_TAG}, ' visible="0"')
	var deck := {}
	for y: int in [1, 2]:
		for x: int in [1, 2]:
			deck[Vector2i(x, y)] = BRIDGE_UP_DOWN
	tmx += _csv("systemtags_bridge1", deck, ' visible="0"')
	_world.sandbox.write("Data/Tiled/Maps/005 Bridge.tmx", tmx + "</map>\n")
	_world.sandbox.write_json("Data/Studio/maps/map005.json", {"klass": "Map", "id": 5, "dbSymbol": "map005", "tiledFilename": "005 Bridge"})


func test_a_bridge_s_deck_is_a_floor_its_ends_ramps_up_to_it() -> void:
	_write_bridge()
	_import("map005")
	var tiles := _world.tiles
	assert_array([tiles.data(Vector2i(1, 1), &"floor"), tiles.data(Vector2i(1, 1), &"ramp")]).is_equal([1, false])
	assert_array([tiles.data(Vector2i(1, 0), &"floor"), tiles.data(Vector2i(1, 0), &"ramp")]).is_equal([1, true])
	# Height 0 and 1 are the ground: nothing to climb.
	assert_array([tiles.data(Vector2i(0, 0), &"floor"), tiles.data(Vector2i(0, 0), &"ramp")]).is_equal([0, false])


func test_a_walker_climbs_the_ramp_crosses_the_deck_over_the_water_and_comes_down() -> void:
	_write_bridge()
	_import("map005")
	var tiles := _world.tiles
	# Onto the ramp from the ground: up on the deck's level.
	assert_bool(tiles.can_step(Vector2i(0, 0), Vector2i.RIGHT, 0)).is_true()
	assert_int(tiles.level_after(Vector2i(0, 0), Vector2i.RIGHT, 0)).is_equal(1)
	# Along the deck, over cells the ground's passages block.
	for y: int in [0, 1, 2]:
		assert_bool(tiles.can_step(Vector2i(1, y), Vector2i.DOWN, 1)).override_failure_message("deck row %d" % y).is_true()
		assert_int(tiles.level_after(Vector2i(1, y), Vector2i.DOWN, 1)).is_equal(1)
	# Across the deck to its other column, but not off its side.
	assert_bool(tiles.can_step(Vector2i(1, 1), Vector2i.RIGHT, 1)).is_true()
	assert_bool(tiles.can_step(Vector2i(1, 1), Vector2i.LEFT, 1)).is_false()
	# Off the far ramp: back on the ground.
	assert_bool(tiles.can_step(Vector2i(1, 3), Vector2i.LEFT, 1)).is_true()
	assert_int(tiles.level_after(Vector2i(1, 3), Vector2i.LEFT, 1)).is_equal(0)


func test_on_the_ground_a_walker_goes_under_the_deck_where_the_ground_lets_it() -> void:
	_write_bridge()
	_import("map005")
	var tiles := _world.tiles
	assert_bool(tiles.can_step(Vector2i(3, 1), Vector2i.LEFT, 0)).is_true()
	assert_int(tiles.level_after(Vector2i(3, 1), Vector2i.LEFT, 0)).is_equal(0)
	assert_bool(tiles.can_step(Vector2i(2, 0), Vector2i.DOWN, 0)).is_true()
	# Under the deck over the water, the ground's passages hold.
	assert_bool(tiles.can_step(Vector2i(0, 1), Vector2i.RIGHT, 0)).is_false()
	assert_bool(tiles.can_step(Vector2i(2, 1), Vector2i.LEFT, 0)).is_false()


func test_a_tile_set_from_an_older_import_gets_the_new_data_layers_and_tags() -> void:
	_import()
	var tile_set := _importer.tile_set()
	tile_set.remove_custom_data_layer(tile_set.get_custom_data_layer_by_name("ramp"))
	tile_set.remove_custom_data_layer(tile_set.get_custom_data_layer_by_name("floor"))
	_importer.save_tile_set()
	var again := StudioMaps.new(_data, _world.sandbox.root + "maps")
	var reloaded := again.tile_set()
	assert_int(reloaded.get_custom_data_layer_by_name("floor")).is_not_equal(-1)
	var tags := reloaded.get_source(again.tile_set().get_meta(&"studio_sources")["systemtags.tsx"]) as TileSetAtlasSource
	var height_4 := 428 - 384
	assert_bool(tags.get_tile_data(Vector2i(height_4 % 8, height_4 / 8), 0).get_custom_data("ramp")).is_true()


## Map records 3 and 4, each the 4 × 4 test map.
func _write_more_maps() -> void:
	for id: int in [3, 4]:
		_world.sandbox.write_json("Data/Studio/maps/map%03d.json" % id, {"klass": "Map", "id": id, "dbSymbol": "map%03d" % id, "tiledFilename": "001 Test"})


func _write_link(id: int, map_id: int, sides: Dictionary) -> void:
	var record := {"klass": "MapLink", "id": id, "dbSymbol": "maplink_%d" % id, "mapId": map_id, "northMaps": [], "eastMaps": [], "southMaps": [], "westMaps": []}
	for side: String in sides:
		record[side] = (sides[side] as Array).map(func(pair: Array) -> Dictionary: return {"mapId": pair[0], "offset": pair[1]})
	_world.sandbox.write_json("Data/Studio/maplinks/maplink_%d.json" % id, record)


static func _described(links: Array[WgMapLink]) -> Array:
	return links.map(func(link: WgMapLink) -> Array: return [WgMapLink.Side.keys()[link.side], String(link.map), link.offset])


func test_a_map_s_links_are_the_first_studio_map_link_naming_it_side_by_side() -> void:
	_write_more_maps()
	# Two records name map 1: Studio keeps the one of lowest id, whatever
	# its file's name.
	_write_link(10, 1, {"northMaps": [[2, 0]]})
	_write_link(2, 1, {"eastMaps": [[2, -1]], "westMaps": [[3, 2], [4, -3]]})
	_write_link(3, 2, {"westMaps": [[1, 1]]})
	var map := _import()
	assert_array(_described(map.links)).is_equal([["EAST", "map002", -1], ["WEST", "map003", 2], ["WEST", "map004", -3]])
	# Their entities sort with the current map's, as Studio draws them as one.
	assert_bool(map.y_sort_enabled).is_true()
	assert_array(_importer.problems).is_empty()
	# Importing again writes the same links, none added.
	assert_bool(_importer.import_map("map001")).is_true()
	var again := (load(_world.sandbox.root + "maps/map001.tscn") as PackedScene).instantiate() as WgMap
	assert_array(_described(again.links)).has_size(3)
	again.free()
	_importer.write_textures(["map002"])
	assert_bool(_importer.import_map("map002")).is_true()
	var other := (load(_world.sandbox.root + "maps/map002.tscn") as PackedScene).instantiate() as WgMap
	assert_array(_described(other.links)).is_equal([["WEST", "map001", 1]])
	other.free()


func test_a_link_to_no_map_to_the_map_itself_or_to_a_map_linked_already_is_told_and_left_out() -> void:
	_write_link(1, 1, {"northMaps": [[0, 0], [9, 0]], "eastMaps": [[1, 0]], "southMaps": [[2, 0]], "westMaps": [[2, 3]]})
	var map := _import()
	assert_array(_described(map.links)).is_equal([["SOUTH", "map002", 0]])
	assert_array(_importer.problems).is_equal([
		"map001: linked north to map 0, which is no map; left out",
		"map001: linked north to map 9, which is no map; left out",
		"map001: linked east to itself; left out",
		"map001: linked west to map002, already linked; left out",
	])


func test_linked_maps_are_shown_against_the_map_and_walked_into_across_the_seam() -> void:
	_write_more_maps()
	_write_link(1, 1, {"eastMaps": [[2, 1]], "southMaps": [[3, -1]]})
	_write_link(2, 2, {"westMaps": [[1, -1]]})
	_world.sandbox.use_maps_folder()
	_importer.write_textures(["map001", "map002", "map003"])
	for symbol: String in ["map001", "map002", "map003"]:
		assert_bool(_importer.import_map(symbol)).is_true()
	_importer.save_tile_set()
	var maps := _world.maps
	maps.traveller = auto_free(Node2D.new())
	await maps.go_to(&"map001", &"")
	if maps.is_loading_neighbours:
		await maps.neighbours_loaded
	# Studio's places: east, from the map's right edge, `offset` rows down;
	# south, from its bottom edge, `offset` columns right.
	var east := maps.map_at(_world.tiles.center_of(Vector2i(4, 1)))
	var south := maps.map_at(_world.tiles.center_of(Vector2i(-1, 4)))
	assert_str(east.scene_file_path.get_file()).is_equal("map002.tscn")
	assert_that(east.position).is_equal(Vector2(64, 16))
	assert_str(south.scene_file_path.get_file()).is_equal("map003.tscn")
	assert_that(south.position).is_equal(Vector2(-16, 64))
	var tiles := _world.tiles
	# Across the seam onto the neighbour's open ground, both ways.
	assert_bool(tiles.can_step(Vector2i(3, 1), Vector2i.RIGHT)).is_true()
	assert_bool(tiles.can_step(Vector2i(4, 1), Vector2i.LEFT)).is_true()
	# The neighbour's own passages hold: map003's solid cell (1, 0).
	assert_bool(tiles.can_step(Vector2i(0, 3), Vector2i.DOWN)).is_false()
	assert_bool(tiles.can_step(Vector2i(1, 3), Vector2i.DOWN)).is_true()
	# Off an edge with no link: nothing there.
	assert_bool(tiles.can_step(Vector2i(0, 1), Vector2i.LEFT)).is_false()
	# Standing in the neighbour, it becomes the current map.
	maps.traveller.global_position = tiles.center_of(Vector2i(4, 1))
	assert_bool(maps.cross()).is_true()
	assert_object(maps.current).is_same(east)
	if maps.is_loading_neighbours:
		await maps.neighbours_loaded


## A map record's sounds; `bgm` and `bgs`: [name, volume, pitch].
func _write_sounds(id: int, bgm: Array, bgs: Array) -> void:
	_world.sandbox.write_json("Data/Studio/maps/map%03d.json" % id, {"klass": "Map", "id": id, "dbSymbol": "map%03d" % id, "tiledFilename": "00%d %s" % [id, "Test" if id == 1 else "Twin"],
		"bgm": {"name": bgm[0], "volume": bgm[1], "pitch": bgm[2]}, "bgs": {"name": bgs[0], "volume": bgs[1], "pitch": bgs[2]}})


func _write_studio_sound(path: String) -> void:
	_world.sandbox.write(path, "not a real sound")


func test_a_map_s_music_and_ambience_are_the_files_studio_finds_copied_into_the_game() -> void:
	_write_studio_sound("audio/bgm/Town Theme.ogg")
	_write_studio_sound("audio/bgs/wind.ogg")
	# Studio finds "Wind" in lower case, with its extension.
	_write_sounds(1, ["Town Theme.ogg", 100, 100], ["Wind", 100, 100])
	_importer.audio_folder = _world.sandbox.root + "audio"
	var written := _importer.write_sounds(["map001"])
	assert_array(written).contains_exactly_in_any_order([_world.sandbox.root + "audio/music/Town Theme.ogg", _world.sandbox.root + "audio/ambience/wind.ogg"])
	assert_array(_importer.write_sounds(["map001"])).is_empty()
	var map := _import()
	assert_array([map.music, map.keep_music, map.ambience, map.keep_ambience]).is_equal([&"Town Theme.ogg", false, &"wind.ogg", false])
	# The engine finds them there by those names.
	assert_str(_world.audio.path_of(&"music", map.music)).is_equal(_world.sandbox.root + "audio/music/Town Theme.ogg")
	assert_str(_world.audio.path_of(&"ambience", map.ambience)).is_equal(_world.sandbox.root + "audio/ambience/wind.ogg")
	assert_array(_importer.problems).is_empty()


func test_a_map_naming_no_sound_keeps_the_one_playing_one_missing_or_unplayed_is_silent() -> void:
	_write_studio_sound("audio/bgm/Old.mid")
	_write_studio_sound("audio/bgs/rain.ogg")
	_write_sounds(1, ["", 100, 100], ["Storm", 100, 100])
	_write_sounds(2, ["Old", 100, 100], ["rain.ogg", 80, 150])
	_importer.audio_folder = _world.sandbox.root + "audio"
	assert_array(_importer.write_sounds(["map001", "map002"])).is_equal([_world.sandbox.root + "audio/ambience/rain.ogg"])
	var first := _import()
	assert_array([first.music, first.keep_music, first.ambience, first.keep_ambience]).is_equal([&"", true, &"", false])
	var second := _import("map002")
	assert_array([second.music, second.keep_music, second.ambience, second.keep_ambience]).is_equal([&"", false, &"rain.ogg", false])
	assert_array(_importer.problems).is_equal([
		"map001: its ambience 'Storm' is in no file of audio/bgs: silent",
		"map002: its music 'Old.mid' is MID, which Godot does not play: silent",
		"map002: its ambience 'rain.ogg' at volume 80 and pitch 150: played at 100",
	])


func test_the_map_numbers_go_into_the_game_s_map_config_its_other_fields_kept() -> void:
	_world.sandbox.write_json("Data/Studio/maps/harbour.json", {"klass": "Map", "id": 5, "dbSymbol": "harbour", "tiledFilename": "005 Harbour"})
	_world.sandbox.write_json("config/map.json", {"tile_size": 32})
	_importer.config_folder = _world.sandbox.root + "config"
	assert_str(_importer.write_map_numbers()).is_equal(_world.sandbox.root + "config/map.json")
	var written: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_world.sandbox.root + "config/map.json"))
	assert_dict(written).is_equal({"tile_size": 32.0, "numbers": {"1": "map001", "2": "map002", "5": "harbour"}})


func test_a_map_s_events_are_written_in_its_scene_their_sheets_and_common_events_too() -> void:
	const Events := preload("res://tests/studio/events_test.gd")
	const Writer := preload("res://tests/support/marshal_writer.gd")
	_picture(_world.sandbox.root + "graphics/characters/npc.png", 4, 4, func(_x: int, _y: int) -> Color: return Color.GREEN)
	_world.sandbox.write_json("Data/Studio/items/potion.json", {"klass": "Item", "id": 17, "dbSymbol": "potion"})
	var has_potion := Events.command(111, [8, 17])
	var talker := Events.event([Events.page([Events.command(101, ["Hi"]), Events.command(401, ["there"]), has_potion], {"graphic": "npc"})], "Talker")
	talker["x"] = 2
	talker["y"] = 1
	var door := Events.event([Events.page([Events.transfer(2, Vector2i(3, 1), 2), Events.command(207, [1, 5])], {"trigger": 1})], "Door")
	door["id"] = 2
	var file := FileAccess.open(_data + "Map001.rxdata", FileAccess.WRITE)
	file.store_buffer(Writer.bytes_of({"class": "RPG::Map", "events": {1: talker, 2: door}}))
	file.close()
	var common := {"class": "RPG::CommonEvent", "id": 3, "name": "Heal", "trigger": 2, "switch_id": 9, "list": [Events.command(121, [1, 1, 0]), Events.command(0)]}
	file = FileAccess.open(_data + "CommonEvents.rxdata", FileAccess.WRITE)
	file.store_buffer(Writer.bytes_of([null, common]))
	file.close()
	_importer.common_events_folder = _world.sandbox.root + "common_events"
	_importer._events_reader().sheets_folder = _world.sandbox.root + "graphics/game_characters"
	assert_array(_importer.write_sheets(["map001"])).is_equal([_world.sandbox.root + "graphics/game_characters/npc.png"])
	var map := _import()
	var events := map.get_node("Entities").get_children().filter(func(child: Node) -> bool: return child is WgEvent)
	assert_array(events.map(func(event: WgEvent) -> String: return String(event.name))).is_equal(["Event1", "Event2"])
	var first: WgEvent = events[0]
	assert_that(first.position).is_equal(Vector2(40, 24))
	assert_object(first.pages[0].sheet).is_not_null()
	assert_array(first.pages[0].commands.map(func(made: WgEventCommand) -> String: return made.get_script().get_global_name())).is_equal(["WgEventSay", "WgEventIf", "WgEventBlockEnd"])
	assert_str((first.pages[0].commands[0] as WgEventSay).text).is_equal("Hi\nthere")
	assert_str((first.pages[0].commands[1] as WgEventIf).item).is_equal("potion")
	assert_str(String((events[1] as WgEvent).pages[0].commands[0].get(&"map"))).is_equal("map002")
	assert_int(_importer.write_common_events()).is_equal(1)
	var written := load(_world.sandbox.root + "common_events/3.tres") as WgCommonEvent
	assert_array([written.trigger, written.switch, written.commands.size()]).is_equal([WgCommonEvent.Trigger.PARALLEL, &"switch_9", 2])
	var counts := _importer.write_event_report(["map001", "map002"])
	assert_array([counts["events"], counts["commands"], counts["raw"]]).is_equal([2, 6, 1])
	assert_array(FileAccess.get_file_as_string(_world.sandbox.root + "maps/events.txt").split("\n")).is_equal([
		"Studio events, as the importer writes them.",
		"2 events on 2 maps, 6 commands.",
		"What the engine does not run yet, by count:",
		"  1 Show Animation",
		"",
	])


func test_the_pictures_and_sounds_events_use_are_copied_once() -> void:
	const Events := preload("res://tests/studio/events_test.gd")
	const Writer := preload("res://tests/support/marshal_writer.gd")
	for file: String in ["graphics/pictures/Intro.png", "graphics/transitions/swirl.png", "audio/se/door.ogg", "audio/bgm/Town.ogg", "audio/me/Old.mid"]:
		_world.sandbox.write(file, "x")
	var shows := Events.event([Events.page([
		Events.command(231, [1, "intro", 0, 0, 0, 0, 100, 100, 255, 0]), Events.command(222, ["swirl"]), Events.command(231, [2, "lost", 0, 0, 0, 0, 100, 100, 255, 0]),
		Events.command(250, [{"name": "door"}]), Events.command(241, [{"name": "Town"}]), Events.command(249, [{"name": "Old"}]),
	])])
	var file := FileAccess.open(_data + "Map001.rxdata", FileAccess.WRITE)
	file.store_buffer(Writer.bytes_of({"class": "RPG::Map", "events": {1: shows}}))
	file.close()
	_importer.audio_folder = _world.sandbox.root + "game_audio"
	_importer._events_reader().pictures_folder = _world.sandbox.root + "game_pictures"
	_importer._events_reader().transitions_folder = _world.sandbox.root + "game_transitions"
	var written := _importer.write_media(["map001"])
	written.sort()
	assert_array(written).is_equal([
		_world.sandbox.root + "game_audio/effects/door.ogg", _world.sandbox.root + "game_audio/music/Town.ogg",
		_world.sandbox.root + "game_pictures/intro.png", _world.sandbox.root + "game_transitions/swirl.png",
	])
	assert_bool(_importer.problems.has("no picture graphics/pictures/lost.png")).is_true()
	assert_array(_importer.write_media(["map001"])).is_empty()
