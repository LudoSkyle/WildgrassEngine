extends GdUnitTestSuite

const World := preload("res://tests/support/walking_world.gd")
const Options := preload("res://addons/wildgrass/options/options.gd")
const Log := preload("res://addons/wildgrass/core/log/log.gd")

var _world: World
var _applied: Array = []


func before_test() -> void:
	_world = World.new(self)
	_applied = []


func after_test() -> void:
	var bus := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_volume_db(bus, 0.0)
	AudioServer.set_bus_mute(bus, false)
	TranslationServer.set_locale("en")
	_world.root.free()
	_world.cleanup()


func _record(value: Variant) -> void:
	_applied.append(value)


func _auto_run(options: Options) -> bool:
	return options.add_option(&"auto_run", {"values": [false, true], "default": false, "apply": _record, "texts": ["Off", "On"]})


func _kept() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(_world.options.file_path))


func test_each_change_applies_and_is_kept_then_comes_back_on_the_next_launch() -> void:
	var changes: Array[String] = []
	_world.options.changed.connect(func(id: StringName, value: Variant) -> void: changes.append("%s %s" % [id, value]))
	_auto_run(_world.options)
	assert_bool(_world.options.value(&"auto_run")).is_false()
	assert_bool(_world.options.set_value(&"auto_run", true)).is_true()
	assert_that(_kept()).is_equal({"auto_run": true})
	assert_array(changes).is_equal(["auto_run true"])
	var next := Options.new(World.Paths.new(false), Log.new(), _world.config)
	next.file_path = _world.options.file_path
	next.read()
	_auto_run(next)
	assert_bool(next.value(&"auto_run")).is_true()
	assert_array(_applied).is_equal([false, true, true])


func test_wrong_options_and_values_are_refused_and_logged() -> void:
	var options := _world.options
	assert_bool(options.add_option(&"none", {"default": 1})).is_false()
	assert_bool(options.add_option(&"odd", {"values": [1, 2], "default": 3})).is_false()
	assert_bool(options.has_option(&"odd")).is_false()
	_auto_run(options)
	assert_bool(options.set_value(&"auto_run", 3)).is_false()
	assert_bool(options.set_value(&"nothing", 1)).is_false()
	assert_array(_world.logged).is_equal([
		"ERROR option 'none' needs values",
		"ERROR option 'odd': its default 3 is not among its values",
		"ERROR option 'auto_run': 3 is not among its values",
		"ERROR no option 'nothing'",
	])


func test_a_kept_value_no_longer_allowed_takes_the_default_and_unknown_ones_are_kept() -> void:
	_world.sandbox.write_json("options.json", {"auto_run": "maybe", "pokedex_sort": "name"})
	_world.options.read()
	_auto_run(_world.options)
	assert_bool(_world.options.value(&"auto_run")).is_false()
	_world.options.set_value(&"auto_run", true)
	assert_that(_kept()).is_equal({"auto_run": true, "pokedex_sort": "name"})
	_world.sandbox.write("options.json", "nope")
	_world.options.read()
	assert_array(_world.logged).is_equal([
		"WARN option 'auto_run': maybe is not among its values; using false",
		"ERROR options.json is not a JSON object; using the defaults",
	])


func test_the_config_orders_the_options_shown_skipping_unknown_ids_and_lone_values() -> void:
	_world.sandbox.write_json("config/options.json", {"order": ["volume", "battle_style", "auto_run", "message_frame", "message_speed", "language"]})
	_world.options.add_engine_options(_world.dialogue, _world.texts)
	_auto_run(_world.options)
	assert_array(_world.options.shown()).is_equal([&"volume", &"auto_run", &"message_speed"])
	assert_str(_world.texts.format(_world.options.option(&"volume")["name"])).is_equal("Volume")


func test_a_value_shows_its_text_else_its_format_else_itself() -> void:
	_world.options.add_engine_options(_world.dialogue, _world.texts)
	_auto_run(_world.options)
	_world.options.add_option(&"count", {"values": [1, 2], "default": 2})
	assert_str(_world.options.text_of(&"auto_run")).is_equal("Off")
	_world.options.set_value(&"volume", 35)
	assert_str(_world.options.text_of(&"volume")).is_equal("35%")
	assert_str(_world.options.text_of(&"count")).is_equal("2")
	assert_str(_world.texts.format(_world.options.text_of(&"message_speed"))).is_equal("Normal")


func test_the_engine_s_options_apply_to_the_dialogue_the_sound_and_the_language() -> void:
	_world.sandbox.write_json("config/dialogue.json", {"letters_per_second": 40, "frames": [{"style": "", "name": "Plain"}, {"style": "gold", "name": "Gold"}, {"name": "no style"}]})
	_world.sandbox.write_json("config/language.json", {"choosable": ["en", "fr"], "names": ["English", "Français"]})
	var options := _world.options
	options.add_engine_options(_world.dialogue, _world.texts)
	assert_float(_world.dialogue.letters_per_second).is_equal(40.0)
	options.set_value(&"message_speed", 1)
	assert_float(_world.dialogue.letters_per_second).is_equal(20.0)
	options.set_value(&"message_speed", 3)
	assert_float(_world.dialogue.letters_per_second).is_equal(80.0)
	assert_array(options.values_of(&"message_frame")).is_equal(["", "gold"])
	options.set_value(&"message_frame", "gold")
	assert_str(_world.dialogue.style).is_equal("gold")
	assert_str(options.text_of(&"message_frame")).is_equal("Gold")
	var bus := AudioServer.get_bus_index(&"Master")
	options.set_value(&"volume", 50)
	assert_float(AudioServer.get_bus_volume_db(bus)).is_equal_approx(linear_to_db(0.5), 0.01)
	assert_bool(AudioServer.is_bus_mute(bus)).is_false()
	options.set_value(&"volume", 0)
	assert_bool(AudioServer.is_bus_mute(bus)).is_true()
	options.set_value(&"language", "fr")
	assert_str(_world.texts.language).is_equal("fr")
	assert_str(options.text_of(&"language")).is_equal("Français")
	assert_array(options.shown()).is_equal([&"message_speed", &"message_frame", &"volume", &"language"])
	assert_array(_world.logged).is_equal(["WARN dialogue.json: frames: a frame needs a style, got {\"name\":\"no style\"}"])
