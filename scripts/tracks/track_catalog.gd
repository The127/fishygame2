class_name TrackCatalog
extends RefCounted
## The playable maps. Add an entry here to make a new track selectable.

## Value of the "random" choice in map selection.
const RANDOM_ID: String = ""

const MAPS: Array[Dictionary] = [
	{
		"id": "zigzag",
		"name": "Zigzag",
		"scene": preload("res://scenes/tracks/test_track.tscn"),
	},
	{
		"id": "pachinko",
		"name": "Pachinko",
		"scene": preload("res://scenes/tracks/pachinko_track.tscn"),
	},
	{
		"id": "wreck",
		"name": "Shipwreck",
		"scene": preload("res://scenes/tracks/wreck_track.tscn"),
	},
	{
		"id": "whirlpool",
		"name": "Whirlpool",
		"scene": preload("res://scenes/tracks/whirlpool_track.tscn"),
	},
]


static func ids() -> PackedStringArray:
	var result: PackedStringArray = []
	for map: Dictionary in MAPS:
		result.append(String(map["id"]))
	return result


static func has_map(id: String) -> bool:
	return ids().has(id)


static func get_name_of(id: String) -> String:
	for map: Dictionary in MAPS:
		if map["id"] == id:
			return String(map["name"])
	return ""


static func instantiate(id: String) -> Track:
	for map: Dictionary in MAPS:
		if map["id"] == id:
			return (map["scene"] as PackedScene).instantiate() as Track
	return null


## Resolves a choice to a concrete map id: a known id is returned as is, anything else
## (including RANDOM_ID) picks at random. The map named in `avoid_id` is skipped when
## another one exists, so consecutive random races differ.
static func resolve(choice: String, rng: RandomNumberGenerator, avoid_id: String = "") -> String:
	if has_map(choice):
		return choice
	var candidates: PackedStringArray = ids()
	if candidates.size() > 1 and candidates.has(avoid_id):
		candidates.remove_at(candidates.find(avoid_id))
	return candidates[rng.randi_range(0, candidates.size() - 1)]
