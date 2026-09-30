class_name ViewerStats
extends RefCounted
## Per-viewer lifetime counters behind the "#stats" chat command, keyed by Twitch user id.
## Saved inside the points file (see PointsStore), so it shares that file's atomic writes,
## backup and localStorage mirror. Race wins live in PointsStore and are passed in for display.

## Counters are clamped to this so they can never overflow a 64-bit int.
const MAX_VALUE: int = 1_000_000_000_000
## Most maps with a best time kept per viewer.
const MAX_MAPS: int = 64
## Longest map id kept as a key.
const MAX_MAP_ID_LENGTH: int = 64
## Counters stored as plain non-negative integers.
const COUNTERS: PackedStringArray = [
	"races",
	"podiums",
	"dnfs",
	"bets_won",
	"bets_lost",
	"boosts",
	"curses",
	"eaten",
	"treasures",
	"treasure_points"
]

## user_id -> {counters..., "bet_net": int, "best_times": {map_id: seconds}}
var _data: Dictionary = {}


func is_empty() -> bool:
	return _data.is_empty()


func user_ids() -> Array[String]:
	var ids: Array[String] = []
	for user_id: String in _data:
		ids.append(user_id)
	return ids


func has_stats(user_id: String) -> bool:
	return _data.has(user_id)


func get_counter(user_id: String, key: String) -> int:
	return int(_row(user_id).get(key, 0))


## Net points won (positive) or lost (negative) on bets, refunds excluded.
func get_bet_net(user_id: String) -> int:
	return int(_row(user_id).get("bet_net", 0))


## Seconds of the viewer's fastest finish on the map, or 0.0 if they never finished there.
func get_best_time(user_id: String, map_id: String) -> float:
	var times: Variant = _row(user_id).get("best_times", {})
	return float((times as Dictionary).get(map_id, 0.0)) if times is Dictionary else 0.0


## The fastest finish over all maps: {map_id, time}, or an empty dictionary.
func get_fastest(user_id: String) -> Dictionary:
	var times: Variant = _row(user_id).get("best_times", {})
	var best: Dictionary = {}
	if not times is Dictionary:
		return best
	for map_id: String in times:
		var time: float = float(times[map_id])
		if (
			best.is_empty()
			or time < float(best["time"])
			or (is_equal_approx(time, float(best["time"])) and map_id < str(best["map_id"]))
		):
			best = {"map_id": map_id, "time": time}
	return best


## A race the viewer took part in ran to its end.
func record_race(user_id: String) -> void:
	_bump(user_id, "races")


## The viewer finished in the top three.
func record_podium(user_id: String) -> void:
	_bump(user_id, "podiums")


## Keeps the time only if it beats the viewer's best on that map. Returns true if it did.
func record_finish_time(user_id: String, map_id: String, seconds: float) -> bool:
	if map_id.is_empty() or map_id.length() > MAX_MAP_ID_LENGTH:
		return false
	if not is_finite(seconds) or seconds <= 0.0:
		return false
	var times: Dictionary = _best_times(user_id)
	var old: float = float(times.get(map_id, 0.0))
	if old > 0.0 and seconds >= old:
		return false
	if not times.has(map_id) and times.size() >= MAX_MAPS:
		return false
	times[map_id] = seconds
	return true


## A settled bet: [param payout] is 0 for a lost bet. A win of only the stake back counts
## as won with no net change.
func record_bet(user_id: String, amount: int, payout: int) -> void:
	_bump(user_id, "bets_won" if payout > 0 else "bets_lost")
	var row: Dictionary = _ensure(user_id)
	row["bet_net"] = clampi(int(row.get("bet_net", 0)) + payout - amount, -MAX_VALUE, MAX_VALUE)


## The viewer's fish did not finish the race (time ran out). The race itself is counted
## by [method record_race].
func record_dnf(user_id: String) -> void:
	_bump(user_id, "dnfs")


func record_boost(user_id: String) -> void:
	_bump(user_id, "boosts")


func record_curse(user_id: String) -> void:
	_bump(user_id, "curses")


## The viewer's fish was eaten (by an Abyss anglerfish).
func record_eaten(user_id: String) -> void:
	_bump(user_id, "eaten")


## The viewer's fish collected `count` treasures worth `points` in total.
func record_treasure(user_id: String, count: int, points: int) -> void:
	var row: Dictionary = _ensure(user_id)
	row["treasures"] = clampi(int(row.get("treasures", 0)) + count, 0, MAX_VALUE)
	row["treasure_points"] = clampi(int(row.get("treasure_points", 0)) + points, 0, MAX_VALUE)


func to_dict() -> Dictionary:
	return _data


## Replaces the contents with [param raw] (as loaded from disk), dropping anything invalid.
## Bad entries are skipped one by one so a damaged row only loses that row.
func load_dict(raw: Variant) -> void:
	_data = {}
	if not raw is Dictionary:
		return
	for user_id: Variant in raw:
		var row: Variant = raw[user_id]
		if not row is Dictionary:
			continue
		var cleaned: Dictionary = _clean_row(row)
		if not cleaned.is_empty():
			_data[str(user_id)] = cleaned


func _row(user_id: String) -> Dictionary:
	var row: Variant = _data.get(user_id, {})
	return row if row is Dictionary else {}


func _ensure(user_id: String) -> Dictionary:
	if not _data.has(user_id):
		_data[user_id] = {}
	return _data[user_id]


func _best_times(user_id: String) -> Dictionary:
	var row: Dictionary = _ensure(user_id)
	if not row.get("best_times") is Dictionary:
		row["best_times"] = {}
	return row["best_times"]


func _bump(user_id: String, key: String) -> void:
	var row: Dictionary = _ensure(user_id)
	row[key] = mini(int(row.get(key, 0)) + 1, MAX_VALUE)


func _clean_row(raw: Dictionary) -> Dictionary:
	var row: Dictionary = {}
	for key: String in COUNTERS:
		var value: Variant = raw.get(key)
		if _is_number(value) and float(value) > 0.0:
			row[key] = mini(int(clampf(float(value), 0.0, float(MAX_VALUE))), MAX_VALUE)
	var net: Variant = raw.get("bet_net")
	if _is_number(net) and float(net) != 0.0:
		row["bet_net"] = clampi(
			int(clampf(float(net), -float(MAX_VALUE), float(MAX_VALUE))), -MAX_VALUE, MAX_VALUE
		)
	var times: Variant = raw.get("best_times")
	if times is Dictionary:
		var kept: Dictionary = {}
		for map_id: Variant in times:
			var seconds: Variant = times[map_id]
			if (
				kept.size() < MAX_MAPS
				and str(map_id).length() <= MAX_MAP_ID_LENGTH
				and _is_number(seconds)
				and float(seconds) > 0.0
			):
				kept[str(map_id)] = float(seconds)
		if not kept.is_empty():
			row["best_times"] = kept
	return row


func _is_number(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value))
