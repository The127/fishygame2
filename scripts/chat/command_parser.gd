class_name CommandParser
extends RefCounted
## Parses chat text such as "#join red" into a command and arguments.

var prefix: String = "#"


func _init(p_prefix: String = "#") -> void:
	prefix = p_prefix


## Returns {"command": String (lowercase), "args": PackedStringArray}, or an
## empty Dictionary when the text is not a command.
func parse(text: String) -> Dictionary:
	var trimmed: String = text.strip_edges()
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
