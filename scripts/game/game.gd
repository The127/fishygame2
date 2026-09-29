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

var _last_reply_msec: Dictionary[String, int] = {}

var _map_choice: String = TrackCatalog.RANDOM_ID
var _map_id: String = ""
var _track: Track
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _flow: GameFlow = $GameFlow
@onready var _betting: Betting = $Betting
@onready var _chaos: Chaos = $Chaos
@onready var _race: Race = $Race
@onready var _overlay: Overlay = $Overlay
@onready var _panel: ControlPanel = $ControlPanel


func _ready() -> void:
	Chat.command_received.connect(_flow.handle_command)
	Chat.command_received.connect(_betting.handle_command)
	Chat.command_received.connect(_chaos.handle_command)
	_chaos.points = _betting.points
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
	_race.marble_finished.connect(_chaos.on_marble_finished)
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
	_rng.randomize()
	_flow.open_lobby()


func _process(_delta: float) -> void:
	if _flow.state == GameFlow.State.LOBBY:
		_refresh_lobby()
	_panel.set_status(_status_text())


func _on_state_changed(new_state: GameFlow.State, _old_state: GameFlow.State) -> void:
	match new_state:
		GameFlow.State.IDLE:
			_race.clear()
			_overlay.show_idle()
		GameFlow.State.LOBBY:
			_race.clear()
			_load_map()
			_refresh_lobby()
		GameFlow.State.RACING:
			_overlay.show_racing()


func _on_player_joined(_contestant: Contestant) -> void:
	_refresh_lobby()


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


func _on_join_rejected(msg: ChatMessage, reason: String) -> void:
	if _flow.state == GameFlow.State.IDLE:
		return
	var text: String = GameFlow.rejection_text(reason, msg)
	if text == "":
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
	var verb: String = "boosted" if kind == Chaos.Kind.BOOST else "cursed"
	_overlay.show_notice("%s %s %s!" % [_viewer_name(msg), verb, target.display_name])


func _on_effect_rejected(msg: ChatMessage, reason: String) -> void:
	var text: String = CHAOS_REJECTIONS.get(reason, "not accepted")
	_overlay.show_notice("%s: %s" % [_viewer_name(msg), text])


func _on_balance_reported(msg: ChatMessage, balance: int) -> void:
	_overlay.show_notice("%s has %d points" % [_viewer_name(msg), balance])


func _viewer_name(msg: ChatMessage) -> String:
	return msg.display_name if msg.display_name != "" else msg.login


func _on_race_started(contestants: Array[Contestant]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_race.start(_track, contestants.size(), rng)
	# Marble ids are roster ids, so match on id rather than on list order.
	for marble: Marble in _race.get_marbles():
		if marble.id < 0 or marble.id >= contestants.size():
			push_warning("Marble id %d has no contestant" % marble.id)
			continue
		marble.color = contestants[marble.id].color
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
