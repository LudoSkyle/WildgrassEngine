extends GdUnitTestSuite

const Paths := preload("res://addons/wildgrass/core/paths/paths.gd")
const Sandbox := preload("res://tests/support/sandbox.gd")

var _sandbox: Sandbox


func before_test() -> void:
	_sandbox = Sandbox.new()


func after_test() -> void:
	_sandbox.cleanup()


func test_resolve_uses_the_studio_folders_by_default() -> void:
	var paths := Paths.new(false)
	assert_str(paths.resolve(&"data", "configs/x.json")).is_equal("res://Data/configs/x.json")
	assert_str(paths.resolve(&"graphics", "a.png")).is_equal("res://graphics/a.png")
	assert_str(paths.resolve(&"audio", "a.ogg")).is_equal("res://audio/a.ogg")
	assert_str(paths.resolve(&"maps", "town.tscn")).is_equal("res://maps/town.tscn")
	assert_str(paths.resolve(&"saves", "Saves/game.json")).is_equal("user://Saves/game.json")


func test_resolve_follows_the_project_setting_with_or_without_trailing_slash() -> void:
	_sandbox.set_setting("wildgrass/paths/graphics", "res://art")
	assert_str(Paths.new(false).resolve(&"graphics", "a.png")).is_equal("res://art/a.png")
	_sandbox.set_setting("wildgrass/paths/graphics", "res://art/")
	assert_str(Paths.new(false).resolve(&"graphics", "a.png")).is_equal("res://art/a.png")


func test_resolve_ignores_a_leading_slash() -> void:
	assert_str(Paths.new(false).resolve(&"graphics", "/a.png")).is_equal("res://graphics/a.png")


func test_a_game_can_add_a_kind_of_folder_in_the_settings() -> void:
	_sandbox.set_setting("wildgrass/paths/cutscenes", "res://cutscenes/")
	assert_str(Paths.new(false).resolve(&"cutscenes", "intro.tscn")).is_equal("res://cutscenes/intro.tscn")


func test_an_unknown_kind_resolves_to_empty() -> void:
	assert_str(Paths.new(false).resolve(&"nope", "a.png")).is_empty()


func test_exists_finds_plain_files_only() -> void:
	var paths := Paths.new(false)
	var file := _sandbox.write("a.json", "{}")
	assert_bool(paths.exists(file)).is_true()
	assert_bool(paths.exists(_sandbox.root + "missing.json")).is_false()
	assert_bool(paths.exists("")).is_false()


func test_a_missing_asset_is_reported_once_per_path() -> void:
	var paths := Paths.new(false)
	var reports: Array[String] = []
	paths.asset_missing.connect(func(path: String, requester: String) -> void: reports.append("%s|%s" % [path, requester]))
	assert_bool(paths.report_missing("res://a.png", "Bag")).is_true()
	assert_bool(paths.report_missing("res://a.png", "Menu")).is_false()
	assert_bool(paths.report_missing("res://b.png", "Bag")).is_true()
	assert_array(reports).is_equal(["res://a.png|Bag", "res://b.png|Bag"])


func test_player_files_are_redirected_in_test_mode() -> void:
	assert_str(Paths.new(false).user_file("save_1.json")).is_equal("user://save_1.json")
	assert_str(Paths.new(true).user_file("save_1.json")).is_equal("user://test_save_1.json")
