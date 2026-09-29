class_name Leaderboard
extends RefCounted
## Text for the leaderboard, as chat replies. Rows come from PointsStore.top_by_points.

## Viewers listed by "#top".
const CHAT_ROWS: int = 5


## "Top 5: 1. Ann 2500 | 2. Bob 1800"; a hint when nobody is ranked yet.
static func chat_text(rows: Array[Dictionary]) -> String:
	if rows.is_empty():
		return "No scores yet, place a bet with #bet <name> <amount>."
	var parts: PackedStringArray = []
	for i: int in rows.size():
		parts.append("%d. %s %d" % [i + 1, rows[i]["name"], rows[i]["points"]])
	return "Top %d: %s" % [rows.size(), " | ".join(parts)]
