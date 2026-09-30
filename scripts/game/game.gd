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
	"self_boost": "you can't boost your own fish",
	"self_curse": "you can't curse your own fish",
	"cooldown": "you have to wait before another one",
	"fish_busy": "that fish was just hit, try again shortly",
	"insufficient": "not enough points",
}

## Milliseconds between "#top" replies in chat, shared by everyone.
const TOP_COOLDOWN_MSEC: int = 30000

## Milliseconds between "#help" replies in chat, shared by everyone.
const HELP_COOLDOWN_MSEC: int = 30000

## Milliseconds before the same viewer gets another "#stats" reply.
const STATS_COOLDOWN_MSEC: int = 15000

## Commands that put a viewer on the leaderboard, so their name is remembered.
const NAMED_COMMANDS: PackedStringArray = [
	"join", "bet", "boost", "curse", "points", "fish", "color", "shop", "stats"
]

## Most payouts named in the race result line.
const RESULT_PAYOUTS: int = 3

const HOME_SCENE: String = "res://scenes/ui/home_screen.tscn"

## Scene opened by the Home button. Tests set it to "" to stay in place.
var home_scene: String = HOME_SCENE

## The streamer's rules. Loaded from storage in _ready unless a caller sets it first.
var settings: GameSettings = null

var _last_reply_msec: Dictionary[String, int] = {}
var _last_top_msec: int = -TOP_COOLDOWN_MSEC
var _last_help_msec: int = -HELP_COOLDOWN_MSEC
var _last_stats_msec: Dictionary[String, int] = {}

var _map_choice: String = TrackCatalog.RANDOM_ID
var _map_id: String = ""
var _track: Track
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _photo: PhotoFinish = PhotoFinish.new()
var _batcher: ChatBatcher = ChatBatcher.new()
var _payouts: Array[Dictionary] = []

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
	Chat.message_received.connect(_backfill_name)
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
	add_child(_batcher)
	_batcher.line_ready.connect(_on_batched_line)
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
	_chaos.effect_applied.connect(_record_effect_stats)
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
	_betting.payouts_settled.connect(_on_payouts_settled)
	_betting.payouts_settled.connect(_record_bet_stats)
	_betting.bet_placed.connect(_on_bet_placed)
	_betting.bet_rejected.connect(_on_bet_rejected)
	_betting.balance_reported.connect(_on_balance_reported)
	_race.race_finished.connect(_record_race_stats)
	_race.race_finished.connect(_flow.report_race_finished)
	_panel.open_lobby_pressed.connect(_flow.open_lobby)
	_panel.start_pressed.connect(_flow.start_race)
	_panel.stop_pressed.connect(_flow.stop)
	_panel.add_debug_players_pressed.connect(_flow.add_debug_players)
	_panel.home_pressed.connect(_on_home_pressed)
	_panel.leave_confirmed.connect(_leave_to_home)
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
	# After Betting.on_podium_ready, which settles the payouts this handler reports.
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
	_shop.colorblind = settings.colorblind
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
	if new_state != GameFlow.State.COUNTDOWN and new_state != GameFlow.State.RACING:
		_panel.cancel_leave()
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


## Any chat line from a viewer who is already ranked fills in or refreshes their name, so
## entries saved before names were recorded get one as soon as the viewer says anything.
func _backfill_name(msg: ChatMessage) -> void:
	var points: PointsStore = _betting.points
	if not points.has_entry(msg.user_id):
		return
	if points.set_name(msg.user_id, _viewer_name(msg)):
		points.save_to_disk()


func _on_command(msg: ChatMessage, command: String, args: PackedStringArray) -> void:
	if command == "help":
		_reply_help()
		return
	if command == "stats":
		_reply_stats(msg, args)
		return
	if command != "top":
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_top_msec < TOP_COOLDOWN_MSEC:
		return
	_last_top_msec = now
	Chat.send_message(Leaderboard.chat_text(_betting.points.top_by_points(Leaderboard.CHAT_ROWS)))


func _reply_help() -> void:
	if not settings.chat_replies:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_help_msec < HELP_COOLDOWN_MSEC:
		return
	_last_help_msec = now
	Chat.send_message(HelpText.CHAT_REPLY)


## "#stats" shows the caller's record, "#stats @name" someone else's. Each viewer has a cooldown.
func _reply_stats(msg: ChatMessage, args: PackedStringArray) -> void:
	if not settings.chat_replies:
		return
	var now: int = Time.get_ticks_msec()
	if (
		_last_stats_msec.has(msg.user_id)
		and now - _last_stats_msec[msg.user_id] < STATS_COOLDOWN_MSEC
	):
		return
	_last_stats_msec[msg.user_id] = now
	var points: PointsStore = _betting.points
	var user_id: String = msg.user_id
	if not args.is_empty():
		var asked: String = " ".join(args)
		user_id = points.find_by_name(asked)
		if user_id.is_empty():
			Chat.send_message("No stats found for that name.")
			return
	Chat.send_message(StatsText.chat_text(points, user_id))


## Feed it Race.race_finished: counts the race for everyone on the field and keeps the times
## and podium places. Ids are roster indexes.
func _record_race_stats(results: Array[Dictionary]) -> void:
	var points: PointsStore = _betting.points
	var contestants: Array[Contestant] = _flow.get_contestants()
	for r: Dictionary in results:
		var id: int = int(r["id"])
		if id < 0 or id >= contestants.size():
			continue
		var user_id: String = contestants[id].user_id
		points.stats.record_race(user_id)
		if bool(r["finished"]):
			points.stats.record_finish_time(user_id, _map_id, float(r["time"]))
			if int(r["place"]) <= _flow.podium_size:
				points.stats.record_podium(user_id)
	points.save_to_disk()


## Feed it Betting.payouts_settled. Refunds are not reported there, so they never count.
func _record_bet_stats(results: Array[Dictionary]) -> void:
	var points: PointsStore = _betting.points
	for r: Dictionary in results:
		points.stats.record_bet(str(r["user_id"]), int(r["amount"]), int(r["payout"]))
	points.save_to_disk()


func _record_effect_stats(
	msg: ChatMessage, _target: Contestant, kind: Chaos.Kind, _cost: int
) -> void:
	if kind == Chaos.Kind.BOOST:
		_betting.points.stats.record_boost(msg.user_id)
	else:
		_betting.points.stats.record_curse(msg.user_id)
	_betting.points.save_to_disk()


func _show_leaderboard() -> void:
	_overlay.set_leaderboard(
		_betting.points.top_by_points(LeaderboardPanel.ROWS),
		_betting.points.top_by_wins(LeaderboardPanel.ROWS)
	)


func _on_player_joined(contestant: Contestant) -> void:
	Sound.play(Sound.Sfx.JOIN)
	_confirm("reply_joins", "joins", "Joined:", "@" + contestant.display_name)
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
	var payouts: Array[Dictionary] = _payouts
	_payouts = []
	if podium.is_empty() or not podium[0]["finished"]:
		return
	Sound.play(Sound.Sfx.WIN)
	_confirm(
		"reply_results", "results", "Race over:", _result_text(str(podium[0]["name"]), payouts)
	)


## Leaves right away between rounds; mid-round the streamer has to confirm first.
func _on_home_pressed() -> void:
	if _flow.state == GameFlow.State.COUNTDOWN or _flow.state == GameFlow.State.RACING:
		_panel.ask_leave()
	else:
		_leave_to_home()


## Aborts the round (bets and chaos stakes are refunded), stops auto mode for this session
## (the saved setting stays as it is) and opens the home screen.
func _leave_to_home() -> void:
	_flow.set_auto_mode(false)
	_flow.stop()
	if not home_scene.is_empty():
		get_tree().change_scene_to_file(home_scene)


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
	_confirm(
		"reply_bets",
		"bets",
		"Bets:",
		"@%s %d on %s" % [_viewer_name(msg), amount, target.display_name]
	)
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
	var label: String = "Boosted:" if kind == Chaos.Kind.BOOST else "Cursed:"
	_confirm(
		"reply_chaos",
		"boost" if kind == Chaos.Kind.BOOST else "curse",
		label,
		"@%s on %s" % [_viewer_name(msg), target.display_name]
	)
	_overlay.show_notice("%s %s %s!" % [_viewer_name(msg), verb, target.display_name])


func _on_effect_rejected(msg: ChatMessage, reason: String) -> void:
	var text: String = CHAOS_REJECTIONS.get(reason, "not accepted")
	_overlay.show_notice("%s: %s" % [_viewer_name(msg), text])


func _on_shop_equipped(msg: ChatMessage, kind: String, item: String, price: int) -> void:
	_confirm("reply_shop", "shop", "Shop:", "@%s %s %s" % [_viewer_name(msg), kind, item])
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


func _on_payouts_settled(results: Array[Dictionary]) -> void:
	_payouts = results


## "Bubbles won. Payouts: @a +300, @b +200", with at most three payouts, biggest first.
func _result_text(winner: String, payouts: Array[Dictionary]) -> String:
	var paid: Array[Dictionary] = payouts.filter(
		func(r: Dictionary) -> bool: return r["payout"] > 0
	)
	paid.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["payout"] > b["payout"])
	var parts: PackedStringArray = []
	for r: Dictionary in paid.slice(0, RESULT_PAYOUTS):
		parts.append("@%s +%d" % [r["name"], r["payout"]])
	var text: String = "%s won." % winner
	if not parts.is_empty():
		text += " Payouts: " + ", ".join(parts)
	return text


## Queues a chat confirmation when replies and the kind's own toggle are on.
func _confirm(toggle: String, kind: String, prefix: String, item: String) -> void:
	if settings.replies_enabled(toggle):
		_batcher.add(kind, prefix, item)


func _on_batched_line(text: String) -> void:
	if settings.chat_replies:
		Chat.send_message(text)


func _viewer_name(msg: ChatMessage) -> String:
	return msg.display_name if msg.display_name != "" else msg.login


func _on_race_started(contestants: Array[Contestant]) -> void:
	Sound.play(Sound.Sfx.GO)
	ShopCatalog.assign_loadouts(contestants, _shop.store, settings.colorblind)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_race.start(_track, contestants.size(), rng, settings.hazard_level())
	# Marble ids are roster ids, so match on id rather than on list order.
	for marble: Marble in _race.get_marbles():
		if marble.id < 0 or marble.id >= contestants.size():
			push_warning("Marble id %d has no contestant" % marble.id)
			continue
		marble.color = contestants[marble.id].color
		marble.species = contestants[marble.id].species
		marble.pattern = contestants[marble.id].pattern
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
