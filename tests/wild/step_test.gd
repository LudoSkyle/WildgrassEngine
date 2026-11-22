extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const WaitingTrigger := preload("res://tests/support/waiting_trigger.gd")
const T := preload("res://tests/support/tile_builder.gd")

var _world: World
var _player: WgWalker
var _node: WgEncounters
var _met: Array[String] = []


func before_test() -> void:
	_world = World.new(self)
	_met = []
	var rattata := WgSpecies.new()
	rattata.id = &"rattata"
	rattata.name = "Rattata"
	rattata.forms.append(WgSpeciesForm.new())
	_world.species.register(rattata)
	var cells := {}
	for x in range(2, 10):
		cells[Vector2i(x, 5)] = T.GRASS
	cells[Vector2i(5, 4)] = T.NORTH_GRASS
	_world.map(cells, Vector2i(12, 12))
	_player = _world.walker(Vector2i(1, 5), WgPlayerInput.new())
	_world.maps.traveller = _player
	_node = WgEncounters.new()
	_node.rate = 100.0
	var table := WgEncounterTable.new()
	table.id = &"route"
	table.pokemon.assign([{"species": &"rattata", "min_level": 3}])
	_node.tables.append(table)
	_world.maps.current.add_child(_node)
	_world.encounters.encountered.connect(func(pokemon: Dictionary) -> void: _met.append("%s %d" % [pokemon["species"], pokemon["level"]]))


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _step(direction: Vector2i, run := false) -> void:
	_player.step(direction, run)
	_player.advance(0.5)


func _close_box() -> void:
	if _world.dialogue.box != null:
		_world.dialogue.box.set_process(false)
		_world.dialogue.box.advance(10.0)
	var event := InputEventAction.new()
	event.action = "ui_accept"
	event.pressed = true
	_world.screens.handle_input(event)


func test_a_step_in_grass_brings_one_out_says_so_and_holds_the_player() -> void:
	_step(Vector2i.RIGHT)
	assert_array(_met).is_equal(["rattata 3"])
	assert_int(_world.encounters.count).is_equal(1)
	assert_that(_world.encounters.last).is_equal({"species": &"rattata", "form": 0, "level": 3, "shiny": false, "table": &"route"})
	assert_bool(_world.pokedex.is_seen(&"rattata")).is_true()
	_world.dialogue.box.set_process(false)
	_world.dialogue.box.advance(10.0)
	assert_str(_world.dialogue.box.shown_text()).is_equal("A wild Rattata appeared!")
	assert_bool(_world.walkers.is_busy(_player)).is_true()
	Input.action_press("ui_right")
	_player.advance(0.5)
	Input.action_release("ui_right")
	assert_that(_player.cell).is_equal(Vector2i(2, 5))
	_close_box()
	await get_tree().process_frame
	assert_bool(_world.walkers.is_busy(_player)).is_false()


func test_off_the_grass_turning_or_another_walker_bring_no_one() -> void:
	_player.place_at(Vector2i(1, 7))
	_step(Vector2i.RIGHT)
	_player.place_at(Vector2i(3, 5))
	_player.turn(Vector2i.UP)
	_player.advance(0.3)
	var other := _world.walker(Vector2i(6, 6))
	other.step(Vector2i.UP)
	other.advance(0.5)
	_world.encounters.forced = 1
	_world.walkers.encounter_at(other)
	assert_array(_met).is_empty()


func test_the_chance_walked_or_run_and_forced() -> void:
	_node.rate = 0.0
	_node.run_rate = 100.0
	_step(Vector2i.RIGHT)
	assert_array(_met).is_empty()
	_player.place_at(Vector2i(1, 5))
	_step(Vector2i.RIGHT, true)
	assert_array(_met).is_equal(["rattata 3"])
	_close_box()
	await get_tree().process_frame
	_world.encounters.forced = 1
	_step(Vector2i.RIGHT)
	assert_int(_met.size()).is_equal(2)
	_close_box()
	await get_tree().process_frame
	_node.rate = 100.0
	_world.encounters.forced = 0
	_step(Vector2i.RIGHT)
	assert_int(_met.size()).is_equal(2)


func test_a_rate_of_50_brings_one_out_about_half_the_steps() -> void:
	_node.rate = 50.0
	_world.encounters.seed(3)
	_world.encounters.start = func(_pokemon: Dictionary) -> void: pass
	for step in 200:
		_player.place_at(Vector2i(4, 5))
		_step(Vector2i.RIGHT)
	assert_int(_met.size()).is_between(80, 120)


func test_a_table_s_own_rate_wins_over_the_map_s() -> void:
	_node.rate = 0.0
	_node.tables[0].rate = 100.0
	_step(Vector2i.RIGHT)
	assert_array(_met).is_equal(["rattata 3"])


func test_a_trigger_or_a_screen_comes_first() -> void:
	var trigger := WaitingTrigger.new()
	trigger.position = _world.tiles.center_of(Vector2i(2, 5))
	_world.maps.current.entities_node().add_child(trigger)
	_step(Vector2i.RIGHT)
	assert_int(trigger.runs).is_equal(1)
	assert_array(_met).is_empty()
	trigger.release.emit()
	_world.screens.register(&"bag", "res://addons/wildgrass/bag/bag_screen.tscn")
	_world.screens.open(&"bag", {"bag": _world.bag, "items": _world.items, "dialogue": _world.dialogue, "texts": _world.texts})
	_world.encounters.forced = 1
	_world.walkers.encounter_at(_player)
	assert_array(_met).is_empty()


func test_the_hook_may_change_or_cancel_and_start_may_be_replaced() -> void:
	var started: Array[String] = []
	_world.encounters.start = func(pokemon: Dictionary) -> void: started.append("battle %d" % pokemon["level"])
	_world.hooks.add(&"wild_encounter", &"test", func(pokemon: Dictionary) -> Dictionary:
		pokemon["level"] = 50
		return pokemon)
	_step(Vector2i.RIGHT)
	assert_array(started).is_equal(["battle 50"])
	await get_tree().process_frame
	_world.hooks.add(&"wild_encounter", &"repel", func(_pokemon: Dictionary) -> Dictionary: return {}, 10)
	_step(Vector2i.RIGHT)
	assert_array(started).is_equal(["battle 50"])
	assert_int(_world.encounters.count).is_equal(1)


func test_the_area_of_the_tile_chooses_its_tables() -> void:
	_player.place_at(Vector2i(5, 3))
	_step(Vector2i.DOWN)
	assert_array(_met).is_empty()
	var north := WgEncounterTable.new()
	north.area = 1
	north.pokemon.assign([{"species": &"rattata", "min_level": 9}])
	_node.tables.append(north)
	_player.place_at(Vector2i(5, 3))
	_step(Vector2i.DOWN)
	assert_array(_met).is_equal(["rattata 9"])
