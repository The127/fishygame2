class_name Haunt
extends Node
## "#eddy": on a map that cuts fish from the race (see [RaceRounds]), a viewer whose fish was cut
## sends its ghost back out onto the course as an eddy. It is free. Anything that does not
## qualify is turned down with a reason the game words for the overlay.
##
## Rules: only while racing, only for a viewer who has a fish in this race, only once that fish was
## cut, and only as often as the viewer's cooldown allows. The race decides whether an eddy has
## room (see [member blocker]); a few can spin at the same time.
## The node emits [signal eddy_requested] for the race to apply; it touches no physics.

signal eddy_requested(marble_id: int)
signal eddy_sent(msg: ChatMessage, target: Contestant)
signal eddy_rejected(msg: ChatMessage, reason: String)

const COMMAND: String = "eddy"

## Seconds before the same viewer can send another eddy.
@export var viewer_cooldown: float = 8.0

## Asks the race why a fish cannot send an eddy: `(marble_id: int) -> String`, empty if it can.
## Set by the game.
var blocker: Callable = Callable()

var _racing: bool = false
var _clock: float = 0.0
var _roster: Array[Contestant] = []
## user_id -> clock time when the viewer may send another eddy
var _viewer_ready: Dictionary = {}


func _process(delta: float) -> void:
	tick(delta)


## Advances the cooldown clock. Called every frame; tests call it directly.
func tick(delta: float) -> void:
	if _racing:
		_clock += delta


## Feed it Chat.command_received.
func handle_command(msg: ChatMessage, command: String, _args: PackedStringArray) -> void:
	if command == COMMAND:
		send_eddy(msg)


## Returns true if the viewer's ghost was sent out.
func send_eddy(msg: ChatMessage) -> bool:
	var fish_id: int = _find_fish(msg.user_id)
	var reason: String = _check(msg, fish_id)
	if not reason.is_empty():
		eddy_rejected.emit(msg, reason)
		return false
	_viewer_ready[msg.user_id] = _clock + viewer_cooldown
	eddy_requested.emit(fish_id)
	eddy_sent.emit(msg, _roster[fish_id])
	return true


func add_contestant(contestant: Contestant) -> void:
	_roster.append(contestant)


## Feed it Race.race_finished, so a command in the frame the race ends is turned down.
func on_race_finished(_results: Array[Dictionary]) -> void:
	_racing = false


## Feed it GameFlow.state_changed.
func on_state_changed(new_state: GameFlow.State, _old_state: GameFlow.State) -> void:
	_racing = new_state == GameFlow.State.RACING
	if new_state == GameFlow.State.LOBBY or new_state == GameFlow.State.IDLE:
		_roster.clear()
	if new_state == GameFlow.State.RACING:
		_clock = 0.0
		_viewer_ready.clear()


## The rejection reason, or "" if the command is acceptable.
func _check(msg: ChatMessage, fish_id: int) -> String:
	if not _racing:
		return "closed"
	if fish_id < 0:
		return "no_fish"
	if blocker.is_valid():
		var reason: String = String(blocker.call(fish_id))
		if not reason.is_empty():
			return reason
	if _clock < float(_viewer_ready.get(msg.user_id, 0.0)):
		return "cooldown"
	return ""


## Roster index of the viewer's fish, or -1.
func _find_fish(user_id: String) -> int:
	for i: int in _roster.size():
		if _roster[i].user_id == user_id:
			return i
	return -1
