class_name GameSettings
extends RefCounted
## Streamer-editable game rules, persisted as a ConfigFile (user:// is IndexedDB in the
## web export, so it survives reloads). Every value is clamped to its range on set and on
## load, so a hand-edited or corrupt file can never produce an unplayable game.

const DEFAULT_PATH: String = "user://settings.cfg"
const SECTION: String = "game"
## Value of [member default_map] for a random map.
const RANDOM_MAP: String = TrackCatalog.RANDOM_ID

## Yes/no settings for which confirmations the game posts in chat, in the order the
## settings screen shows them. Each only applies while [member chat_replies] is on.
const CHAT_TOGGLES: Array[Dictionary] = [
	{"key": "reply_joins", "label": "Confirm #join"},
	{"key": "reply_bets", "label": "Confirm #bet and #pick"},
	{"key": "reply_chaos", "label": "Confirm #boost and #curse"},
	{"key": "reply_shop", "label": "Confirm #fish, #color and #hat"},
	{"key": "reply_results", "label": "Announce race results"},
	{"key": "reply_powers", "label": "Announce streamer powers"},
]

## Values of [member finish_replay].
const REPLAY_OFF: int = 0
const REPLAY_CLOSE: int = 1
const REPLAY_ALWAYS: int = 2

## Numeric settings, in the order the settings screen shows them. "max" of max_players is
## what the maps are tested with. max_bet 0 means no limit.
const FIELDS: Array[Dictionary] = [
	{"key": "min_players", "label": "Min players", "min": 1, "max": 20, "step": 1},
	{"key": "max_players", "label": "Max players", "min": 1, "max": 20, "step": 1},
	{"key": "countdown_seconds", "label": "Countdown (s)", "min": 0, "max": 30, "step": 1},
	{
		"key": "race_time_limit",
		"label": "Race time limit (s, 0 = none)",
		"min": 0,
		"max": 90,
		"step": 5
	},
	{
		"key": "auto_join_seconds",
		"label": "Auto mode join window (s)",
		"min": 5,
		"max": 600,
		"step": 5
	},
	{
		"key": "finish_replay",
		"label": "Finish replay (0 off, 1 close, 2 all)",
		"min": 0,
		"max": 2,
		"step": 1
	},
	{"key": "starting_balance", "label": "Starting points", "min": 0, "max": 1000000, "step": 100},
	{"key": "min_bet", "label": "Min bet", "min": 1, "max": 1000000, "step": 10},
	{"key": "max_bet", "label": "Max bet (0 = no limit)", "min": 0, "max": 1000000, "step": 100},
	{"key": "pick_reward", "label": "Free pick reward", "min": 0, "max": 1000000, "step": 10},
	{"key": "win_reward", "label": "1st place reward", "min": 0, "max": 1000000, "step": 10},
	{"key": "second_reward", "label": "2nd place reward", "min": 0, "max": 1000000, "step": 10},
	{"key": "third_reward", "label": "3rd place reward", "min": 0, "max": 1000000, "step": 10},
	{"key": "boost_cost", "label": "Boost cost", "min": 0, "max": 1000000, "step": 10},
	{"key": "curse_cost", "label": "Curse cost", "min": 0, "max": 1000000, "step": 10},
	{"key": "species_price", "label": "Fish species price", "min": 0, "max": 1000000, "step": 50},
	{"key": "color_price", "label": "Fish color price", "min": 0, "max": 1000000, "step": 50},
	{"key": "hat_price", "label": "Fish accessory price", "min": 0, "max": 1000000, "step": 50},
	{"key": "viewer_cooldown", "label": "Viewer cooldown (s)", "min": 0, "max": 600, "step": 1},
	{"key": "fish_lockout", "label": "Fish lockout (s)", "min": 0, "max": 60, "step": 1},
	{"key": "hazard_frequency", "label": "Hazard frequency (1-5)", "min": 1, "max": 5, "step": 1},
	{
		"key": "power_cooldown",
		"label": "Streamer power cooldown (s)",
		"min": 0,
		"max": 120,
		"step": 1
	},
	{"key": "powers_per_race", "label": "Streamer powers per race", "min": 1, "max": 20, "step": 1},
	{"key": "pad_left", "label": "Blocked left (%)", "min": 0, "max": 40, "step": 1},
	{"key": "pad_right", "label": "Blocked right (%)", "min": 0, "max": 40, "step": 1},
	{"key": "pad_top", "label": "Blocked top (%)", "min": 0, "max": 40, "step": 1},
	{"key": "pad_bottom", "label": "Blocked bottom (%)", "min": 0, "max": 40, "step": 1},
	{
		"key": "cheer_strength",
		"label": "Cheer strength (%, 0 = off)",
		"min": 0,
		"max": 500,
		"step": 10
	},
	{
		"key": "cheer_viewer_cooldown",
		"label": "Cheer viewer cooldown (s)",
		"min": 0,
		"max": 600,
		"step": 1
	},
	{
		"key": "cheer_fish_cooldown",
		"label": "Cheer fish cooldown (s)",
		"min": 0,
		"max": 60,
		"step": 1
	},
	{
		"key": "cheer_max_emotes",
		"label": "Cheer max emotes counted",
		"min": 1,
		"max": 20,
		"step": 1
	},
]

var min_players: int = 1
var max_players: int = 20
var countdown_seconds: int = 3
## Seconds a race may last before unfinished fish are DNF. 0 means no limit.
var race_time_limit: int = 60
var auto_join_seconds: int = 60
## Replay of the finish before the podium: REPLAY_OFF, REPLAY_CLOSE or REPLAY_ALWAYS.
var finish_replay: int = 1
var starting_balance: int = 1000
var min_bet: int = 1
var max_bet: int = 0
var pick_reward: int = 50
var win_reward: int = 100
var second_reward: int = 50
var third_reward: int = 25
var boost_cost: int = 100
var curse_cost: int = 150
var species_price: int = 500
var color_price: int = 250
var hat_price: int = 200
var viewer_cooldown: int = 20
var fish_lockout: int = 5
## How often a map's hazard events strike, 1 (rare) to 5 (constant).
var hazard_frequency: int = 3
## Screen edges kept free for the streamer's own overlays, in percent of the screen.
var pad_left: int = 0
var pad_right: int = 0
var pad_top: int = 0
var pad_bottom: int = 0
var power_cooldown: int = 8
var powers_per_race: int = 6
var cheer_strength: int = 100
var cheer_viewer_cooldown: int = 10
var cheer_fish_cooldown: int = 2
var cheer_max_emotes: int = 5
## A TrackCatalog id, or RANDOM_MAP.
var default_map: String = RANDOM_MAP
## Whether the game cycles lobby, race and podium on its own. Off by default.
var auto_mode: bool = false
## Whether the game answers in chat at all (rejections, #help, #top, and the confirmations
## below).
var chat_replies: bool = true
var reply_joins: bool = true
var reply_bets: bool = true
var reply_chaos: bool = true
var reply_shop: bool = true
var reply_results: bool = true
var reply_powers: bool = true
## Whether fish wear the colorblind palette and a marking each (see [FishPalette]).
var colorblind: bool = false
## Whether a viewer's first race comes with a free random hat.
var welcome_hat: bool = true
## Whether the streamer can use their own powers (rod, net, bubble blast) during a race.
var powers_enabled: bool = true
## Whether maps run their hazard events (currents, eels, collapsing planks).
var hazards_enabled: bool = true
## Whether treasures lie on the maps for the fish to collect.
var treasures_enabled: bool = true
## Whether a wheel is spun before every race, landing on a modifier now and then (see
## [RaceEvent]).
var random_events: bool = false
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
	set(key, roundi(clampf(value, float(field["min"]), float(field["max"]))))
	return true


## The part of the screen the game may use, as fractions of the screen size. Opposite
## paddings add up to at most 80%, so at least a fifth of each axis stays.
func play_fraction() -> Rect2:
	return Rect2(
		float(pad_left) / 100.0,
		float(pad_top) / 100.0,
		1.0 - float(pad_left + pad_right) / 100.0,
		1.0 - float(pad_top + pad_bottom) / 100.0
	)


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
	for toggle: Dictionary in CHAT_TOGGLES:
		var key: String = toggle["key"]
		set(key, fresh.get(key))
	auto_mode = fresh.auto_mode
	colorblind = fresh.colorblind
	welcome_hat = fresh.welcome_hat
	hazards_enabled = fresh.hazards_enabled
	powers_enabled = fresh.powers_enabled
	treasures_enabled = fresh.treasures_enabled
	random_events = fresh.random_events


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
	for toggle: Dictionary in CHAT_TOGGLES:
		var key: String = toggle["key"]
		var value: Variant = file.get_value(SECTION, key, get(key))
		if value is bool:
			set(key, value)
	var auto: Variant = file.get_value(SECTION, "auto_mode", auto_mode)
	if auto is bool:
		auto_mode = auto
	var blind: Variant = file.get_value(SECTION, "colorblind", colorblind)
	if blind is bool:
		colorblind = blind
	var welcome: Variant = file.get_value(SECTION, "welcome_hat", welcome_hat)
	if welcome is bool:
		welcome_hat = welcome
	var hazards: Variant = file.get_value(SECTION, "hazards_enabled", hazards_enabled)
	if hazards is bool:
		hazards_enabled = hazards
	var powers: Variant = file.get_value(SECTION, "powers_enabled", powers_enabled)
	if powers is bool:
		powers_enabled = powers
	var treasures: Variant = file.get_value(SECTION, "treasures_enabled", treasures_enabled)
	if treasures is bool:
		treasures_enabled = treasures
	var events: Variant = file.get_value(SECTION, "random_events", random_events)
	if events is bool:
		random_events = events
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
	for toggle: Dictionary in CHAT_TOGGLES:
		var key: String = toggle["key"]
		file.set_value(SECTION, key, get(key))
	file.set_value(SECTION, "auto_mode", auto_mode)
	file.set_value(SECTION, "colorblind", colorblind)
	file.set_value(SECTION, "welcome_hat", welcome_hat)
	file.set_value(SECTION, "hazards_enabled", hazards_enabled)
	file.set_value(SECTION, "powers_enabled", powers_enabled)
	file.set_value(SECTION, "treasures_enabled", treasures_enabled)
	file.set_value(SECTION, "random_events", random_events)
	return file.save(save_path) == OK


## The frequency to hand to a race: 0 when hazards are off.
func hazard_level() -> int:
	return hazard_frequency if hazards_enabled else 0


## The countdown length to run, in seconds. Random events stretch a short one so the wheel
## has time to spin.
func effective_countdown() -> int:
	return maxi(countdown_seconds, RaceEvent.MIN_COUNTDOWN) if random_events else countdown_seconds


## Whether the confirmation toggled by [param key] (one of [constant CHAT_TOGGLES]) should
## be posted: needs both the master switch and its own toggle.
func replies_enabled(key: String) -> bool:
	return chat_replies and bool(get(key))


static func field_of(key: String) -> Dictionary:
	for field: Dictionary in FIELDS:
		if field["key"] == key:
			return field
	return {}
