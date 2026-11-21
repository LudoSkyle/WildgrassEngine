extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")

var _world: World
var _missing: Array[String] = []


func before_test() -> void:
	_world = World.new(self)
	_missing = []
	_world.paths.asset_missing.connect(func(path: String, requester: String) -> void: _missing.append("%s %s" % [path.get_file(), requester]))


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _species(id: StringName, number: int, form_numbers: Array[int] = [0]) -> WgSpecies:
	var species := WgSpecies.new()
	species.id = id
	species.number = number
	for form_number in form_numbers:
		var found := WgSpeciesForm.new()
		found.form = form_number
		species.forms.append(found)
	return species


func _save(species: WgSpecies) -> void:
	DirAccess.make_dir_recursive_absolute(_world.sandbox.root + "pokemon")
	ResourceSaver.save(species, _world.sandbox.root + "pokemon/%s.tres" % species.id)


func _image(file_name: String) -> String:
	var path := _world.sandbox.root + file_name
	Image.create(2, 2, false, Image.FORMAT_RGBA8).save_png(path)
	return path


func test_registered_then_the_folder_s_then_a_source_s_each_read_once() -> void:
	var reads: Array[String] = []
	_world.species.add_source(func(id: StringName) -> WgSpecies:
		reads.append(String(id))
		return _species(id, 999) if id == &"mew" else null)
	var bulbasaur := _species(&"bulbasaur", 1)
	bulbasaur.name = "Bulbasaur"
	_save(bulbasaur)
	var mine := _species(&"pikachu", 25)
	_world.species.register(mine)
	assert_str(_world.species.find(&"bulbasaur").name).is_equal("Bulbasaur")
	assert_object(_world.species.find(&"pikachu")).is_same(mine)
	assert_int(_world.species.find(&"mew").number).is_equal(999)
	assert_object(_world.species.find(&"mew")).is_same(_world.species.find(&"mew"))
	assert_array(reads).is_equal(["mew"])
	_save(_species(&"mew", 151))
	assert_int(_world.species.find(&"mew").number).is_equal(999)


func test_a_game_s_species_wins_over_a_source_s_and_the_id_is_filled() -> void:
	_world.species.add_source(func(id: StringName) -> WgSpecies: return _species(&"", 7))
	var squirtle := _species(&"squirtle", 7)
	squirtle.name = "Mine"
	_save(squirtle)
	assert_str(_world.species.find(&"squirtle").name).is_equal("Mine")
	assert_str(_world.species.find(&"wartortle").id).is_equal("wartortle")


func test_an_unknown_species_or_a_resource_of_another_class_is_logged_once() -> void:
	DirAccess.make_dir_recursive_absolute(_world.sandbox.root + "pokemon")
	ResourceSaver.save(WgItem.new(), _world.sandbox.root + "pokemon/potion.tres")
	assert_object(_world.species.find(&"missingno")).is_null()
	assert_object(_world.species.find(&"missingno")).is_null()
	assert_bool(_world.species.has(&"missingno")).is_false()
	assert_object(_world.species.find(&"potion")).is_null()
	assert_array(_world.logged).is_equal([
		"ERROR unknown species 'missingno'",
		"ERROR potion.tres: not a WgSpecies",
		"ERROR unknown species 'potion'",
	])


func test_a_form_it_does_not_have_is_its_form_0_logged_once() -> void:
	var rattata := _species(&"rattata", 19, [0, 1])
	_world.species.register(rattata)
	_world.species.register(_species(&"ghost", 0, []))
	assert_object(_world.species.form(&"rattata", 1)).is_same(rattata.forms[1])
	assert_object(_world.species.form(&"rattata")).is_same(rattata.forms[0])
	assert_object(_world.species.form(&"rattata", 5)).is_same(rattata.forms[0])
	assert_object(_world.species.form(&"rattata", 5)).is_same(rattata.forms[0])
	assert_object(_world.species.form(&"ghost")).is_null()
	assert_object(_world.species.form(&"nobody")).is_null()
	assert_array(_world.logged).is_equal([
		"WARN species 'rattata' has no form 5; form 0 instead",
		"WARN species 'ghost' has no form",
		"ERROR unknown species 'nobody'",
	])


func test_ids_read_nothing_and_all_reads_every_species_by_national_number() -> void:
	var read: Array[String] = []
	_world.species.add_source(func(id: StringName) -> WgSpecies:
		read.append(String(id))
		return _species(id, {&"eevee": 133, &"zubat": 41, &"abra": 63}.get(id, 0)) if id != &"broken" else null,
		func() -> Array: return [&"zubat", &"eevee", &"broken", &"abra"])
	_save(_species(&"ivysaur", 2))
	_world.species.register(_species(&"mew", 151))
	_world.species.register(_species(&"nidoran", 29))
	_world.species.register(_species(&"alpha", 29))
	assert_array(_world.species.ids()).contains_exactly_in_any_order([&"mew", &"nidoran", &"alpha", &"ivysaur", &"zubat", &"eevee", &"broken", &"abra"])
	assert_array(read).is_empty()
	var numbers: Array[String] = []
	for species in _world.species.all():
		numbers.append("%d %s" % [species.number, species.id])
	assert_array(numbers).is_equal(["2 ivysaur", "29 alpha", "29 nidoran", "41 zubat", "63 abra", "133 eevee", "151 mew"])
	assert_array(_world.logged).is_empty()


func test_a_picture_falls_back_from_female_then_from_shiny_and_loads_once() -> void:
	var found := WgSpeciesForm.new()
	var front := ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	found.pictures = {&"front": front, &"front_shiny": _image("shiny.png"), &"front_female": _image("female.png")}
	var shiny := found.picture(&"front", true)
	assert_object(shiny).is_not_null()
	assert_object(found.picture(&"front", true)).is_same(shiny)
	assert_object(found.picture(&"front", true, true)).is_same(shiny)
	var female := found.picture(&"front", false, true)
	assert_object(female).is_not_same(front)
	found.pictures.erase(&"front_shiny")
	assert_object(found.picture(&"front", true, true)).is_same(female)
	assert_object(found.picture(&"front")).is_same(front)
	assert_object(found.picture(&"back")).is_null()


func test_a_missing_picture_or_cry_is_reported_once_and_the_next_variant_shows() -> void:
	var eevee := _species(&"eevee", 133)
	var front := ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	eevee.forms[0].pictures = {&"front": front, &"front_shiny": _world.sandbox.root + "gone.png", &"cry": _world.sandbox.root + "gone.ogg"}
	_world.species.register(eevee)
	var found := _world.species.form(&"eevee")
	assert_object(found.picture(&"front", true)).is_same(front)
	assert_object(found.picture(&"front", true)).is_same(front)
	assert_object(found.cry()).is_null()
	assert_object(found.cry()).is_null()
	assert_array(_missing).is_equal(["gone.png species eevee", "gone.ogg species eevee"])


func test_a_species_read_by_all_reports_its_missing_pictures_too() -> void:
	var lost := _species(&"lost", 1)
	lost.forms[0].pictures = {&"icon": _world.sandbox.root + "lost.png"}
	_save(lost)
	assert_object(_world.species.all()[0].forms[0].picture(&"icon")).is_null()
	assert_array(_missing).is_equal(["lost.png species lost"])


func test_a_missing_file_is_tried_once() -> void:
	var found := WgSpeciesForm.new()
	var told: Array[String] = []
	found.on_missing = func(path: String) -> void: told.append(path.get_file())
	found.pictures = {&"icon": _world.sandbox.root + "gone.png"}
	assert_object(found.picture(&"icon")).is_null()
	assert_object(found.picture(&"icon")).is_null()
	assert_array(told).is_equal(["gone.png"])


func test_a_cry_loads_from_a_plain_file() -> void:
	var found := WgSpeciesForm.new()
	var stream := AudioStreamWAV.new()
	stream.data = PackedByteArray([0, 0, 0, 0])
	stream.save_to_wav(_world.sandbox.root + "cry.wav")
	found.pictures = {&"cry": _world.sandbox.root + "cry.wav"}
	assert_object(found.cry()).is_instanceof(AudioStreamWAV)
