extends GdUnitTestSuite

# Ruby's Marshal data read into plain values: bytes the tests write.

const Reader := preload("res://addons/wildgrass/studio/marshal_reader.gd")
const Writer := preload("res://tests/support/marshal_writer.gd")


func _round_trip(value: Variant) -> Variant:
	var reader := Reader.new()
	var read: Variant = reader.read(Writer.bytes_of(value))
	assert_str(reader.error).is_empty()
	return read


func test_integers_small_large_and_negative_read_back() -> void:
	var numbers := [0, 1, 122, 123, 255, 256, 65535, 70000, -1, -123, -124, -256, -257, -70000, (1 << 30) - 1, 1 << 40, -(1 << 40)]
	assert_array(_round_trip(numbers)).is_equal(numbers)


func test_text_is_utf8_symbols_are_names_and_nil_and_bools_stay() -> void:
	assert_array(_round_trip(["§ Pokéball door", &"down", &"down", null, true, false])).is_equal(["§ Pokéball door", &"down", &"down", null, true, false])


func test_an_object_is_a_dictionary_of_its_class_and_fields_a_hash_keeps_its_keys() -> void:
	var event := {"class": "RPG::Event", "id": 3, "name": "Door", "pages": [{"class": "RPG::Event::Page", "trigger": 1}]}
	var events := {3: event, 7: null}
	var read: Dictionary = _round_trip(events)
	assert_dict(read[3]).is_equal(event)
	assert_bool(read.has(7)).is_true()


func test_an_object_met_twice_is_the_same_dictionary() -> void:
	var step := {"class": "RPG::MoveCommand", "code": 4, "parameters": []}
	var read: Array = _round_trip([{"class": "RPG::MoveRoute", "list": [step]}, step])
	assert_bool(is_same(read[0]["list"][0], read[1])).is_true()


func test_an_object_that_dumps_itself_keeps_its_bytes() -> void:
	var read: Dictionary = _round_trip({"class": "Table", "dumped": PackedByteArray([1, 0, 0, 0, 9])})
	assert_str(read["class"]).is_equal("Table")
	assert_array(Array(read["data"])).is_equal([1, 0, 0, 0, 9])


func test_what_is_not_marshal_data_or_ends_too_soon_is_an_error_and_null() -> void:
	var reader := Reader.new()
	assert_object(reader.read(PackedByteArray([1, 2, 3]))).is_null()
	assert_str(reader.error).is_equal("not Marshal data 4.8")
	var cut := Writer.bytes_of(["a long enough text"])
	assert_object(reader.read(cut.slice(0, 8))).is_null()
	assert_str(reader.error).contains("longer than the data")
	assert_object(reader.read(cut.slice(0, cut.size() - 1))).is_null()
	assert_str(reader.error).contains("data ends too soon")
	assert_object(reader.read(PackedByteArray([4, 8, "?".unicode_at(0)]))).is_null()
	assert_str(reader.error).contains("unknown kind")
	assert_object(reader.read_file("user://nowhere.rxdata")).is_null()
	assert_str(reader.error).contains("no file")
