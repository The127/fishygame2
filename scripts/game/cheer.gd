class_name Cheer
extends Node
## Free cheering: during a race, a chat message that names a fish (or "@name") and
## contains at least one emote gives that fish a small forward nudge.
##
## The nudge grows with the emote count up to [member max_emotes]. Each viewer has a
## cooldown and each fish has a lockout, so cheering alone cannot decide a race.
## The node emits [signal cheer_requested] for the race to apply; it touches no physics.

## strength is the nudge in emote units: the number of emotes counted, scaled by the
## strength setting (1.0 = one emote at the default strength).
signal cheer_requested(marble_id: int, strength: float)
signal cheer_applied(msg: ChatMessage, target: Contestant, emote_count: int)

## Messages starting with this are commands, not cheers.
@export var command_prefix: String = "#"
## Percent of the default nudge. 0 turns cheering off.
@export var strength_percent: int = 100
## Seconds before the same viewer can cheer again.
@export var viewer_cooldown: float = 10.0
## Seconds before the same fish can be cheered again.
@export var fish_cooldown: float = 2.0
## Emotes beyond this in one message are not counted.
@export var max_emotes: int = 5

var _racing: bool = false
var _clock: float = 0.0
var _roster: Array[Contestant] = []
var _finished: Dictionary = {}
## user_id -> clock time when the viewer may cheer again
var _viewer_ready: Dictionary = {}
## marble id -> clock time when the fish may be cheered again
var _fish_ready: Dictionary = {}


func _process(delta: float) -> void:
	tick(delta)


## Advances the cooldown clock. Called every frame; tests call it directly.
func tick(delta: float) -> void:
	if _racing:
		_clock += delta


## Feed it Chat.message_received. Returns true if the message cheered a fish.
func handle_message(msg: ChatMessage) -> bool:
	if not _racing or strength_percent <= 0 or msg.emotes.is_empty():
		return false
	if not command_prefix.is_empty() and msg.text.strip_edges().begins_with(command_prefix):
		return false
	var target_id: int = find_fish(msg.text)
	if target_id < 0 or _finished.has(target_id):
		return false
	if _clock < float(_viewer_ready.get(msg.user_id, 0.0)):
		return false
	if _clock < float(_fish_ready.get(target_id, 0.0)):
		return false
	var count: int = mini(msg.emotes.size(), maxi(max_emotes, 1))
	_viewer_ready[msg.user_id] = _clock + viewer_cooldown
	_fish_ready[target_id] = _clock + fish_cooldown
	cheer_requested.emit(target_id, float(count) * float(strength_percent) / 100.0)
	cheer_applied.emit(msg, _roster[target_id], count)
	return true


## Roster index of the fish named first in the text, or -1. A name matches as whole
## words, with an optional leading "@" and trailing punctuation, ignoring case.
func find_fish(text: String) -> int:
	var words: PackedStringArray = []
	for word: String in text.to_lower().split(" ", false):
		words.append(word.trim_prefix("@").rstrip(".,!?:;"))
	var padded: String = " " + " ".join(words) + " "
	var best_id: int = -1
	var best_at: int = -1
	for i: int in _roster.size():
		var fish_name: String = _roster[i].display_name.to_lower()
		if fish_name.is_empty():
			continue
		var at: int = padded.find(" " + fish_name + " ")
		if at >= 0 and (best_at < 0 or at < best_at):
			best_id = i
			best_at = at
	return best_id


func add_contestant(contestant: Contestant) -> void:
	_roster.append(contestant)


## Feed it Race.marble_finished. Marble ids are roster indices.
func on_marble_finished(id: int, _place: int) -> void:
	_finished[id] = true


## Feed it Race.race_finished, so a message in the frame the race ends is not counted.
func on_race_finished(_results: Array[Dictionary]) -> void:
	_racing = false


## Feed it GameFlow.state_changed.
func on_state_changed(new_state: GameFlow.State, _old_state: GameFlow.State) -> void:
	_racing = new_state == GameFlow.State.RACING
	if new_state == GameFlow.State.LOBBY or new_state == GameFlow.State.IDLE:
		_roster.clear()
	if new_state == GameFlow.State.RACING:
		_clock = 0.0
		_finished.clear()
		_viewer_ready.clear()
		_fish_ready.clear()
