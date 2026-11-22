extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const DressingFollower := preload("res://tests/support/dressing_follower.gd")

var _world: World
var _player: WgWalker
var _plain: Texture2D
var _shiny: Texture2D
var _shiny_female: Texture2D
var _alolan: Texture2D


func before_test() -> void:
	_world = World.new(self)
	_plain = _texture()
	_shiny = _texture()
	_shiny_female = _texture()
	_alolan = _texture()
	var vulpix := WgSpecies.new()
	vulpix.id = &"vulpix"
	vulpix.forms.append(WgSpeciesForm.new())
	vulpix.forms[0].pictures[&"character"] = _plain
	vulpix.forms[0].pictures[&"character_shiny"] = _shiny
	vulpix.forms[0].pictures[&"character_shiny_female"] = _shiny_female
	vulpix.forms.append(WgSpeciesForm.new())
	vulpix.forms[1].form = 1
	vulpix.forms[1].pictures[&"character"] = _alolan
	_world.species.register(vulpix)
	var ghost := WgSpecies.new()
	ghost.id = &"ghost"
	ghost.forms.append(WgSpeciesForm.new())
	_world.species.register(ghost)
	_world.map({}, Vector2i(20, 20))
	_player = _world.walker(Vector2i(5, 5))
	_world.maps.traveller = _player


func after_test() -> void:
	_world.followers.reset()
	_world.root.free()
	_world.cleanup()


static func _texture() -> Texture2D:
	return ImageTexture.create_from_image(Image.create(128, 128, false, Image.FORMAT_RGBA8))


## Saves `node` as a scene in the sandbox; returns its path.
func _scene(node: Node, file: String) -> String:
	for child: Node in node.get_children():
		child.owner = node
	var packed := PackedScene.new()
	packed.pack(node)
	node.free()
	var path := _world.sandbox.root + file
	ResourceSaver.save(packed, path)
	return path


func _sheet(follower: WgFollower) -> Texture2D:
	return (follower.get_node("Sprite") as WgCharacterSprite).sheet


func test_the_engines_pokemon_shows_its_sheet_stepping_at_the_end_of_the_line() -> void:
	var friend := WgFollower.new()
	_world.followers.add(friend)
	var pokemon := _world.followers.follow_pokemon(&"vulpix")
	var person := WgFollower.new()
	_world.followers.add(person)
	assert_array(_world.followers.line).is_equal([friend, person, pokemon])
	assert_object(_world.followers.pokemon).is_same(pokemon)
	assert_bool(pokemon.always_stepping).is_true()
	assert_bool(pokemon.prints).is_false()
	assert_that(pokemon.species).is_equal(&"vulpix")
	var sprite := pokemon.get_node("Sprite") as WgCharacterSprite
	assert_object(sprite.sheet).is_same(_plain)
	assert_float(sprite.fps).is_equal(6.0)
	assert_object(pokemon.get_parent()).is_same(_player.get_parent())
	assert_bool(pokemon.visible).is_false()


func test_the_form_shiny_and_female_pick_their_pictures() -> void:
	assert_object(_sheet(_world.followers.follow_pokemon(&"vulpix", 0, true))).is_same(_shiny)
	assert_object(_sheet(_world.followers.follow_pokemon(&"vulpix", 0, true, true))).is_same(_shiny_female)
	assert_object(_sheet(_world.followers.follow_pokemon(&"vulpix", 0, false, true))).is_same(_plain)
	var alolan := _world.followers.follow_pokemon(&"vulpix", 1)
	assert_object(_sheet(alolan)).is_same(_alolan)
	assert_int(alolan.form).is_equal(1)
	# No form 7: form 0, and it says so.
	assert_int(_world.followers.follow_pokemon(&"vulpix", 7).form).is_equal(0)


func test_a_new_pokemon_takes_the_place_of_the_one_following_which_is_freed() -> void:
	var first := _world.followers.follow_pokemon(&"vulpix")
	var changes := [0]
	_world.followers.line_changed.connect(func() -> void: changes[0] += 1)
	var second := _world.followers.follow_pokemon(&"vulpix", 1)
	assert_bool(is_instance_valid(first)).is_false()
	assert_array(_world.followers.line).is_equal([second])
	_world.followers.stop_pokemon()
	assert_bool(is_instance_valid(second)).is_false()
	assert_array(_world.followers.line).is_empty()
	assert_object(_world.followers.pokemon).is_null()
	assert_int(changes[0]).is_greater(1)


func test_an_unknown_species_or_one_without_a_sheet_is_logged_and_nobody_follows() -> void:
	var nodes := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var before := _world.followers.follow_pokemon(&"vulpix")
	assert_object(_world.followers.follow_pokemon(&"missingno")).is_null()
	assert_bool(is_instance_valid(before)).is_false()
	assert_object(_world.followers.follow_pokemon(&"ghost")).is_null()
	assert_float(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)).is_equal(nodes)
	assert_array(_world.followers.line).is_empty()
	assert_array(_world.logged).contains(["ERROR no species 'missingno' to follow", "ERROR 'ghost' has no character picture to follow with"])


func test_a_games_scene_and_its_own_dressing() -> void:
	var scaled := WgFollower.new()
	var sprite := WgCharacterSprite.new()
	sprite.name = "Sprite"
	sprite.scale = Vector2(0.9, 0.9)
	scaled.add_child(sprite)
	_world.followers.pokemon_scene = _scene(scaled, "scaled.tscn")
	var pokemon := _world.followers.follow_pokemon(&"vulpix")
	assert_object(_sheet(pokemon)).is_same(_plain)
	assert_float((pokemon.get_node("Sprite") as Node2D).scale.x).is_equal_approx(0.9, 0.001)
	var own := DressingFollower.new()
	_world.followers.pokemon_scene = _scene(own, "own.tscn")
	var dressed := _world.followers.follow_pokemon(&"vulpix", 1, true, false)
	assert_array(dressed.get(&"dressed")).is_equal([1, true, false])
	_world.followers.pokemon_scene = _scene(Node2D.new(), "wrong.tscn")
	assert_object(_world.followers.follow_pokemon(&"vulpix")).is_null()
	assert_str(_world.logged.back()).contains("must be a scene whose root is a WgFollower")


func test_the_part_saves_the_line_and_puts_it_back_hidden() -> void:
	var friend := WgFollower.new()
	friend.name = "Friend"
	var friend_path := _scene(friend, "friend.tscn")
	_world.followers.add(load(friend_path).instantiate())
	var coded := WgFollower.new()
	coded.name = "Coded"
	_world.followers.add(coded)
	_world.followers.follow_pokemon(&"vulpix", 1, true, true)
	_world.followers.enabled = false
	var saved := _world.followers.state()
	assert_dict(saved).is_equal({"enabled": false, "people": [friend_path], "pokemon": {"species": "vulpix", "form": 1, "shiny": true, "female": true}})
	assert_str(_world.logged.back()).contains("Coded was made in code: it is not saved")
	_world.followers.restore(JSON.parse_string(JSON.stringify(saved)))
	assert_bool(_world.followers.enabled).is_false()
	assert_object(_world.followers.line[0].get_parent()).is_null()
	saved["enabled"] = true
	_world.followers.restore(JSON.parse_string(JSON.stringify(saved)))
	var line := _world.followers.line
	assert_int(line.size()).is_equal(2)
	assert_str(line[0].scene_file_path).is_equal(friend_path)
	assert_that(line[1].species).is_equal(&"vulpix")
	assert_array([line[1].form, line[1].shiny, line[1].female]).is_equal([1, true, true])
	assert_bool(is_instance_valid(coded)).is_false()
	assert_object(line[1].get_parent()).is_same(_player.get_parent())
	assert_that(line[1].cell).is_equal(Vector2i(5, 5))
	assert_bool(line[1].visible).is_false()


func test_a_new_game_empties_the_line_and_turns_following_on() -> void:
	var pokemon := _world.followers.follow_pokemon(&"vulpix")
	var friend := WgFollower.new()
	_world.followers.add(friend)
	_world.followers.enabled = false
	_world.followers.reset()
	assert_array(_world.followers.line).is_empty()
	assert_bool(is_instance_valid(pokemon)).is_false()
	assert_bool(is_instance_valid(friend)).is_false()
	assert_bool(_world.followers.enabled).is_true()
	_world.followers.restore({"people": ["res://nowhere.tscn"]})
	assert_array(_world.followers.line).is_empty()
	assert_str(_world.logged.back()).contains("the saved follower 'res://nowhere.tscn' is not a WgFollower scene")
