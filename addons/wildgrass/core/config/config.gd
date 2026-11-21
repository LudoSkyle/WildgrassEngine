## Base of every configuration. Its fields are its `@export` variables, read
## from a resource of its class or from a JSON object whose keys are their
## names.
class_name WgConfig
extends Resource


## Reads `data` into this config. Returns the problems found; a field with a
## problem keeps its current value.
func load_data(data: Dictionary, source: String) -> PackedStringArray:
	var problems := PackedStringArray()
	var fields := _fields()
	for key: Variant in data:
		var field := str(key)
		if not fields.has(field):
			problems.append("%s: unknown key '%s'" % [source, key])
			continue
		var info: Dictionary = fields[field]
		var where := "%s.%s" % [source, key]
		var current: Variant = get(field)
		if current is WgConfig:
			if data[key] is Dictionary:
				problems.append_array((current as WgConfig).load_data(data[key], where))
			else:
				problems.append("%s: expected an object" % where)
			continue
		var result := _convert(data[key], info, current, where)
		if result.has("error"):
			problems.append(result["error"])
		else:
			set(field, result["value"])
	for problem: String in _validate():
		problems.append("%s: %s" % [source, problem])
	return problems


## Takes from `own` every field that differs from `defaults`: a resource of
## the project, over what sources gave. Returns the problems found.
func take_from(own: WgConfig, defaults: WgConfig) -> PackedStringArray:
	for field: String in _fields():
		if own.get(field) != defaults.get(field):
			set(field, own.get(field))
	var problems := PackedStringArray()
	for problem: String in _validate():
		problems.append("%s: %s" % [own.resource_path.get_file(), problem])
	return problems


## Override to check values together; reset what is wrong and describe it.
func _validate() -> PackedStringArray:
	return PackedStringArray()


func _fields() -> Dictionary:
	var fields := {}
	for info: Dictionary in get_property_list():
		var usage: int = info["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_STORAGE:
			fields[info["name"]] = info
	return fields


## Returns {"value": converted} or {"error": message}.
static func _convert(value: Variant, info: Dictionary, current: Variant, where: String) -> Dictionary:
	var type: int = info["type"]
	if type == TYPE_INT and info["hint"] == PROPERTY_HINT_ENUM:
		return _convert_enum(value, info["hint_string"], where)
	return _convert_type(value, type, current, where)


static func _convert_type(value: Variant, type: int, current: Variant, where: String) -> Dictionary:
	match type:
		TYPE_BOOL:
			if value is bool:
				return {"value": value}
		TYPE_INT:
			if value is int or (value is float and is_equal_approx(value, roundf(value))):
				return {"value": int(value)}
		TYPE_FLOAT:
			if value is float or value is int:
				return {"value": float(value)}
		TYPE_STRING:
			if value is String:
				return {"value": value}
		TYPE_STRING_NAME:
			if value is String:
				return {"value": StringName(value)}
		TYPE_VECTOR2I, TYPE_VECTOR2:
			if value is Dictionary and value.size() == 2 and value.has("x") and value.has("y"):
				var axis_type := TYPE_INT if type == TYPE_VECTOR2I else TYPE_FLOAT
				var x := _convert_type(value["x"], axis_type, null, where)
				var y := _convert_type(value["y"], axis_type, null, where)
				if x.has("value") and y.has("value"):
					if type == TYPE_VECTOR2I:
						return {"value": Vector2i(x["value"], y["value"])}
					return {"value": Vector2(x["value"], y["value"])}
		TYPE_COLOR:
			if value is String and Color.html_is_valid(value):
				return {"value": Color.html(value)}
		TYPE_ARRAY:
			if value is Array:
				return _convert_array(value, current if current is Array else [], where)
		TYPE_DICTIONARY:
			# An element of an array has no current value: any dictionary.
			if value is Dictionary:
				return _convert_dictionary(value, current if current is Dictionary else {}, where)
	return {"error": "%s: expected %s, got %s" % [where, type_string(type), JSON.stringify(value)]}


static func _convert_enum(value: Variant, hint_string: String, where: String) -> Dictionary:
	var names := PackedStringArray()
	var next := 0
	for entry: String in hint_string.split(","):
		var parts := entry.split(":")
		var number := int(parts[1]) if parts.size() > 1 else next
		next = number + 1
		names.append(parts[0])
		if value is String and parts[0].to_snake_case() == (value as String).to_snake_case():
			return {"value": number}
	var expected := ", ".join(Array(names).map(func(name: String) -> String: return name.to_snake_case()))
	return {"error": "%s: expected one of %s, got %s" % [where, expected, JSON.stringify(value)]}


static func _convert_array(value: Array, current: Array, where: String) -> Dictionary:
	var result := current.duplicate()
	result.clear()
	var element_type := current.get_typed_builtin()
	for index in value.size():
		var converted := _convert_type(value[index], element_type, null, "%s[%d]" % [where, index]) if element_type != TYPE_NIL else {"value": value[index]}
		if converted.has("error"):
			return converted
		result.append(converted["value"])
	return {"value": result}


static func _convert_dictionary(value: Dictionary, current: Dictionary, where: String) -> Dictionary:
	var result := current.duplicate()
	result.clear()
	var key_type := current.get_typed_key_builtin()
	var value_type := current.get_typed_value_builtin()
	for key: Variant in value:
		var converted_key := _convert_type(key, key_type, null, where) if key_type != TYPE_NIL else {"value": key}
		if converted_key.has("error"):
			return converted_key
		var converted := _convert_type(value[key], value_type, null, "%s.%s" % [where, key]) if value_type != TYPE_NIL else {"value": value[key]}
		if converted.has("error"):
			return converted
		result[converted_key["value"]] = converted["value"]
	return {"value": result}
