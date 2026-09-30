class_name Game
extends Node2D
## Wires chat commands, the round state machine, the race and the UI together.

## Most payouts named in the race result line.
const RESULT_PAYOUTS: int = 3

## Seconds a cast net holds fish.
const NET_SECONDS: float = 2.5
## Pixels the camera shakes when the streamer blasts.
const BLAST_PUNCH: float = 14.0

## Milliseconds a "power not available" line stays in the control panel.
const POWER_NOTE_MSEC: int = 3000
## Most DNF names in the race result line.
const RESULT_DNF: int = 3

## The overlay timer shows for this many seconds before the time limit.
const TIMER_SECONDS: int = 10

const HOME_SCENE: String = "res://scenes/ui/home_screen.tscn"

## Scene opened by the Home button. Tests set it to "" to stay in place.
var home_scene: String = HOME_SCENE

## The streamer's rules. Loaded from storage in _ready unless a caller sets it first.
var settings: GameSettings = null

## Test and debug hook: when set, the wheel lands on this event (or [constant RaceEvent.NOTHING]
## for the plain slice) instead of a random one.
var forced_event: Variant = null

var _event: String = RaceEvent.NOTHING
var _event_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _map_choice: String = TrackCatalog.RANDOM_ID
var _map_id: String = ""
var _track: Track
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _sequence: RaceSequence = RaceSequence.new()
var _replies: ChatReplies = ChatReplies.new()
var _batcher: ChatBatcher = _replies.batcher
var _meow: Meow = Meow.new()
var _viewer_commands: ViewerCommands = ViewerCommands.new()
var _payouts: Array[Dictionary] = []
## The streamer power waiting for a click on the track (a StreamerPowers.Kind), or -1.
var _armed_power: int = -1
var _power_cursor: PowerCursor = PowerCursor.new()
var _power_note: String = ""
var _power_note_until_msec: int = 0
## Names of the fish that did not finish the last race, in results order.
var _dnf_names: PackedStringArray = []
## The treasures found this race, paid when it ends.
var _haul: TreasureHaul = TreasureHaul.new()
## The treasure part of the result line, "@a +50, @b +25", or empty.
var _haul_text: String = ""

@onready var _flow: GameFlow = $GameFlow
@onready var _betting: Betting = $Betting
@onready var _chaos: Chaos = $Chaos
@onready var _shop: Shop = $Shop
@onready var _cheer: Cheer = $Cheer
@onready var _powers: StreamerPowers = $StreamerPowers
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
	_viewer_commands.points = _betting.points
	_viewer_commands.settings = settings
	_viewer_commands.reply_ready.connect(Chat.send_message)
	add_child(_viewer_commands)
	Chat.command_received.connect(_viewer_commands.remember_name)
	Chat.message_received.connect(_viewer_commands.backfill_name)
	Chat.command_received.connect(_flow.handle_command)
	Chat.command_received.connect(_betting.handle_command)
	Chat.command_received.connect(_chaos.handle_command)
	Chat.command_received.connect(_viewer_commands.handle_command)
	Chat.command_received.connect(_shop.handle_command)
	_chaos.points = _betting.points
	_shop.points = _betting.points
	_shop.equipped.connect(_on_shop_equipped)
	_shop.rejected.connect(_on_shop_rejected)
	_shop.catalog_requested.connect(_on_shop_catalog_requested)
	add_child(_replies)
	_replies.notice.connect(_overlay.show_notice)
	_replies.chat_line.connect(Chat.send_message)
	add_child(_meow)
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
	Chat.command_received.connect(_meow.handle_command)
	_flow.player_joined.connect(_meow.add_contestant)
	_flow.state_changed.connect(_meow.on_state_changed)
	_meow.meow_requested.connect(_on_meow_requested)
	_flow.state_changed.connect(_powers.on_state_changed)
	_powers.power_used.connect(_on_power_used)
	_powers.power_rejected.connect(_on_power_rejected)
	_panel.power_pressed.connect(_on_power_pressed)
	add_child(_power_cursor)
	_race.marble_finished.connect(_chaos.on_marble_finished)
	_race.marble_finished.connect(_cheer.on_marble_finished)
	# Before the flow's connection below, so chaos closes before the state changes.
	_race.race_finished.connect(_chaos.on_race_finished)
	_race.race_finished.connect(_powers.on_race_finished)
	_race.race_finished.connect(_cheer.on_race_finished)
	_race.race_finished.connect(_meow.on_race_finished)
	_flow.podium_ready.connect(_overlay.show_podium)
	_flow.podium_ready.connect(_betting.on_podium_ready)
	_betting.bets_changed.connect(_overlay.show_bets)
	_betting.payouts_settled.connect(_overlay.show_payouts)
	_betting.payouts_settled.connect(_on_payouts_settled)
	_betting.payouts_settled.connect(_record_bet_stats)
	_betting.bet_placed.connect(_on_bet_placed)
	_betting.bet_rejected.connect(_on_bet_rejected)
	_betting.balance_reported.connect(_on_balance_reported)
	_race.race_finished.connect(_on_race_finished)
	_panel.open_lobby_pressed.connect(_flow.open_lobby)
	_panel.start_pressed.connect(_on_start_pressed)
	_panel.skip_replay_pressed.connect(_sequence.skip_replay)
	_panel.stop_pressed.connect(_flow.stop)
	_panel.add_debug_players_pressed.connect(_flow.add_debug_players)
	_panel.debug_duck_pressed.connect(_on_debug_duck)
	_panel.debug_meow_pressed.connect(_on_debug_meow)
	_panel.home_pressed.connect(_on_home_pressed)
	_panel.back_pressed.connect(_on_back_pressed)
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
	_sequence.settings = settings
	_sequence.name = "RaceSequence"
	_sequence.fade_out = _overlay.fade_out
	_sequence.fade_in_requested.connect(_overlay.fade_in)
	_sequence.results_ready.connect(_report_results)
	_sequence.replay_started.connect(_on_replay_started)
	_sequence.replay_ended.connect(_on_replay_ended)
	add_child(_sequence)
	_race.photo_finish.connect(_on_photo_finish)
	_race.fish_snapped.connect(_on_fish_snapped)
	_race.treasure_collected.connect(_on_treasure_collected)
	_race.fish_stranded.connect(_on_fish_stranded)
	_race.fish_dissolved.connect(_on_fish_dissolved)
	_sequence.photo_ended.connect(_camera.release_hold)
	# After Betting.on_podium_ready, which settles the payouts this handler reports.
	_flow.podium_ready.connect(_on_podium_ready)
	_rng.randomize()
	_event_rng.randomize()
	if OS.has_feature("web") and DebugMode.is_enabled():
		var bridge := WebTestBridge.new()
		add_child(bridge)
		bridge.setup(_flow, _betting, _panel)
	_flow.open_lobby()


func _apply_settings() -> void:
	_replies.settings = settings
	_flow.min_players = settings.min_players
	_flow.max_players = settings.max_players
	_flow.countdown_seconds = settings.effective_countdown()
	_race.time_limit = float(settings.race_time_limit)
	_race.treasures_enabled = settings.treasures_enabled
	_flow.set_auto_mode(settings.auto_mode, float(settings.auto_join_seconds))
	_betting.starting_balance = settings.starting_balance
	_betting.points.starting_balance = settings.starting_balance
	_betting.min_bet = settings.min_bet
	_betting.max_bet = settings.max_bet
	_betting.place_rewards = [settings.win_reward, settings.second_reward, settings.third_reward]
	_shop.species_price = settings.species_price
	_shop.color_price = settings.color_price
	_shop.premium_color_price = settings.premium_color_price
	_shop.hat_price = settings.hat_price
	_shop.trail_price = settings.trail_price
	_shop.colorblind = settings.colorblind
	_chaos.boost_cost = settings.boost_cost
	_chaos.curse_cost = settings.curse_cost
	_chaos.viewer_cooldown = float(settings.viewer_cooldown)
	_chaos.fish_lockout = float(settings.fish_lockout)
	_powers.enabled = settings.powers_enabled
	_powers.cooldown = float(settings.power_cooldown)
	_powers.max_per_race = settings.powers_per_race
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
	var left: float = _race.time_left()
	_overlay.show_race_timer(ceili(left) if left >= 0.0 and left <= TIMER_SECONDS else -1)
	if _sequence.is_replaying():
		_follow_replay()
	_panel.set_status(_status_text())
	_panel.set_power_status(_power_status_text())
	var racing: bool = _flow.state == GameFlow.State.RACING
	_panel.set_power_cooldown(
		_powers.cooldown_left() if racing else 0.0, _powers.cooldown, not racing
	)


## Left click fires the armed streamer power at the mouse; right click puts it away.
func _unhandled_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or _armed_power < 0:
		return
	if click.button_index == MOUSE_BUTTON_LEFT:
		var kind: int = _armed_power
		_arm_power(-1)
		_powers.use(kind as StreamerPowers.Kind, get_global_mouse_position())
		get_viewport().set_input_as_handled()
	elif click.button_index == MOUSE_BUTTON_RIGHT:
		_arm_power(-1)
		get_viewport().set_input_as_handled()


func _on_state_changed(new_state: GameFlow.State, _old_state: GameFlow.State) -> void:
	_arm_power(-1)
	# Leaving the race (stop, home) drops the held results instead of reporting them.
	_sequence.cancel()
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
	match new_state:
		GameFlow.State.COUNTDOWN:
			_spin_wheel()
		GameFlow.State.RACING:
			_overlay.show_racing()
		_:
			_event = RaceEvent.NOTHING


func _on_treasure_collected(id: int, kind: int, value: int) -> void:
	Sound.play(Sound.Sfx.BOOST)
	var contestants: Array[Contestant] = _flow.get_contestants()
	if id < 0 or id >= contestants.size():
		return
	var found: Contestant = contestants[id]
	_haul.add(found.user_id, found.display_name, value)
	_overlay.show_notice(
		"%s found a %s! +%d" % [found.display_name, Treasure.name_of(kind as Treasure.Kind), value]
	)


## Feed it Race.race_finished: counts the race for everyone on the field and keeps the times
## and podium places. Ids are roster indexes.
func _record_race_stats(results: Array[Dictionary]) -> void:
	var points: PointsStore = _betting.points
	var contestants: Array[Contestant] = _flow.get_contestants()
	_dnf_names = []
	for r: Dictionary in results:
		var id: int = int(r["id"])
		if id < 0 or id >= contestants.size():
			continue
		var user_id: String = contestants[id].user_id
		points.stats.record_race(user_id)
		if not bool(r["finished"]):
			points.stats.record_dnf(user_id)
			_dnf_names.append(contestants[id].display_name)
		else:
			points.stats.record_finish_time(user_id, _map_id, float(r["time"]))
			if int(r["place"]) <= _flow.podium_size:
				points.stats.record_podium(user_id)
	points.save_to_disk()


## Feed it Betting.payouts_settled. Refunds are not reported there, so they never count.
func _record_bet_stats(results: Array[Dictionary]) -> void:
	var points: PointsStore = _betting.points
	for r: Dictionary in results:
		# Placement rewards are not bets: they never count towards bets won, lost or the net.
		if r.get("kind", "bet") != "bet":
			continue
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


## Picks this race's event and starts the wheel over the countdown, leaving a second to read
## the result. With random events off the race has none.
func _spin_wheel() -> void:
	_event = RaceEvent.NOTHING
	if not settings.random_events:
		return
	var slices: Array[String] = RaceEvent.wheel(settings.hazards_enabled)
	var index: int = RaceEvent.spin(slices, _event_rng)
	if forced_event != null:
		index = maxi(slices.find(String(forced_event)), 0)
	_event = slices[index]
	var result: String = RaceEvent.name_of(_event).to_upper() if _event != "" else "NOTHING"
	_overlay.show_event_wheel(
		slices, index, maxf(float(_flow.countdown_seconds) - 1.0, 1.0), result
	)


func _event_badge_text() -> String:
	if _event == RaceEvent.NOTHING:
		return ""
	return "%s: %s" % [RaceEvent.name_of(_event).to_upper(), RaceEvent.blurb_of(_event)]


func _show_leaderboard() -> void:
	_overlay.set_leaderboard(
		_betting.points.top_by_points(LeaderboardPanel.ROWS),
		_betting.points.top_by_wins(LeaderboardPanel.ROWS)
	)


func _on_player_joined(contestant: Contestant) -> void:
	Sound.play(Sound.Sfx.JOIN)
	_replies.player_joined(contestant)
	_refresh_lobby()


func _on_countdown_tick(_seconds_left: int) -> void:
	Sound.play(Sound.Sfx.TICK)


func _on_marble_finished(_id: int, _place: int) -> void:
	Sound.play(Sound.Sfx.SPLASH)


func _on_fish_snapped(ids: Array[int]) -> void:
	Sound.play(Sound.Sfx.SPLASH)
	_overlay.show_notice("SNAP! %d fish turned to dust" % ids.size(), 3.0)


func _on_fish_stranded(id: int) -> void:
	# Marble ids are roster indexes.
	var contestants: Array[Contestant] = _flow.get_contestants()
	var who: String = "A fish"
	if id >= 0 and id < contestants.size():
		who = "@" + contestants[id].display_name
	_overlay.show_notice("%s was left high and dry!" % who, 2.5)


func _on_fish_dissolved(id: int) -> void:
	Sound.play(Sound.Sfx.CURSE)
	# Marble ids are roster indexes.
	var contestants: Array[Contestant] = _flow.get_contestants()
	var who: String = "A fish"
	if id >= 0 and id < contestants.size():
		who = "@" + contestants[id].display_name
	_overlay.show_notice("%s was dissolved in stomach acid!" % who, 3.0)


func _on_photo_finish(_winner_id: int, _chaser_id: int) -> void:
	if _flow.state != GameFlow.State.RACING or _track == null:
		return
	_camera.hold_on(_track.get_finish_position())
	_sequence.start_photo_finish()


## The kraken grumbles with its warning and swooshes as the tentacles go. Hazards do not run
## during the finish replay, so it stays silent there.
func _on_hazard_started(kind: String) -> void:
	if kind == KrakenHazard.KIND or kind == GulpHazard.KIND:
		Sound.play(Sound.Sfx.KRAKEN_GRUMBLE)


func _on_hazard_active(kind: String) -> void:
	if kind == KrakenHazard.KIND or kind == GulpHazard.KIND:
		Sound.play(Sound.Sfx.KRAKEN_SWOOSH)


func _on_fish_eaten(marble: Marble) -> void:
	Sound.play(Sound.Sfx.CURSE)
	var who: String = "@" + marble.label_text if marble.label_text != "" else "A fish"
	_overlay.show_notice("%s got eaten!" % who, 3.0)
	# Marble ids are roster indexes.
	var contestants: Array[Contestant] = _flow.get_contestants()
	if marble.id >= 0 and marble.id < contestants.size():
		_betting.points.stats.record_eaten(contestants[marble.id].user_id)
		_betting.points.save_to_disk()


## Hands the results to the sequence, which reports them after a finish replay when the
## setting asks for one.
func _on_race_finished(results: Array[Dictionary]) -> void:
	_sequence.finish(results, _race.get_recorder(), _race.get_marbles(), _race.had_photo_finish)


## The replay cut in under a dip to dark.
func _on_replay_started() -> void:
	_overlay.show_replay(true)
	_panel.show_skip_replay(true)


## Counts the race for the viewers' stats and hands the results to the flow. Only runs when the
## race really ends, so a round stopped during the replay leaves no stats behind.
func _report_results(results: Array[Dictionary]) -> void:
	# Before the stats, whose save covers the treasure points too.
	_haul_text = _haul.settle(_betting.points)
	_record_race_stats(results)
	_flow.report_race_finished(results)


func _on_replay_ended(results: Array[Dictionary]) -> void:
	_overlay.show_replay(false)
	_panel.show_skip_replay(false)
	var still_racing: bool = _flow.state == GameFlow.State.RACING
	if not results.is_empty():
		_report_results(results)
	# Fully dark already when the replay ran out; a skip dips quickly from wherever it was. After
	# the report, because showing the podium resets the overlay.
	if still_racing:
		_overlay.fade_in(RaceSequence.REPLAY_FADE)


## Space starts the race, or skips the replay while one plays.
func _on_start_pressed() -> void:
	if _sequence.is_replaying():
		_sequence.skip_replay()
	else:
		_flow.start_race()


## Camera during the replay: tight on the winner, centred on them through the crossing.
func _follow_replay() -> void:
	if _track == null:
		return
	var at: Vector2 = _sequence.winner_position()
	_camera.follow({0: at}, {0: _track.get_progress(at)})


func _on_podium_ready(podium: Array[Dictionary]) -> void:
	var payouts: Array[Dictionary] = _payouts
	var dnf: PackedStringArray = _dnf_names
	var haul: String = _haul_text
	_payouts = []
	_dnf_names = []
	_haul_text = ""
	_overlay.show_dnf(dnf)
	if podium.is_empty():
		if not dnf.is_empty():
			var over: String = "time is up, nobody finished."
			if not haul.is_empty():
				over += " Treasure: " + haul
			_replies.confirm("reply_results", "results", "Race over:", over)
		return
	Sound.play_win()
	_replies.confirm(
		"reply_results",
		"results",
		"Race over:",
		_result_text(str(podium[0]["name"]), payouts, dnf, haul)
	)


## Esc steps back one level: the podium returns to an empty map. Everywhere else it does
## nothing, so a stray key press never aborts a round or leaves the game.
func _on_back_pressed() -> void:
	if _flow.state == GameFlow.State.PODIUM:
		_flow.open_lobby()


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
	_track.fish_eaten.connect(_on_fish_eaten)
	_track.hazard_started.connect(_on_hazard_started)
	_track.hazard_active.connect(_on_hazard_active)
	add_child(_track)
	move_child(_track, 0)
	_camera.set_bounds(_track.view_bounds)
	Sound.set_music_theme(id)
	_camera.show_overview(true)


func _on_join_rejected(msg: ChatMessage, reason: String) -> void:
	if _flow.state == GameFlow.State.IDLE:
		return
	_replies.join_rejected(msg, reason)


func _on_bet_placed(msg: ChatMessage, target: Contestant, amount: int) -> void:
	_replies.bet_placed(msg, target, amount)


func _on_bet_rejected(msg: ChatMessage, reason: String) -> void:
	_replies.bet_rejected(msg, reason)


func _on_power_pressed(kind: int) -> void:
	_arm_power(-1 if kind == _armed_power else kind)


func _arm_power(kind: int) -> void:
	_armed_power = kind
	_panel.set_armed_power(kind)
	_power_cursor.arm(
		kind, StreamerPowers.radius_of(kind as StreamerPowers.Kind) if kind >= 0 else 0.0
	)


func _on_power_used(kind: StreamerPowers.Kind, pos: Vector2) -> void:
	var radius: float = StreamerPowers.radius_of(kind)
	_panel.play_power_activate(kind)
	var text: String = ""
	match kind:
		StreamerPowers.Kind.ROD:
			var id: int = _race.hook_near(pos, radius)
			var hooked: String = _contestant_name(id)
			text = (
				"The streamer hooked @%s!" % hooked
				if id >= 0
				else "The streamer's hook came up empty"
			)
			Sound.play(Sound.Sfx.ROD_CAST)
			if id >= 0:
				Sound.play(Sound.Sfx.ROD_CATCH)
		StreamerPowers.Kind.NET:
			var caught: int = _race.place_net(pos, radius, NET_SECONDS)
			text = "The streamer cast a net over %s!" % _fish_count(caught)
			Sound.play(Sound.Sfx.NET_CAST)
			if caught > 0:
				Sound.play(Sound.Sfx.NET_CATCH)
		StreamerPowers.Kind.BLAST:
			var hit: int = _race.blast(pos, radius)
			text = "The streamer blasted %s!" % _fish_count(hit)
			Sound.play(Sound.Sfx.BLAST_CAST)
			if hit > 0:
				Sound.play(Sound.Sfx.BLAST_HIT)
			_camera.punch(BLAST_PUNCH)
	_overlay.show_notice(text)
	if settings.replies_enabled("reply_powers"):
		Chat.send_message(text)


func _on_power_rejected(_kind: StreamerPowers.Kind, reason: String) -> void:
	_power_note = ChatReplies.power_rejection(reason)
	_power_note_until_msec = Time.get_ticks_msec() + POWER_NOTE_MSEC


## "1 fish" or "3 fish", or "no fish" for none.
func _fish_count(count: int) -> String:
	return "%d fish" % count if count > 0 else "no fish"


func _contestant_name(id: int) -> String:
	var contestants: Array[Contestant] = _flow.get_contestants()
	return contestants[id].display_name if id >= 0 and id < contestants.size() else ""


func _power_status_text() -> String:
	if Time.get_ticks_msec() < _power_note_until_msec:
		return _power_note
	if _armed_power >= 0:
		return (
			"%s armed: click the track (right click cancels)"
			% StreamerPowers.name_of(_armed_power as StreamerPowers.Kind)
		)
	if not settings.powers_enabled:
		return "Streamer powers are off in the settings"
	if _flow.state != GameFlow.State.RACING:
		return "Streamer powers: available during a race"
	if _powers.cooldown_left() > 0.0:
		return "Recharging %.0fs, %d left" % [ceilf(_powers.cooldown_left()), _powers.uses_left()]
	return "Ready, %d left this race" % _powers.uses_left()


func _on_effect_requested(marble_id: int, kind: Chaos.Kind) -> void:
	if kind == Chaos.Kind.BOOST:
		_race.boost_marble(marble_id)
	else:
		_race.curse_marble(marble_id)


func _on_effect_applied(msg: ChatMessage, target: Contestant, kind: Chaos.Kind, _cost: int) -> void:
	Sound.play(Sound.Sfx.BOOST if kind == Chaos.Kind.BOOST else Sound.Sfx.CURSE)
	_replies.effect_applied(msg, target, kind)


## Debug button: a rubber duck drifts through the current map right now.
func _on_debug_duck() -> void:
	if _track == null:
		_overlay.show_notice("Debug: no map loaded")
		return
	_track.force_duck(randi())


## Debug button: a random fish meows. Only works while a race is running.
func _on_debug_meow() -> void:
	if _race.meow_random_marble():
		Sound.play(Sound.Sfx.MEOW)
	else:
		_overlay.show_notice("Debug: meow needs a running race")


func _on_meow_requested(marble_id: int) -> void:
	if _race.meow_marble(marble_id):
		Sound.play(Sound.Sfx.MEOW)


func _on_effect_rejected(msg: ChatMessage, reason: String) -> void:
	_replies.effect_rejected(msg, reason)


func _on_shop_equipped(msg: ChatMessage, kind: String, item: String, price: int) -> void:
	_replies.shop_equipped(msg, kind, item, price)


func _on_shop_rejected(msg: ChatMessage, reason: String) -> void:
	_replies.shop_rejected(msg, reason)


func _on_shop_catalog_requested(_msg: ChatMessage) -> void:
	_overlay.show_notice("Shop: #fish <species>, #color <name>, #hat <name> or #trail <name>")
	if settings.chat_replies:
		Chat.send_message(_shop.catalog_text())
		Chat.send_message(_shop.premium_catalog_text())
		Chat.send_message(_shop.hat_catalog_text())
		Chat.send_message(_shop.trail_catalog_text())


func _on_balance_reported(msg: ChatMessage, balance: int) -> void:
	_replies.balance_reported(msg, balance)


func _on_payouts_settled(results: Array[Dictionary]) -> void:
	_payouts = results


## "Bubbles won. Payouts: @a +300, @b +200. DNF: c, d", with at most three payouts, biggest
## first, and at most three DNF names.
func _result_text(
	winner: String, payouts: Array[Dictionary], dnf: PackedStringArray = [], treasure: String = ""
) -> String:
	# One entry per viewer: a winner who also bet shows a single total.
	var totals: Dictionary = {}
	for r: Dictionary in payouts:
		if int(r["payout"]) <= 0:
			continue
		var uid: String = str(r.get("user_id", r["name"]))
		if totals.has(uid):
			totals[uid]["payout"] = int(totals[uid]["payout"]) + int(r["payout"])
		else:
			totals[uid] = {"name": r["name"], "payout": int(r["payout"])}
	var paid: Array[Dictionary] = []
	for total: Dictionary in totals.values():
		paid.append(total)
	paid.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["payout"] > b["payout"])
	var parts: PackedStringArray = []
	for r: Dictionary in paid.slice(0, RESULT_PAYOUTS):
		parts.append("@%s +%d" % [r["name"], r["payout"]])
	var sections: PackedStringArray = []
	if not parts.is_empty():
		sections.append("Payouts: " + ", ".join(parts))
	if not treasure.is_empty():
		sections.append("Treasure: " + treasure)
	if not dnf.is_empty():
		var names: String = "DNF: " + ", ".join(dnf.slice(0, RESULT_DNF))
		if dnf.size() > RESULT_DNF:
			names += " +%d more" % (dnf.size() - RESULT_DNF)
		sections.append(names)
	var text: String = "%s won." % winner
	if not sections.is_empty():
		text += " " + ". ".join(sections)
	return text


func _on_race_started(contestants: Array[Contestant]) -> void:
	Sound.play(Sound.Sfx.GO)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if settings.welcome_hat:
		for welcome: Dictionary in _shop.welcome_new_racers(
			contestants, _betting.points.stats, rng
		):
			var name: String = (welcome["contestant"] as Contestant).display_name
			_replies.welcome(name, welcome["hat"])
	ShopCatalog.assign_loadouts(contestants, _shop.store, settings.colorblind)
	_haul.clear()
	_haul_text = ""
	_race.start(_track, contestants.size(), rng, settings.hazard_level(), _event)
	_overlay.show_event_badge(_event_badge_text())
	# Marble ids are roster ids, so match on id rather than on list order.
	for marble: Marble in _race.get_marbles():
		if marble.id < 0 or marble.id >= contestants.size():
			push_warning("Marble id %d has no contestant" % marble.id)
			continue
		marble.color = contestants[marble.id].color
		marble.species = contestants[marble.id].species
		marble.pattern = contestants[marble.id].pattern
		marble.accessory = contestants[marble.id].accessory
		marble.skin = contestants[marble.id].skin
		marble.trail = contestants[marble.id].trail
		marble.label_text = contestants[marble.id].display_name


func _refresh_lobby() -> void:
	var contestants: Array[Contestant] = _flow.get_contestants()
	# Same look the race will give them, so the list previews the fish that swims.
	ShopCatalog.assign_loadouts(contestants, _shop.store, settings.colorblind)
	var players: Array[Dictionary] = []
	for contestant: Contestant in contestants:
		(
			players
			. append(
				{
					"name": contestant.display_name,
					"color": contestant.color,
					"species": contestant.species,
					"pattern": contestant.pattern,
					"accessory": contestant.accessory,
					"skin": contestant.skin,
				}
			)
		)
	_overlay.show_lobby(
		players, _flow.max_players, _flow.timer if _flow.lobby_seconds > 0.0 else 0.0
	)


func _status_text() -> String:
	var state_name: String = GameFlow.State.keys()[_flow.state]
	return (
		"%s, %d players, map: %s"
		% [state_name, _flow.get_contestants().size(), TrackCatalog.get_name_of(_map_id)]
	)
