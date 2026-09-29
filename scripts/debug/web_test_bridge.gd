class_name WebTestBridge
extends Node
## Lets the browser smoke test (tests/browser) drive and read the game. Web + debug mode only.
## Exposes window.fishyTest: `act(name, a, b)` drives the game, `state` is a JSON snapshot.

## How often the snapshot is refreshed, in seconds.
const STATE_INTERVAL: float = 0.1

var _flow: GameFlow
var _betting: Betting
var _panel: ControlPanel
var _api: JavaScriptObject
var _act_callback: JavaScriptObject
var _elapsed: float = 0.0
var _podiums: int = 0
var _last_podium: Array[String] = []
var _bet_reasons: Array[String] = []
## user_id -> true, for the viewers whose balance goes into the snapshot.
var _watched: Dictionary[String, bool] = {}


func setup(flow: GameFlow, betting: Betting, panel: ControlPanel) -> void:
	_flow = flow
	_betting = betting
	_panel = panel
	_flow.podium_ready.connect(_on_podium_ready)
	_betting.bet_rejected.connect(_on_bet_rejected)
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	_api = JavaScriptBridge.create_object("Object")
	_act_callback = JavaScriptBridge.create_callback(_on_act)
	_api.set("act", _act_callback)
	window.set("fishyTest", _api)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= STATE_INTERVAL:
		_elapsed = 0.0
		_api.set("state", JSON.stringify(_snapshot()))


func _snapshot() -> Dictionary:
	var balances: Dictionary = {}
	for user_id: String in _watched:
		balances[user_id] = _betting.points.get_balance(user_id)
	return {
		"flow": GameFlow.State.keys()[_flow.state],
		"fps": Engine.get_frames_per_second(),
		"players": _flow.get_contestants().size(),
		"podiums": _podiums,
		"podium": _last_podium,
		"balances": balances,
		"bet_rejections": _bet_reasons,
	}


## act("open"), act("start"), act("stop"), act("players", count),
## act("chat", user_id, text), which also tracks that viewer's balance.
func _on_act(args: Array) -> void:
	var action: String = str(args[0])
	match action:
		"open":
			_panel.open_lobby_pressed.emit()
		"start":
			_panel.start_pressed.emit()
		"stop":
			_panel.stop_pressed.emit()
		"players":
			_panel.add_debug_players_pressed.emit(int(args[1]))
		"chat":
			var user_id: String = str(args[1])
			_watched[user_id] = true
			var source: DebugChatSource = Chat.source as DebugChatSource
			if source != null:
				source.inject(user_id, user_id, str(args[2]))
		_:
			push_warning("fishyTest: unknown action %s" % action)


func _on_podium_ready(podium: Array[Dictionary]) -> void:
	_podiums += 1
	_last_podium = []
	for entry: Dictionary in podium:
		_last_podium.append(str(entry["name"]))


func _on_bet_rejected(_msg: ChatMessage, reason: String) -> void:
	_bet_reasons.append(reason)
