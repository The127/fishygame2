class_name GameFlow
extends Node
## Round state machine: IDLE -> LOBBY -> COUNTDOWN -> RACING -> PODIUM -> LOBBY.
## It owns the roster and the timers but no physics; the game scene starts the
## race when [signal race_started] fires and reports back via [method report_race_finished].

signal state_changed(new_state: State, old_state: State)
signal player_joined(contestant: Contestant)
signal join_rejected(msg: ChatMessage, reason: String)
signal countdown_tick(seconds_left: int)
signal race_started(contestants: Array[Contestant])
signal podium_ready(podium: Array[Dictionary])

enum State { IDLE, LOBBY, COUNTDOWN, RACING, PODIUM }

@export var max_players: int = 20
## Seconds before the lobby starts the race on its own. 0 or less means manual start only.
@export var lobby_seconds: float = 0.0
## Players needed before a round can start. Never below 1.
@export var min_players: int = 1:
	set(value):
		min_players = maxi(value, 1)
@export var countdown_seconds: int = 3
@export var podium_seconds: float = 8.0
@export var podium_size: int = 3

## Auto mode: the lobby closes after [member auto_lobby_seconds] and the round cycles on its
## own. Change it with [method set_auto_mode]. Off means manual start only.
var auto_mode: bool = false
## Join window of auto mode in seconds.
var auto_lobby_seconds: float = 60.0

var state: State = State.IDLE
var timer: float = 0.0

var _contestants: Array[Contestant] = []
var _ids: Dictionary = {}
var _last_tick: int = 0
var _debug_count: int = 0


func _process(delta: float) -> void:
	tick(delta)


## Advances the timers. Called every frame; tests call it directly.
func tick(delta: float) -> void:
	match state:
		State.LOBBY:
			if lobby_seconds <= 0.0:
				return
			timer -= delta
			if timer <= 0.0:
				if _contestants.size() >= min_players:
					start_race()
				else:
					timer = lobby_seconds
		State.COUNTDOWN:
			timer -= delta
			if timer <= 0.0:
				_begin_race()
			else:
				var whole: int = ceili(timer)
				if whole != _last_tick:
					_last_tick = whole
					countdown_tick.emit(whole)
		State.PODIUM:
			timer -= delta
			if timer <= 0.0:
				open_lobby()


## Turns auto mode on or off. An open lobby picks it up right away: turning it on starts a
## fresh join window, turning it off leaves the lobby open until the streamer starts.
func set_auto_mode(enabled: bool, join_seconds: float = auto_lobby_seconds) -> void:
	auto_mode = enabled
	auto_lobby_seconds = join_seconds
	lobby_seconds = auto_lobby_seconds if enabled else 0.0
	if state == State.LOBBY:
		timer = lobby_seconds


## Opens a fresh lobby (empty roster). Allowed from IDLE and PODIUM.
func open_lobby() -> bool:
	if state != State.IDLE and state != State.PODIUM:
		return false
	_contestants.clear()
	_ids.clear()
	_debug_count = 0
	timer = lobby_seconds
	_set_state(State.LOBBY)
	return true


## Streamer start. Needs a lobby with at least min_players.
func start_race() -> bool:
	if state != State.LOBBY or _contestants.size() < min_players:
		return false
	timer = float(countdown_seconds)
	_last_tick = countdown_seconds
	_set_state(State.COUNTDOWN)
	if countdown_seconds > 0:
		countdown_tick.emit(countdown_seconds)
	else:
		_begin_race()
	return true


## Aborts the round and returns to IDLE from any state.
func stop() -> void:
	if state == State.IDLE:
		return
	_contestants.clear()
	_ids.clear()
	_set_state(State.IDLE)


## Feed it the results of Race.race_finished (ids are roster indexes). Only fish that
## finished get a podium place; the rest are DNF and are left off.
func report_race_finished(results: Array[Dictionary]) -> void:
	if state != State.RACING:
		return
	var podium: Array[Dictionary] = []
	for r: Dictionary in results:
		if podium.size() >= podium_size or not bool(r["finished"]):
			break
		var contestant: Contestant = _contestants[int(r["id"])]
		(
			podium
			. append(
				{
					"id": int(r["id"]),
					"place": int(r["place"]),
					"user_id": contestant.user_id,
					"name": contestant.display_name,
					"color": contestant.color,
					"species": contestant.species,
					"pattern": contestant.pattern,
					"accessory": contestant.accessory,
					"time": float(r["time"]),
					"finished": bool(r["finished"]),
				}
			)
		)
	timer = podium_seconds
	_set_state(State.PODIUM)
	podium_ready.emit(podium)


## Adds fake viewers to the open lobby through the normal join path. Returns how many joined.
func add_debug_players(count: int) -> int:
	var added: int = 0
	while added < count and state == State.LOBBY and _contestants.size() < max_players:
		_debug_count += 1
		var user_id: String = "debug_%d" % _debug_count
		var msg := ChatMessage.create(user_id, user_id, "Debug%d" % _debug_count, "#join")
		if join(msg):
			added += 1
	return added


## Chat entry point; connect Chat.command_received to it.
func handle_command(msg: ChatMessage, command: String, _args: PackedStringArray) -> void:
	if command == "join":
		join(msg)


func join(msg: ChatMessage) -> bool:
	if state != State.LOBBY:
		join_rejected.emit(msg, "closed")
		return false
	if _ids.has(msg.user_id):
		join_rejected.emit(msg, "duplicate")
		return false
	if _contestants.size() >= max_players:
		join_rejected.emit(msg, "full")
		return false
	var name_to_show: String = msg.display_name if msg.display_name != "" else msg.login
	var contestant: Contestant = Contestant.create(msg.user_id, name_to_show, _contestants.size())
	_ids[msg.user_id] = true
	_contestants.append(contestant)
	player_joined.emit(contestant)
	return true


## Chat reply for a rejected join, or "" when the rejection should stay silent.
static func rejection_text(reason: String, msg: ChatMessage) -> String:
	var who: String = msg.display_name if msg.display_name != "" else msg.login
	match reason:
		"full":
			return "@%s the lobby is full." % who
		"closed":
			return "@%s there is no open lobby right now." % who
	return ""


func get_contestants() -> Array[Contestant]:
	return _contestants.duplicate()


func _begin_race() -> void:
	_set_state(State.RACING)
	race_started.emit(get_contestants())


func _set_state(new_state: State) -> void:
	var old_state: State = state
	state = new_state
	state_changed.emit(new_state, old_state)
