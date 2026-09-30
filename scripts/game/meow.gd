class_name Meow
extends Node
## Hidden chat command: "#meow" makes the caller's own fish meow during a race.
##
## It is not listed in the help. Anything that does not qualify (not racing, no fish in
## this race, on cooldown) is ignored without a reply. Each viewer has a cooldown.
## The node emits [signal meow_requested] for the race to show; it touches no physics.

signal meow_requested(marble_id: int)

const COMMAND: String = "meow"

## Seconds before the same viewer can meow again.
@export var viewer_cooldown: float = 12.0

var _racing: bool = false
var _clock: float = 0.0
var _roster: Array[Contestant] = []
## user_id -> clock time when the viewer may meow again
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
		meow(msg)


## Returns true if the viewer's fish meowed.
func meow(msg: ChatMessage) -> bool:
	if not _racing or _clock < float(_viewer_ready.get(msg.user_id, 0.0)):
		return false
	var fish_id: int = _find_fish(msg.user_id)
	if fish_id < 0:
		return false
	_viewer_ready[msg.user_id] = _clock + viewer_cooldown
	meow_requested.emit(fish_id)
	return true


func add_contestant(contestant: Contestant) -> void:
	_roster.append(contestant)


## Feed it Race.race_finished, so a meow in the frame the race ends is dropped.
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


## Roster index of the viewer's fish, or -1.
func _find_fish(user_id: String) -> int:
	for i: int in _roster.size():
		if _roster[i].user_id == user_id:
			return i
	return -1
