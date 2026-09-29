class_name Chaos
extends Node
## Viewers spend points during a race to push a fish around: "#boost <name>" gives
## it a forward kick, "#curse <name>" knocks it back and slows it.
##
## Rules: only while racing, and only on a fish that has not finished. Points are
## taken when the effect is applied. Each viewer has a cooldown between uses and
## each fish has a lockout between effects, so nobody decides a race alone.
## The node emits [signal effect_requested] for the race to apply; it touches no physics.

signal effect_requested(marble_id: int, kind: Kind)
signal effect_applied(msg: ChatMessage, target: Contestant, kind: Kind, cost: int)
signal effect_rejected(msg: ChatMessage, reason: String)

enum Kind { BOOST, CURSE }

@export var points_path: String = "user://points.json"
@export var boost_cost: int = 100
@export var curse_cost: int = 150
## Seconds before the same viewer can use another effect.
@export var viewer_cooldown: float = 20.0
## Seconds before the same fish can be hit by another effect.
@export var fish_lockout: float = 5.0

## Set by the game so chaos spends from the same balances as betting.
var points: PointsStore = null

var _racing: bool = false
var _clock: float = 0.0
var _roster: Array[Contestant] = []
var _finished: Dictionary = {}
## user_id -> clock time when the viewer may act again
var _viewer_ready: Dictionary = {}
## marble id -> clock time when the fish may be hit again
var _fish_ready: Dictionary = {}
## user_id -> points spent on effects this race, refunded if the round is aborted.
## Also held as stakes in the points store so a reload mid-race refunds them.
var _spent: Dictionary = {}


func _ready() -> void:
	if points == null:
		points = PointsStore.new(points_path, 1000)
		points.load_from_disk()


func _process(delta: float) -> void:
	tick(delta)


## Advances the cooldown clock. Called every frame; tests call it directly.
func tick(delta: float) -> void:
	if _racing:
		_clock += delta


func handle_command(msg: ChatMessage, command: String, args: PackedStringArray) -> void:
	match command:
		"boost":
			use_effect(msg, args, Kind.BOOST)
		"curse":
			use_effect(msg, args, Kind.CURSE)


func cost_of(kind: Kind) -> int:
	return boost_cost if kind == Kind.BOOST else curse_cost


## Chat entry point for "#boost <name>" and "#curse <name>". Returns true if applied.
func use_effect(msg: ChatMessage, args: PackedStringArray, kind: Kind) -> bool:
	var reason: String = _check(msg, args, kind)
	var target_id: int = _find_contestant_index(" ".join(args)) if not args.is_empty() else -1
	if reason.is_empty() and not points.try_debit(msg.user_id, cost_of(kind)):
		reason = "insufficient"
	if not reason.is_empty():
		effect_rejected.emit(msg, reason)
		return false
	_spent[msg.user_id] = int(_spent.get(msg.user_id, 0)) + cost_of(kind)
	points.add_stake(msg.user_id, cost_of(kind))
	points.save_to_disk()
	_viewer_ready[msg.user_id] = _clock + viewer_cooldown
	_fish_ready[target_id] = _clock + fish_lockout
	effect_requested.emit(target_id, kind)
	effect_applied.emit(msg, _roster[target_id], kind, cost_of(kind))
	return true


func add_contestant(contestant: Contestant) -> void:
	_roster.append(contestant)


## Feed it Race.marble_finished. Marble ids are roster indices.
func on_marble_finished(id: int, _place: int) -> void:
	_finished[id] = true


## Feed it Race.race_finished. Closes chaos at once, so a command arriving in the same
## frame the race ends is rejected instead of charging for an effect that cannot land.
func on_race_finished(_results: Array[Dictionary]) -> void:
	_racing = false


## Feed it GameFlow.state_changed.
func on_state_changed(new_state: GameFlow.State, old_state: GameFlow.State) -> void:
	_racing = new_state == GameFlow.State.RACING
	if new_state == GameFlow.State.IDLE and old_state == GameFlow.State.RACING:
		_refund_all()
	if new_state != GameFlow.State.RACING:
		_release_spent()
	if new_state == GameFlow.State.LOBBY or new_state == GameFlow.State.IDLE:
		_roster.clear()
	if new_state == GameFlow.State.RACING:
		_clock = 0.0
		_finished.clear()
		_viewer_ready.clear()
		_fish_ready.clear()
		_release_spent()


## Returns the rejection reason, or "" if the command is acceptable (before charging).
func _check(msg: ChatMessage, args: PackedStringArray, kind: Kind) -> String:
	if not _racing:
		return "closed"
	if args.is_empty():
		return "usage"
	var target_id: int = _find_contestant_index(" ".join(args))
	if target_id < 0:
		return "unknown_fish"
	var reason: String = ""
	if _finished.has(target_id):
		reason = "finished"
	elif _clock < float(_viewer_ready.get(msg.user_id, 0.0)):
		reason = "cooldown"
	elif _clock < float(_fish_ready.get(target_id, 0.0)):
		reason = "fish_busy"
	elif points.get_balance(msg.user_id) < cost_of(kind):
		reason = "insufficient"
	return reason


func _refund_all() -> void:
	for user_id: String in _spent:
		points.add(user_id, int(_spent[user_id]))
	_release_spent()


## The spend is final (or was just refunded): stop holding it as a stake.
func _release_spent() -> void:
	if _spent.is_empty():
		return
	for user_id: String in _spent:
		points.release_stake(user_id, int(_spent[user_id]))
	_spent.clear()
	points.save_to_disk()


func _find_contestant_index(text: String) -> int:
	var wanted: String = text.trim_prefix("@").to_lower()
	for i: int in _roster.size():
		if _roster[i].display_name.to_lower() == wanted:
			return i
	return -1
