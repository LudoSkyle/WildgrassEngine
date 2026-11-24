## Writes Ruby's Marshal data (4.8) for the tests: null, bools, ints,
## Strings (UTF-8), StringNames as symbols, Arrays, Dictionaries as hashes;
## a Dictionary with "class" is an object, its other keys its instance
## variables, or with "dumped" bytes, an object that dumps itself. An Array
## or a Dictionary met again is written as a link.
extends RefCounted

var _out := PackedByteArray()
var _symbols: Array[StringName] = []
var _objects: Array = []


static func bytes_of(value: Variant) -> PackedByteArray:
	var writer: RefCounted = load("res://tests/support/marshal_writer.gd").new()
	return writer.call("write", value)


func write(value: Variant) -> PackedByteArray:
	_out = PackedByteArray([4, 8])
	_symbols.clear()
	_objects.clear()
	_value(value)
	return _out


func _char(text: String) -> void:
	_out.append(text.unicode_at(0))


func _int(number: int) -> void:
	if number == 0:
		_out.append(0)
	elif number > 0 and number < 123:
		_out.append(number + 5)
	elif number < 0 and number > -124:
		_out.append((number - 5) & 0xff)
	else:
		var size := 1
		while size < 4 and (number >= (1 << (8 * size)) if number > 0 else number < -(1 << (8 * size))):
			size += 1
		_out.append(size if number > 0 else (256 - size))
		for k in size:
			_out.append((number >> (8 * k)) & 0xff)


func _raw(bytes: PackedByteArray) -> void:
	_int(bytes.size())
	_out.append_array(bytes)


func _symbol(name: StringName) -> void:
	var index := _symbols.find(name)
	if index >= 0:
		_char(";")
		_int(index)
		return
	_symbols.append(name)
	_char(":")
	_raw(String(name).to_utf8_buffer())


func _linked(value: Variant) -> bool:
	for index in _objects.size():
		if is_same(_objects[index], value):
			_char("@")
			_int(index)
			return true
	return false


func _value(value: Variant) -> void:
	match typeof(value):
		TYPE_NIL:
			_char("0")
		TYPE_BOOL:
			_char("T" if value else "F")
		TYPE_INT:
			if absi(value) < (1 << 30):
				_char("i")
				_int(value)
			else:
				_objects.append(null)
				_char("l")
				_char("-" if value < 0 else "+")
				var magnitude: int = absi(value)
				var words := 0
				while magnitude >> (16 * words) != 0:
					words += 1
				_int(words)
				for k in words * 2:
					_out.append((magnitude >> (8 * k)) & 0xff)
		TYPE_STRING:
			_objects.append(value)
			_char("I")
			_char("\"")
			_raw((value as String).to_utf8_buffer())
			_int(1)
			_symbol(&"E")
			_char("T")
		TYPE_STRING_NAME:
			_symbol(value)
		TYPE_ARRAY:
			if _linked(value):
				return
			_objects.append(value)
			_char("[")
			_int((value as Array).size())
			for item: Variant in value:
				_value(item)
		TYPE_DICTIONARY:
			if _linked(value):
				return
			_objects.append(value)
			var map: Dictionary = value
			if map.has("class") and map.has("dumped"):
				_char("u")
				_symbol(StringName(map["class"]))
				_raw(map["dumped"])
			elif map.has("class"):
				_char("o")
				_symbol(StringName(map["class"]))
				_int(map.size() - 1)
				for key: String in map:
					if key != "class":
						_symbol(StringName("@" + key))
						_value(map[key])
			else:
				_char("{")
				_int(map.size())
				for key: Variant in map:
					_value(key)
					_value(map[key])
