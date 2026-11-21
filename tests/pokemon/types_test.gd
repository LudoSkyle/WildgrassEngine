extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")

var _world: World


func before_test() -> void:
	_world = World.new(self)


func after_test() -> void:
	_world.root.free()
	_world.cleanup()


func _type(id: StringName, damage: Dictionary[StringName, float] = {}) -> WgType:
	var type := WgType.new()
	type.id = id
	type.damage = damage
	return type


func test_registered_then_the_folder_s_then_a_source_s() -> void:
	DirAccess.make_dir_recursive_absolute(_world.sandbox.root + "types")
	var water := _type(&"water")
	water.name = "Water"
	ResourceSaver.save(water, _world.sandbox.root + "types/water.tres")
	var fire := _type(&"fire")
	_world.types.register(fire)
	_world.types.add_source(func(id: StringName) -> WgType: return _type(&"") if id == &"ice" else null, func() -> Array: return [&"ice"])
	assert_object(_world.types.find(&"fire")).is_same(fire)
	assert_str(_world.types.find(&"water").name).is_equal("Water")
	assert_str(_world.types.find(&"ice").id).is_equal("ice")
	assert_bool(_world.types.has(&"shadow")).is_false()
	assert_array(_world.types.ids()).contains_exactly_in_any_order([&"fire", &"ice", &"water"])
	assert_array(_world.types.all().map(func(type: WgType) -> StringName: return type.id)).is_equal([&"fire", &"ice", &"water"])


func test_factors_multiply_and_a_type_not_named_counts_1() -> void:
	_world.types.register(_type(&"fire", {&"grass": 2.0, &"water": 0.5, &"rock": 0.5}))
	for id: StringName in [&"grass", &"water", &"rock", &"poison", &"bug"]:
		_world.types.register(_type(id))
	assert_float(_world.types.factor(&"fire", [&"grass", &"poison"])).is_equal(2.0)
	assert_float(_world.types.factor(&"fire", [&"water", &"rock"])).is_equal(0.25)
	assert_float(_world.types.factor(&"fire", [&"bug"])).is_equal(1.0)
	assert_float(_world.types.factor(&"fire", [])).is_equal(1.0)
	assert_array(_world.logged).is_empty()


func test_an_unknown_type_is_logged_once_and_counts_1() -> void:
	_world.types.register(_type(&"fire", {&"grass": 2.0, &"steel": 2.0}))
	_world.types.register(_type(&"grass"))
	assert_float(_world.types.factor(&"fire", [&"grass", &"steel"])).is_equal(2.0)
	assert_float(_world.types.factor(&"shadow", [&"grass"])).is_equal(1.0)
	assert_float(_world.types.factor(&"shadow", [&"grass"])).is_equal(1.0)
	assert_array(_world.logged).is_equal(["ERROR unknown type 'steel'", "ERROR unknown type 'shadow'"])
