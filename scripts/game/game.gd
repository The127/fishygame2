class_name Game
extends Node2D
## Wires chat commands, the round state machine, the race and the UI together.

## Milliseconds before the same viewer gets another rejection reply.
const REPLY_COOLDOWN_MSEC: int = 15000

const BET_REJECTIONS: Dictionary = {
	"closed": "betting is closed",
	"usage": "use #bet <name> <amount>",
	"already_bet": "you already bet this round",
	"unknown_fish": "no such racer",
	"invalid_amount": "invalid amount",
	"below_min": "bet is below the minimum",
	"above_max": "bet is above the maximum",
	"insufficient": "not enough points",
}

const SHOP_REJECTIONS: Dictionary = {
	"usage": "use #fish <species> or #color <name>, see #shop",
	"unknown_species": "no such species, see #shop",
	"unknown_color": "no such color, see #shop",
	"insufficient": "not enough points",
}

const CHAOS_REJECTIONS: Dictionary = {
	"closed": "chaos only works during a race",
	"usage": "use #boost <name> or #curse <name>",
	"unknown_fish": "no such racer",
	"finished": "that fish already finished",
	"cooldown": "you have to wait before another one",
	"fish_busy": "that fish was just hit, try again shortly",
	"insufficient": "not enough points",
}

## Milliseconds between "#top" replies in chat, shared by everyone.
const TOP_COOLDOWN_MSEC: int = 30000

## Commands that put a viewer on the leaderboard, so their name is remembered.
const NAMED_COMMANDS: PackedStringArray = [
	"join", "bet", "boost", "curse", "points", "fish", "color", "shop"
]

## The streamer's rules. Loaded from storage in _ready unless a caller sets it first.
var settings: GameSettings = null

var _last_reply_msec: Dictionary[String, int] = {}
var _last_top_msec: int = -TOP_COOLDOWN_MSEC

var _map_choice: String = TrackCatalog.RANDOM_ID
var _map_id: String = ""
var _track: Track
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _photo: PhotoFinish = PhotoFinish.new()

@onready var _flow: GameFlow = $GameFlow
@onready var _betting: Betting = $Betting
@onready var _chaos: Chaos = $Chaos
@onready var _shop: Shop = $Shop
@onready var _cheer: Cheer = $Cheer
@onready var _race: Race = $Race
@onready var _camera: RaceCamera = $RaceCamera
@onready var _overlay: Overlay = $Overlay
@onready var _panel: ControlPanel = $ControlPanel


func _ready() -> void:
	if settings == null:
		settings = GameSettings.new(GameSettings.DEFAULT_PATH)
		settings.load_settings()
	_apply_settings()
	# First, so the name is stored before a bet or effect saves the points.
	Chat.command_received.connect(_remember_name)
	Chat.command_received.connect(_flow.handle_command)
	Chat.command_received.connect(_betting.handle_command)
	Chat.command_received.connect(_chaos.handle_command)
	Chat.command_received.connect(_on_command)
	Chat.command_received.connect(_shop.handle_command)
	_chaos.points = _betting.points
	_shop.points = _betting.points
	_shop.equipped.connect(_on_shop_equipped)
	_shop.rejected.connect(_on_shop_rejected)
	_shop.catalog_requested.connect(_on_shop_catalog_requested)
	_flow.state_changed.connect(_on_state_changed)
	_flow.player_joined.connect(_on_player_joined)
	_flow.join_rejected.connect(_on_join_rejected)
	_flow.countdown_tick.connect(_overlay.show_countdown)
	_flow.race_started.connect(_on_race_started)
	_flow.player_joined.connect(_betting.add_contestant)
	_flow.state_changed.connect(_betting.on_state_changed)
	_flow.player_joined.connect(_chaos.add_contestant)
	_flow.state_changed.connect(_chaos.on_state_changed)
	_chaos.effect_requested.connect(_on_effect_requested)
	_chaos.effect_applied.connect(_on_effect_applied)
	_chaos.effect_rejected.connect(_on_effect_rejected)
	Chat.message_received.connect(_cheer.handle_message)
	_flow.player_joined.connect(_cheer.add_contestant)
	_flow.state_changed.connect(_cheer.on_state_changed)
	_cheer.cheer_requested.connect(_race.cheer_marble)
	_race.marble_finished.connect(_chaos.on_marble_finished)
	_race.marble_finished.connect(_cheer.on_marble_finished)
	# Before the flow's connection below, so chaos closes before the state changes.
	_race.race_finished.connect(_chaos.on_race_finished)
	_race.race_finished.connect(_cheer.on_race_finished)
	_flow.podium_ready.connect(_overlay.show_podium)
	_flow.podium_ready.connect(_betting.on_podium_ready)
	_betting.bets_changed.connect(_overlay.show_bets)
	_betting.payouts_settled.connect(_overlay.show_payouts)
	_betting.bet_placed.connect(_on_bet_placed)
	_betting.bet_rejected.connect(_on_bet_rejected)
	_betting.balance_reported.connect(_on_balance_reported)
	_race.race_finished.connect(_flow.report_race_finished)
	_panel.open_lobby_pressed.connect(_flow.open_lobby)
	_panel.start_pressed.connect(_flow.start_race)
	_panel.stop_pressed.connect(_flow.stop)
	_panel.add_debug_players_pressed.connect(_flow.add_debug_players)
	_panel.map_selected.connect(_on_map_selected)
	_panel.auto_mode_toggled.connect(_on_auto_mode_toggled)
	_panel.volume_changed.connect(Sound.set_volume)
	_panel.mute_toggled.connect(Sound.set_muted)
	_panel.select_map(_map_choice)
	_panel.set_auto_mode(settings.auto_mode)
	_panel.set_audio_state(Sound.settings.get_volumes(), Sound.settings.muted)
	_flow.countdown_tick.connect(_on_countdown_tick)
	_race.marble_finished.connect(_on_marble_finished)
	add_child(_photo)
	_race.photo_finish.connect(_on_photo_finish)
	_photo.ended.connect(_camera.release_hold)
	_flow.podium_ready.connect(_on_podium_ready)
	_rng.randomize()
	if OS.has_feature("web") and DebugMode.is_enabled():
		var bridge := WebTestBridge.new()
		add_child(bridge)
		bridge.setup(_flow, _betting, _panel)
	_flow.open_lobby()


func _apply_settings() -> void:
	_flow.min_players = settings.min_players
	_flow.max_players = settings.max_players
	_flow.countdown_seconds = settings.countdown_seconds
	_flow.set_auto_mode(settings.auto_mode, float(settings.auto_join_seconds))
	_betting.starting_balance = settings.starting_balance
	_betting.points.starting_balance = settings.starting_balance
	_betting.min_bet = settings.min_bet
	_betting.max_bet = settings.max_bet
	_shop.species_price = settings.species_price
	_shop.color_price = settings.color_price
	_chaos.boost_cost = settings.boost_cost
	_chaos.curse_cost = settings.curse_cost
	_chaos.viewer_cooldown = float(settings.viewer_cooldown)
	_chaos.fish_lockout = float(settings.fish_lockout)
	_cheer.command_prefix = Chat.parser.prefix
	_cheer.strength_percent = settings.cheer_strength
	_cheer.viewer_cooldown = float(settings.cheer_viewer_cooldown)
	_cheer.fish_cooldown = float(settings.cheer_fish_cooldown)
	_cheer.max_emotes = settings.cheer_max_emotes
	_map_choice = settings.default_map
	_camera.set_play_fraction(settings.play_fraction())
	_overlay.set_play_fraction(settings.play_fraction())


func _process(_delta: float) -> void:
	if _flow.state == GameFlow.State.LOBBY:
		_refresh_lobby()
	if _flow.state == GameFlow.State.RACING and _race.running:
		_camera.follow(_race.get_position_map(), _race.get_progress_map())
	_panel.set_status(_status_text())


func _on_state_changed(new_state: GameFlow.State, _old_state: GameFlow.State) -> void:
	_photo.stop()
	match new_state:
		GameFlow.State.IDLE:
			_race.clear()
			_overlay.show_idle()
			_camera.show_overview()
		GameFlow.State.LOBBY:
			_race.clear()
			_load_map()
			_show_leaderboard()
			_refresh_lobby()
			_camera.show_overview(true)
		GameFlow.State.COUNTDOWN, GameFlow.State.PODIUM:
			_camera.show_overview()
		GameFlow.State.RACING:
			_overlay.show_racing()


func _remember_name(msg: ChatMessage, command: String, _args: PackedStringArray) -> void:
	if NAMED_COMMANDS.has(command):
		_betting.points.set_name(msg.user_id, _viewer_name(msg))


func _on_command(_msg: ChatMessage, command: String, _args: PackedStringArray) -> void:
	if command != "top":
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_top_msec < TOP_COOLDOWN_MSEC:
		return
	_last_top_msec = now
	Chat.send_message(Leaderboard.chat_text(_betting.points.top_by_points(Leaderboard.CHAT_ROWS)))


func _show_leaderboard() -> void:
	_overlay.set_leaderboard(
		_betting.points.top_by_points(LeaderboardPanel.ROWS),
		_betting.points.top_by_wins(LeaderboardPanel.ROWS)
	)


func _on_player_joined(_contestant: Contestant) -> void:
	Sound.play(Sound.Sfx.JOIN)
	_refresh_lobby()


func _on_countdown_tick(_seconds_left: int) -> void:
	Sound.play(Sound.Sfx.TICK)


func _on_marble_finished(_id: int, _place: int) -> void:
	Sound.play(Sound.Sfx.SPLASH)


func _on_photo_finish(_winner_id: int, _chaser_id: int) -> void:
	if _flow.state != GameFlow.State.RACING or _track == null:
		return
	_camera.hold_on(_track.get_finish_position())
	_photo.start()


func _on_podium_ready(podium: Array[Dictionary]) -> void:
	if not podium.is_empty() and podium[0]["finished"]:
		Sound.play(Sound.Sfx.WIN)


func _on_auto_mode_toggled(enabled: bool) -> void:
	settings.auto_mode = enabled
	settings.save()
	_flow.set_auto_mode(enabled, float(settings.auto_join_seconds))


func _on_map_selected(choice: String) -> void:
	if choice == _map_choice:
		return
	_map_choice = choice
	# Applies to the next lobby, or right away while one is open (the roster is unaffected).
	if _flow.state == GameFlow.State.LOBBY:
		_load_map()


## Swaps in the track for the coming race. Only called with no marbles on the field.
func _load_map() -> void:
	var id: String = TrackCatalog.resolve(_map_choice, _rng, _map_id)
	if _track != null and id == _map_id:
		return
	if _track != null:
		remove_child(_track)
		_track.queue_free()
	_map_id = id
	_track = TrackCatalog.instantiate(id)
	add_child(_track)
	move_child(_track, 0)
	_camera.set_bounds(_track.view_bounds)
	_camera.show_overview(true)


func _on_join_rejected(msg: ChatMessage, reason: String) -> void:
	if _flow.state == GameFlow.State.IDLE:
		return
	var text: String = GameFlow.rejection_text(reason, msg)
	if text == "" or not settings.chat_replies:
		return
	var now: int = Time.get_ticks_msec()
	if (
		_last_reply_msec.has(msg.user_id)
		and now - _last_reply_msec[msg.user_id] < REPLY_COOLDOWN_MSEC
	):
		return
	_last_reply_msec[msg.user_id] = now
	Chat.send_message(text)


func _on_bet_placed(msg: ChatMessage, target: Contestant, amount: int) -> void:
	_overlay.show_notice("%s bet %d on %s" % [_viewer_name(msg), amount, target.display_name])


func _on_bet_rejected(msg: ChatMessage, reason: String) -> void:
	var text: String = BET_REJECTIONS.get(reason, "bet not accepted")
	_overlay.show_notice("%s: %s" % [_viewer_name(msg), text])


func _on_effect_requested(marble_id: int, kind: Chaos.Kind) -> void:
	if kind == Chaos.Kind.BOOST:
		_race.boost_marble(marble_id)
	else:
		_race.curse_marble(marble_id)


func _on_effect_applied(msg: ChatMessage, target: Contestant, kind: Chaos.Kind, _cost: int) -> void:
	Sound.play(Sound.Sfx.BOOST if kind == Chaos.Kind.BOOST else Sound.Sfx.CURSE)
	var verb: String = "boosted" if kind == Chaos.Kind.BOOST else "cursed"
	_overlay.show_notice("%s %s %s!" % [_viewer_name(msg), verb, target.display_name])


func _on_effect_rejected(msg: ChatMessage, reason: String) -> void:
	var text: String = CHAOS_REJECTIONS.get(reason, "not accepted")
	_overlay.show_notice("%s: %s" % [_viewer_name(msg), text])


func _on_shop_equipped(msg: ChatMessage, _kind: String, item: String, price: int) -> void:
	if price > 0:
		_overlay.show_notice("%s bought %s for %d" % [_viewer_name(msg), item, price])
	else:
		_overlay.show_notice("%s switched to %s" % [_viewer_name(msg), item])


func _on_shop_rejected(msg: ChatMessage, reason: String) -> void:
	var text: String = SHOP_REJECTIONS.get(reason, "not accepted")
	_overlay.show_notice("%s: %s" % [_viewer_name(msg), text])


func _on_shop_catalog_requested(_msg: ChatMessage) -> void:
	_overlay.show_notice("Shop: #fish <species> or #color <name>")
	if settings.chat_replies:
		Chat.send_message(_shop.catalog_text())


func _on_balance_reported(msg: ChatMessage, balance: int) -> void:
	_overlay.show_notice("%s has %d points" % [_viewer_name(msg), balance])


func _viewer_name(msg: ChatMessage) -> String:
	return msg.display_name if msg.display_name != "" else msg.login


func _on_race_started(contestants: Array[Contestant]) -> void:
	Sound.play(Sound.Sfx.GO)
	ShopCatalog.assign_loadouts(contestants, _shop.store)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_race.start(_track, contestants.size(), rng)
	# Marble ids are roster ids, so match on id rather than on list order.
	for marble: Marble in _race.get_marbles():
		if marble.id < 0 or marble.id >= contestants.size():
			push_warning("Marble id %d has no contestant" % marble.id)
			continue
		marble.color = contestants[marble.id].color
		marble.species = contestants[marble.id].species
		marble.label_text = contestants[marble.id].display_name


func _refresh_lobby() -> void:
	var names: PackedStringArray = []
	for contestant: Contestant in _flow.get_contestants():
		names.append(contestant.display_name)
	_overlay.show_lobby(names, _flow.max_players, _flow.timer if _flow.lobby_seconds > 0.0 else 0.0)


func _status_text() -> String:
	var state_name: String = GameFlow.State.keys()[_flow.state]
	return (
		"%s, %d players, map: %s"
		% [state_name, _flow.get_contestants().size(), TrackCatalog.get_name_of(_map_id)]
	)
