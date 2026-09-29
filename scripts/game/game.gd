class_name Game
extends Node2D
## Wires chat commands, the round state machine, the race and the UI together.

var _map_choice: String = TrackCatalog.RANDOM_ID
var _map_id: String = ""
var _track: Track
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _flow: GameFlow = $GameFlow
@onready var _race: Race = $Race
@onready var _overlay: Overlay = $Overlay
@onready var _panel: ControlPanel = $ControlPanel


func _ready() -> void:
	Chat.command_received.connect(_flow.handle_command)
	_flow.state_changed.connect(_on_state_changed)
	_flow.player_joined.connect(_on_player_joined)
	_flow.countdown_tick.connect(_overlay.show_countdown)
	_flow.race_started.connect(_on_race_started)
	_flow.podium_ready.connect(_overlay.show_podium)
	_race.race_finished.connect(_flow.report_race_finished)
	_panel.open_lobby_pressed.connect(_flow.open_lobby)
	_panel.start_pressed.connect(_flow.start_race)
	_panel.stop_pressed.connect(_flow.stop)
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
	return (
		"%s, %d players, map: %s"
		% [state_name, _flow.get_contestants().size(), TrackCatalog.get_name_of(_map_id)]
	)
