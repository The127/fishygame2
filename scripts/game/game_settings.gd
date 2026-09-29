class_name GameSettings
extends RefCounted
## Streamer-editable game rules, persisted as a ConfigFile (user:// is IndexedDB in the
## web export, so it survives reloads). Every value is clamped to its range on set and on
## load, so a hand-edited or corrupt file can never produce an unplayable game.

const DEFAULT_PATH: String = "user://settings.cfg"
const SECTION: String = "game"
## Value of [member default_map] for a random map.
const RANDOM_MAP: String = TrackCatalog.RANDOM_ID

## Numeric settings, in the order the settings screen shows them. "max" of max_players is
## what the maps are tested with. max_bet 0 means no limit.
const FIELDS: Array[Dictionary] = [
	{"key": "min_players", "label": "Min players", "min": 1, "max": 20, "step": 1},
	{"key": "max_players", "label": "Max players", "min": 1, "max": 20, "step": 1},
	{"key": "countdown_seconds", "label": "Countdown (s)", "min": 0, "max": 30, "step": 1},
	{"key": "starting_balance", "label": "Starting points", "min": 0, "max": 1000000, "step": 100},
	{"key": "min_bet", "label": "Min bet", "min": 1, "max": 1000000, "step": 10},
	{"key": "max_bet", "label": "Max bet (0 = no limit)", "min": 0, "max": 1000000, "step": 100},
	{"key": "boost_cost", "label": "Boost cost", "min": 0, "max": 1000000, "step": 10},
	{"key": "curse_cost", "label": "Curse cost", "min": 0, "max": 1000000, "step": 10},
	{"key": "viewer_cooldown", "label": "Viewer cooldown (s)", "min": 0, "max": 600, "step": 1},
	{"key": "fish_lockout", "label": "Fish lockout (s)", "min": 0, "max": 60, "step": 1},
]

var min_players: int = 1
var max_players: int = 20
var countdown_seconds: int = 3
var starting_balance: int = 1000
var min_bet: int = 1
var max_bet: int = 0
var boost_cost: int = 100
var curse_cost: int = 150
var viewer_cooldown: int = 20
var fish_lockout: int = 5
## A TrackCatalog id, or RANDOM_MAP.
var default_map: String = RANDOM_MAP
## Whether the game answers in chat (join rejections).
var chat_replies: bool = true
## Empty means in-memory only.
var save_path: String = ""


func _init(p_save_path: String = "") -> void:
	save_path = p_save_path


## Sets one numeric setting by key, clamped to its range. Returns false for an unknown key.
## Call [method sanitize] afterwards if the cross-field rules matter to the caller.
func set_number(key: String, value: float) -> bool:
	var field: Dictionary = field_of(key)
	if field.is_empty() or not is_finite(value):
		return false
	set(key, clampi(roundi(value), int(field["min"]), int(field["max"])))
	return true


## Enforces the rules between settings: min_players <= max_players, and min_bet <= max_bet
## when max_bet is limited. The lower bound wins, so a raised minimum pushes its maximum up.
## Also replaces an unknown default map with random.
func sanitize() -> void:
	max_players = maxi(max_players, min_players)
	if max_bet > 0:
		max_bet = maxi(max_bet, min_bet)
	if default_map != RANDOM_MAP and not TrackCatalog.has_map(default_map):
		default_map = RANDOM_MAP


func reset_to_defaults() -> void:
	var fresh := GameSettings.new()
	for field: Dictionary in FIELDS:
		var key: String = field["key"]
		set(key, fresh.get(key))
	default_map = fresh.default_map
	chat_replies = fresh.chat_replies


## Loads the saved values; missing or malformed ones keep their current value.
func load_settings() -> void:
	if save_path == "":
		return
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return
	for field: Dictionary in FIELDS:
		var key: String = field["key"]
		var value: Variant = file.get_value(SECTION, key, "")
		if value is int or value is float:
			set_number(key, float(value))
	var map: Variant = file.get_value(SECTION, "default_map", default_map)
	if map is String:
		default_map = map
	var replies: Variant = file.get_value(SECTION, "chat_replies", chat_replies)
	if replies is bool:
		chat_replies = replies
	sanitize()


## Writes the values. Returns false when there is no path or the write failed.
func save() -> bool:
	if save_path == "":
		return false
	var file := ConfigFile.new()
	for field: Dictionary in FIELDS:
		var key: String = field["key"]
		file.set_value(SECTION, key, get(key))
	file.set_value(SECTION, "default_map", default_map)
	file.set_value(SECTION, "chat_replies", chat_replies)
	return file.save(save_path) == OK


static func field_of(key: String) -> Dictionary:
	for field: Dictionary in FIELDS:
		if field["key"] == key:
			return field
	return {}
