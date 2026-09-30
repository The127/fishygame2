class_name TrackCatalog
extends RefCounted
## The playable maps. Add an entry here to make a new track selectable: the entry holds the
## scene and the music, ambience and jingle files, and nothing else needs a per-map edit.

## Value of the "random" choice in map selection.
const RANDOM_ID: String = ""

const MAPS: Array[Dictionary] = [
	{
		"id": "zigzag",
		"name": "Zigzag",
		"scene": preload("res://scenes/tracks/test_track.tscn"),
		"music": "res://assets/audio/music_zigzag.wav",
		"ambience": "res://assets/audio/ambience_zigzag.wav",
		"jingle": "res://assets/audio/jingle_zigzag.wav",
	},
	{
		"id": "pachinko",
		"name": "Pachinko",
		"scene": preload("res://scenes/tracks/pachinko_track.tscn"),
		"music": "res://assets/audio/music_pachinko.wav",
		"ambience": "res://assets/audio/ambience_pachinko.wav",
		"jingle": "res://assets/audio/jingle_pachinko.wav",
	},
	{
		"id": "wreck",
		"name": "Shipwreck",
		"scene": preload("res://scenes/tracks/wreck_track.tscn"),
		"music": "res://assets/audio/music_wreck.wav",
		"ambience": "res://assets/audio/ambience_wreck.wav",
		"jingle": "res://assets/audio/jingle_wreck.wav",
	},
	{
		"id": "whirlpool",
		"name": "Whirlpool",
		"scene": preload("res://scenes/tracks/whirlpool_track.tscn"),
		"music": "res://assets/audio/music_whirlpool.wav",
		"ambience": "res://assets/audio/ambience_whirlpool.wav",
		"jingle": "res://assets/audio/jingle_whirlpool.wav",
	},
	{
		"id": "jelly",
		"name": "Jellyfish Field",
		"scene": preload("res://scenes/tracks/jelly_track.tscn"),
		"music": "res://assets/audio/music_jelly.wav",
		"ambience": "res://assets/audio/ambience_jelly.wav",
		"jingle": "res://assets/audio/jingle_jelly.wav",
	},
	{
		"id": "abyss",
		"name": "Abyss",
		"scene": preload("res://scenes/tracks/abyss_track.tscn"),
		"music": "res://assets/audio/music_abyss.wav",
		"ambience": "res://assets/audio/ambience_abyss.wav",
		"jingle": "res://assets/audio/jingle_abyss.wav",
	},
	{
		"id": "vents",
		"name": "Volcanic Vents",
		"scene": preload("res://scenes/tracks/vents_track.tscn"),
		"music": "res://assets/audio/music_vents.wav",
		"ambience": "res://assets/audio/ambience_vents.wav",
		"jingle": "res://assets/audio/jingle_vents.wav",
	},
	{
		"id": "cave",
		"name": "Crystal Cave",
		"scene": preload("res://scenes/tracks/cave_track.tscn"),
		"music": "res://assets/audio/music_cave.wav",
		"ambience": "res://assets/audio/ambience_cave.wav",
		"jingle": "res://assets/audio/jingle_cave.wav",
	},
	{
		"id": "garden",
		"name": "Coral Garden",
		"scene": preload("res://scenes/tracks/garden_track.tscn"),
		"music": "res://assets/audio/music_garden.wav",
		"ambience": "res://assets/audio/ambience_garden.wav",
		"jingle": "res://assets/audio/jingle_garden.wav",
	},
	{
		"id": "kraken",
		"name": "Kraken's Lair",
		"scene": preload("res://scenes/tracks/kraken_track.tscn"),
		"music": "res://assets/audio/music_kraken.wav",
		"ambience": "res://assets/audio/ambience_kraken.wav",
		"jingle": "res://assets/audio/jingle_kraken.wav",
	},
	{
		"id": "gravity",
		"name": "Gravity Flip",
		"scene": preload("res://scenes/tracks/gravity_track.tscn"),
		"music": "res://assets/audio/music_gravity.wav",
		"ambience": "res://assets/audio/ambience_gravity.wav",
		"jingle": "res://assets/audio/jingle_gravity.wav",
	},
	{
		"id": "tide",
		"name": "Ebb Tide",
		"scene": preload("res://scenes/tracks/tide_track.tscn"),
		"music": "res://assets/audio/music_tide.wav",
		"ambience": "res://assets/audio/ambience_tide.wav",
		"jingle": "res://assets/audio/jingle_tide.wav",
	},
	{
		"id": "fork",
		"name": "Fork Reef",
		"scene": preload("res://scenes/tracks/fork_track.tscn"),
		"music": "res://assets/audio/music_fork.wav",
		"ambience": "res://assets/audio/ambience_fork.wav",
		"jingle": "res://assets/audio/jingle_fork.wav",
	},
	{
		"id": "city",
		"name": "Sunken City",
		"scene": preload("res://scenes/tracks/city_track.tscn"),
		"music": "res://assets/audio/music_city.wav",
		"ambience": "res://assets/audio/ambience_city.wav",
		"jingle": "res://assets/audio/jingle_city.wav",
	},
	{
		"id": "washer",
		"name": "Washing Machine",
		"scene": preload("res://scenes/tracks/washer_track.tscn"),
		"music": "res://assets/audio/music_washer.wav",
		"ambience": "res://assets/audio/ambience_washer.wav",
		"jingle": "res://assets/audio/jingle_washer.wav",
	},
	{
		"id": "whale",
		"name": "Inside the Whale",
		"scene": preload("res://scenes/tracks/whale_track.tscn"),
		"music": "res://assets/audio/music_whale.wav",
		"ambience": "res://assets/audio/ambience_whale.wav",
		"jingle": "res://assets/audio/jingle_whale.wav",
	},
	{
		"id": "flush",
		"name": "Toilet Flush",
		"scene": preload("res://scenes/tracks/flush_track.tscn"),
		"music": "res://assets/audio/music_flush.wav",
		"ambience": "res://assets/audio/ambience_flush.wav",
		"jingle": "res://assets/audio/jingle_flush.wav",
	},
	{
		"id": "switchback",
		"name": "Switchback",
		"scene": preload("res://scenes/tracks/switchback_track.tscn"),
		"music": "res://assets/audio/music_switchback.wav",
		"ambience": "res://assets/audio/ambience_switchback.wav",
		"jingle": "res://assets/audio/jingle_switchback.wav",
	},
]


static func ids() -> PackedStringArray:
	var result: PackedStringArray = []
	for map: Dictionary in MAPS:
		result.append(String(map["id"]))
	return result


## Music theme file of a map, or "" for an unknown id.
static func music_path(id: String) -> String:
	return _field(id, "music")


## Looping sound bed file of a map, or "" for an unknown id.
static func ambience_path(id: String) -> String:
	return _field(id, "ambience")


## Podium jingle file of a map, or "" for an unknown id.
static func jingle_path(id: String) -> String:
	return _field(id, "jingle")


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


static func _field(id: String, key: String) -> String:
	for map: Dictionary in MAPS:
		if map["id"] == id:
			return String(map[key])
	return ""
