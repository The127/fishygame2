class_name TreasureHaul
extends RefCounted
## The treasures the fish found in one race, per viewer. Nothing is paid until [method settle],
## which the game calls when the race really ends.

## Most finders named in the result line.
const NAMED: int = 3

## user_id -> {"name": String, "count": int, "points": int}
var _entries: Dictionary = {}


func is_empty() -> bool:
	return _entries.is_empty()


func clear() -> void:
	_entries = {}


func add(user_id: String, display_name: String, value: int) -> void:
	var entry: Dictionary = _entries.get(user_id, {"name": display_name, "count": 0, "points": 0})
	entry["count"] = int(entry["count"]) + 1
	entry["points"] = int(entry["points"]) + value
	_entries[user_id] = entry


## Pays every finder, counts it in their stats and empties the haul. Returns the result-line
## text, "@a +50, @b +25" (biggest first, a few names), or "" when nothing was found.
## The caller saves the points.
func settle(points: PointsStore) -> String:
	var entries: Array[Dictionary] = []
	for user_id: String in _entries:
		var entry: Dictionary = _entries[user_id]
		points.add(user_id, int(entry["points"]))
		points.stats.record_treasure(user_id, int(entry["count"]), int(entry["points"]))
		entries.append(entry)
	_entries = {}
	entries.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return a["points"] > b["points"]
	)
	var parts: PackedStringArray = []
	for entry: Dictionary in entries.slice(0, NAMED):
		parts.append("@%s +%d" % [entry["name"], entry["points"]])
	if entries.size() > NAMED:
		parts.append("+%d more" % (entries.size() - NAMED))
	return ", ".join(parts)
