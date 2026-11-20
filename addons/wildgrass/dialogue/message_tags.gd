## Takes the engine's and the game's tags out of a message, leaving Godot's
## BBCode to the label.
extends RefCounted

## Tags the engine acts on itself.
const ENGINE_TAGS: Array[String] = ["page", "pause", "speed", "wait"]
## Tag names of Godot's BBCode: never taken by a game.
const BBCODE_TAGS: Array[String] = [
	"b", "i", "u", "s", "code", "char", "p", "br", "hr", "center", "left", "right", "fill",
	"indent", "url", "hint", "img", "font", "font_size", "opentype_features", "otf", "lang",
	"table", "cell", "ul", "ol", "lb", "rb", "lrm", "rlm", "lre", "rle", "lro", "rlo", "pdf",
	"alm", "lri", "rli", "fsi", "pdi", "zwj", "zwnj", "wj", "shy", "color", "bgcolor",
	"fgcolor", "outline_size", "outline_color", "dropcap", "wave", "tornado", "shake", "fade",
	"rainbow", "pulse",
]

static var _pattern: RegEx


## Returns `text`, the message without the tags of the engine and of
## `game_tags`; `tags`, each `{"index": in text, "name", "value"}`, in order;
## `unknown`, the names of tags that are neither those, BBCode, nor
## `effect_tags` (custom effects of the label). `[page]` leaves a line break.
static func split(message: String, game_tags: Array, effect_tags: Array) -> Dictionary:
	if _pattern == null:
		_pattern = RegEx.create_from_string("\\[(/?)(\\w+)([^\\]]*)\\]")
	var text := ""
	var tags: Array[Dictionary] = []
	var unknown := PackedStringArray()
	var from := 0
	for found: RegExMatch in _pattern.search_all(message):
		var tag_name := found.get_string(2)
		var ours := found.get_string(1).is_empty() and (tag_name in ENGINE_TAGS or tag_name in game_tags)
		if not ours:
			if tag_name not in BBCODE_TAGS and tag_name not in effect_tags and tag_name not in unknown:
				unknown.append(tag_name)
			continue
		text += message.substr(from, found.get_start() - from)
		from = found.get_end()
		var rest := found.get_string(3)
		if tag_name == "page" and not text.is_empty() and not text.ends_with("\n"):
			text += "\n"
		tags.append({"index": text.length(), "name": tag_name, "value": rest.substr(1) if rest.begins_with("=") else ""})
	text += message.substr(from)
	return {"text": text, "tags": tags, "unknown": unknown}
