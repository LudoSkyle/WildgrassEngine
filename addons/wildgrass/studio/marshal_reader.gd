## Reads Ruby's Marshal data (format 4.8), as Studio's RPG Maker files hold
## it, into plain values; it runs nothing. An object is a Dictionary, its
## class under "class" and each instance variable under its name without "@";
## an object that dumps itself (a Table, a Color) holds its bytes under
## "data". Strings are UTF-8 text, symbols StringNames, a nil null. The same
## object met twice is the same Dictionary or Array.
extends RefCounted

## The problem met, if `read` returned null.
var error := ""

var _bytes: PackedByteArray
var _at := 0
var _symbols: Array[StringName] = []
var _objects: Array = []


## The value in `bytes`, or null with `error` set.
func read(bytes: PackedByteArray) -> Variant:
	_bytes = bytes
	_at = 0
	_symbols.clear()
	_objects.clear()
	error = ""
	if bytes.size() < 2 or bytes[0] != 4 or bytes[1] != 8:
		error = "not Marshal data 4.8"
		return null
	_at = 2
	var value: Variant = _value()
	return null if not error.is_empty() else value


## The value in the file at `path`, or null with `error` set.
func read_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		error = "no file %s" % path
		return null
	var value: Variant = read(FileAccess.get_file_as_bytes(path))
	if not error.is_empty():
		error = "%s: %s" % [path.get_file(), error]
	return value


func _fail(message: String) -> Variant:
	if error.is_empty():
		error = "%s at byte %d" % [message, _at]
	_at = _bytes.size()
	return null


func _byte() -> int:
	if _at >= _bytes.size():
		_fail("data ends too soon")
		return 0
	_at += 1
	return _bytes[_at - 1]


## Marshal's packed integer.
func _int() -> int:
	var c := _byte()
	if c > 127:
		c -= 256
	if c == 0:
		return 0
	if c >= 5:
		return c - 5
	if c <= -5:
		return c + 5
	var result := 0
	if c > 0:
		for k in c:
			result |= _byte() << (8 * k)
		return result
	result = -1
	for k in -c:
		result &= ~(0xff << (8 * k))
		result |= _byte() << (8 * k)
	return result


func _raw() -> PackedByteArray:
	var size := _int()
	if size < 0 or _at + size > _bytes.size():
		_fail("a string longer than the data")
		return PackedByteArray()
	_at += size
	return _bytes.slice(_at - size, _at)


func _symbol() -> StringName:
	var kind := char(_byte())
	if kind == ":":
		var symbol := StringName(_raw().get_string_from_utf8())
		_symbols.append(symbol)
		return symbol
	if kind == ";":
		var index := _int()
		if index < 0 or index >= _symbols.size():
			_fail("an unknown symbol")
			return &""
		return _symbols[index]
	_fail("a symbol expected")
	return &""


func _keep(value: Variant) -> Variant:
	_objects.append(value)
	return value


func _value() -> Variant:
	if not error.is_empty():
		return null
	var kind := char(_byte())
	match kind:
		"0":
			return null
		"T":
			return true
		"F":
			return false
		"i":
			return _int()
		":", ";":
			_at -= 1
			return _symbol()
		"@":
			var index := _int()
			if index < 0 or index >= _objects.size():
				return _fail("a link to nothing")
			return _objects[index]
		"I":
			var wrapped: Variant = _value()
			for _k in _int():
				_symbol()
				_value()
			return wrapped
		"\"":
			return _keep(_raw().get_string_from_utf8())
		"f":
			var text := _raw().get_string_from_ascii()
			return _keep(INF if text == "inf" else -INF if text == "-inf" else NAN if text == "nan" else text.to_float())
		"l":
			var negative := char(_byte()) == "-"
			var size := _int() * 2
			var number := 0
			for k in size:
				var digit := _byte()
				if k < 8:
					number |= digit << (8 * k)
			return _keep(-number if negative else number)
		"[":
			var list: Array = _keep([])
			for _k in _int():
				list.append(_value())
			return list
		"{", "}":
			var map: Dictionary = _keep({})
			for _k in _int():
				var key: Variant = _value()
				map[key] = _value()
			if kind == "}":
				_value()
			return map
		"o", "S":
			var object: Dictionary = _keep({"class": String(_symbol())})
			for _k in _int():
				# Godot reads the value before the key: the name first.
				var field := String(_symbol()).trim_prefix("@")
				object[field] = _value()
			return object
		"u":
			var class_name_ := String(_symbol())
			return _keep({"class": class_name_, "data": _raw()})
		"U":
			var dumped: Dictionary = _keep({"class": String(_symbol())})
			dumped["data"] = _value()
			return dumped
		"e":
			_symbol()
			return _value()
		"c", "m", "M":
			return _keep({"class": "Class", "name": _raw().get_string_from_utf8()})
		"/":
			var source := _raw().get_string_from_utf8()
			_byte()
			return _keep(source)
	return _fail("an unknown kind '%s'" % kind)
