class_name CommandParser
extends RefCounted
## Parses chat text such as "#join red" into a command and arguments.

## Characters that are treated as a plain space.
const SEPARATORS: PackedInt32Array = [
	0x09,
	0x0A,
	0x0B,
	0x0C,
	0x0D,
	0x85,
	0xA0,
	0x1680,
	0x2000,
	0x2001,
	0x2002,
	0x2003,
	0x2004,
	0x2005,
	0x2006,
	0x2007,
	0x2008,
	0x2009,
	0x200A,
	0x2028,
	0x2029,
	0x202F,
	0x205F,
	0x3000
]
## Invisible characters removed before parsing: zero-width space/joiners, word
## joiner, BOM, soft hyphen, and the 7TV tag character (U+E0000) that is
## appended to repeated messages.
const INVISIBLES: PackedInt32Array = [0xAD, 0x200B, 0x200C, 0x200D, 0x2060, 0xFEFF, 0xE0000]

var prefix: String = "#"


func _init(p_prefix: String = "#") -> void:
	prefix = p_prefix


## Returns {"command": String (lowercase), "args": PackedStringArray}, or an
## empty Dictionary when the text is not a command.
func parse(text: String) -> Dictionary:
	var trimmed: String = _normalize(text).strip_edges()
	if prefix.is_empty() or not trimmed.begins_with(prefix):
		return {}
	var rest: String = trimmed.substr(prefix.length())
	if rest.is_empty() or rest[0] == " ":
		return {}
	var parts: PackedStringArray = rest.split(" ", false)
	if parts.is_empty():
		return {}
	var args: PackedStringArray = parts.slice(1)
	return {"command": parts[0].to_lower(), "args": args}


## Maps unusual whitespace to spaces and drops invisible characters.
static func _normalize(text: String) -> String:
	var out: String = ""
	for i: int in text.length():
		var code: int = text.unicode_at(i)
		if INVISIBLES.has(code):
			continue
		out += " " if SEPARATORS.has(code) else text[i]
	return out
