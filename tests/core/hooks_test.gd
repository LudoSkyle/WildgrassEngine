extends GdUnitTestSuite

const Hooks := preload("res://addons/wildgrass/core/hooks/hooks.gd")

var _hooks: Hooks
var _calls: Array[String]


func before_test() -> void:
	_hooks = Hooks.new()
	_calls = []


func _record(label: String) -> Callable:
	return func(_arg: Variant = null) -> void: _calls.append(label)


func test_handlers_run_by_priority_then_in_insertion_order() -> void:
	_hooks.add(&"e", &"b", _record("b"))
	_hooks.add(&"e", &"late", _record("late"), 10)
	_hooks.add(&"e", &"early", _record("early"), -10)
	_hooks.add(&"e", &"c", _record("c"))
	_hooks.run(&"e")
	assert_array(_calls).is_equal(["early", "b", "c", "late"])


func test_run_passes_its_arguments() -> void:
	var received: Array = []
	_hooks.add(&"e", &"a", func(x: int, y: String) -> void: received.append_array([x, y]))
	_hooks.run(&"e", [1, "two"])
	assert_array(received).is_equal([1, "two"])


func test_adding_an_existing_name_replaces_the_handler_in_place() -> void:
	_hooks.add(&"e", &"a", _record("a"))
	_hooks.add(&"e", &"b", _record("b"))
	_hooks.add(&"e", &"a", _record("a2"))
	_hooks.run(&"e")
	assert_array(_calls).is_equal(["a2", "b"])


func test_a_replacement_can_change_the_priority() -> void:
	_hooks.add(&"e", &"a", _record("a"))
	_hooks.add(&"e", &"b", _record("b"))
	_hooks.add(&"e", &"a", _record("a"), 5)
	assert_array(_hooks.names(&"e")).is_equal([&"b", &"a"])


func test_remove_tells_whether_the_handler_existed() -> void:
	_hooks.add(&"e", &"a", _record("a"))
	assert_bool(_hooks.remove(&"e", &"a")).is_true()
	assert_bool(_hooks.remove(&"e", &"a")).is_false()
	assert_bool(_hooks.remove(&"other", &"a")).is_false()
	assert_bool(_hooks.has(&"e", &"a")).is_false()


func test_filter_passes_the_value_from_handler_to_handler() -> void:
	_hooks.add(&"rate", &"double", func(value: int, bonus: int) -> int: return value * 2 + bonus)
	_hooks.add(&"rate", &"minus", func(value: int, _bonus: int) -> int: return value - 1)
	assert_int(_hooks.filter(&"rate", 5, [1])).is_equal(10)


func test_an_event_without_handlers_does_nothing() -> void:
	_hooks.run(&"none")
	assert_int(_hooks.filter(&"none", 5)).is_equal(5)
	assert_array(_hooks.names(&"none")).is_empty()


func test_a_handler_whose_object_was_freed_is_dropped() -> void:
	var holder := Node.new()
	_hooks.add(&"e", &"gone", holder.queue_free)
	holder.free()
	_hooks.add(&"e", &"alive", _record("alive"))
	_hooks.run(&"e")
	assert_array(_calls).is_equal(["alive"])
	assert_array(_hooks.names(&"e")).is_equal([&"alive"])


func test_changes_made_while_running_apply_from_the_next_run() -> void:
	_hooks.add(&"e", &"a", func() -> void:
		_calls.append("a")
		_hooks.remove(&"e", &"b")
		_hooks.add(&"e", &"c", _record("c")))
	_hooks.add(&"e", &"b", _record("b"))
	_hooks.run(&"e")
	assert_array(_calls).is_equal(["a", "b"])
	_calls.clear()
	_hooks.run(&"e")
	assert_array(_calls).is_equal(["a", "c"])
