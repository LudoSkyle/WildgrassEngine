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
