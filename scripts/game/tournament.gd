class_name Tournament
extends RefCounted
## A run of races on maps the streamer picked, one per round. The points each racer earns in
## the races add up, and the final standings pay a podium bonus.

## Round counts the streamer can pick.
const ROUND_CHOICES: Array[int] = [2, 3, 5]
## The podium bonus is this many times the per-race placement reward of the same place.
const BONUS_FACTOR: int = 3

## One entry per round: a map id or TrackCatalog.RANDOM_ID, in play order. Repeats are fine.
var maps: PackedStringArray = []
## Rounds already played.
var rounds_done: int = 0

## user_id -> {"name": String, "points": int, "order": int}
var _scores: Dictionary = {}


func _init(p_maps: PackedStringArray = []) -> void:
	maps = p_maps


static func is_valid_round_count(count: int) -> bool:
	return ROUND_CHOICES.has(count)


func round_count() -> int:
	return maps.size()


## 1-based number of the round being played, or the last one once all are done.
func round_number() -> int:
	return mini(rounds_done + 1, round_count())


## Map choice of the round being played.
func current_map() -> String:
	if maps.is_empty():
		return TrackCatalog.RANDOM_ID
	return maps[mini(rounds_done, maps.size() - 1)]


func is_finished() -> bool:
	return rounds_done >= round_count()


func finish_round() -> void:
	rounds_done = mini(rounds_done + 1, round_count())


## Puts a racer on the standings with no points, so everyone who raced shows up.
func add_racer(user_id: String, display_name: String) -> void:
	add_points(user_id, display_name, 0)


func add_points(user_id: String, display_name: String, amount: int) -> void:
	var entry: Dictionary = _scores.get(
		user_id, {"name": display_name, "points": 0, "order": _scores.size()}
	)
	entry["name"] = display_name
	entry["points"] = int(entry["points"]) + amount
	_scores[user_id] = entry


func points_of(user_id: String) -> int:
	return int(_scores.get(user_id, {}).get("points", 0))


## Best first: {"user_id", "name", "points", "place"}. Ties go to whoever entered first.
func standings() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for user_id: String in _scores:
		var entry: Dictionary = _scores[user_id]
		(
			rows
			. append(
				{
					"user_id": user_id,
					"name": entry["name"],
					"points": int(entry["points"]),
					"order": int(entry["order"]),
				}
			)
		)
	rows.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if a["points"] != b["points"]:
				return a["points"] > b["points"]
			return a["order"] < b["order"]
	)
	for i: int in rows.size():
		rows[i].erase("order")
		rows[i]["place"] = i + 1
	return rows


## The podium of the final standings with its bonus: {"user_id", "name", "points", "place",
## "bonus"}. [param place_rewards] are the per-race rewards for 1st, 2nd, 3rd. Racers without
## points and places without a reward get no bonus and are left off.
func podium_bonuses(place_rewards: Array[int]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Dictionary in standings():
		var place: int = int(row["place"])
		if place > place_rewards.size():
			break
		var bonus: int = place_rewards[place - 1] * BONUS_FACTOR
		if int(row["points"]) <= 0 or bonus <= 0:
			continue
		row["bonus"] = bonus
		result.append(row)
	return result


## "@a 150, @b 100, @c 50" for the top [param count], or "" with no racers.
func standings_text(count: int = 3) -> String:
	var parts: PackedStringArray = []
	for row: Dictionary in standings().slice(0, count):
		parts.append("@%s %d" % [row["name"], row["points"]])
	return ", ".join(parts)
