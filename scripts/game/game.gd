class_name Game
extends Node2D
## Wires chat commands, the round state machine, the race and the UI together.

const BET_REJECTIONS: Dictionary = {
	"closed": "betting is closed",
	"usage": "use #bet <name> <amount>",
	"already_bet": "you already bet this round",
	"unknown_fish": "no such racer",
	"invalid_amount": "invalid amount",
	"insufficient": "not enough points",
}

@onready var _flow: GameFlow = $GameFlow
@onready var _betting: Betting = $Betting
@onready var _race: Race = $Race
@onready var _track: Track = $Track
@onready var _overlay: Overlay = $Overlay
@onready var _panel: ControlPanel = $ControlPanel


func _ready() -> void:
	Chat.command_received.connect(_flow.handle_command)
	Chat.command_received.connect(_betting.handle_command)
	_flow.state_changed.connect(_on_state_changed)
	_flow.player_joined.connect(_on_player_joined)
	_flow.countdown_tick.connect(_overlay.show_countdown)
	_flow.race_started.connect(_on_race_started)
	_flow.player_joined.connect(_betting.add_contestant)
	_flow.state_changed.connect(_betting.on_state_changed)
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
			_refresh_lobby()
		GameFlow.State.RACING:
			_overlay.show_racing()


func _on_player_joined(_contestant: Contestant) -> void:
	_refresh_lobby()


func _on_bet_placed(msg: ChatMessage, target: Contestant, amount: int) -> void:
	_overlay.show_notice("%s bet %d on %s" % [_viewer_name(msg), amount, target.display_name])


func _on_bet_rejected(msg: ChatMessage, reason: String) -> void:
	var text: String = BET_REJECTIONS.get(reason, "bet not accepted")
	_overlay.show_notice("%s: %s" % [_viewer_name(msg), text])


func _on_balance_reported(msg: ChatMessage, balance: int) -> void:
	_overlay.show_notice("%s has %d points" % [_viewer_name(msg), balance])


func _viewer_name(msg: ChatMessage) -> String:
	return msg.display_name if msg.display_name != "" else msg.login


func _on_race_started(contestants: Array[Contestant]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_race.start(_track, contestants.size(), rng)
	var marbles: Array[Marble] = _race.get_marbles()
	for i: int in contestants.size():
		marbles[i].color = contestants[i].color
		marbles[i].label_text = contestants[i].display_name


func _refresh_lobby() -> void:
	var names: PackedStringArray = []
	for contestant: Contestant in _flow.get_contestants():
		names.append(contestant.display_name)
	_overlay.show_lobby(names, _flow.max_players, _flow.timer if _flow.lobby_seconds > 0.0 else 0.0)


func _status_text() -> String:
	var state_name: String = GameFlow.State.keys()[_flow.state]
	return "%s, %d players" % [state_name, _flow.get_contestants().size()]
