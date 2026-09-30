class_name FinishReplay
extends Node
## Plays a [ReplayRecorder] clip back on the existing (frozen) marbles: slow motion around the
## winner's crossing. It only moves the marbles to recorded poses, nothing is simulated.

signal started
signal ended
## Emitted once, a moment before the clip runs out, so the picture can fade out under it.
signal ending

## Playback speed around the crossing, and how long that stretch lasts.
const SLOW_RATE: float = 0.3
const SLOW_BEFORE: float = 1.0
const SLOW_AFTER: float = 0.5
## Seconds (clip time) each side takes to ease between normal speed and slow motion.
const EASE_SECONDS: float = 0.3
## A finish this close between first and second place counts as a close one.
const CLOSE_GAP: float = 0.5
## Consecutive frames this far apart are a teleport (portal): snap instead of sliding.
const TELEPORT_DISTANCE: float = 250.0
## Clip seconds before the end at which [signal ending] fires.
const OUTRO_SECONDS: float = 0.3

var active: bool = false

var _recorder: ReplayRecorder
var _marbles: Dictionary = {}
var _clock: float = 0.0
var _frame: int = 0
var _event_index: int = 0
var _ending_sent: bool = false
var _crossed: Dictionary = {}
## Where each marble really ended up, put back when the replay ends.
var _home_positions: Dictionary = {}
## Visibility each marble had, and the state of each replayable map node, before the replay.
var _home_looks: Dictionary = {}
var _home_states: Array[PackedFloat32Array] = []
## Moving bodies under the replayable nodes, and whether each one synced to physics before.
## Untyped: a typed key that was freed makes iterating the dictionary raise an error.
var _home_sync: Dictionary = {}


## Playback speed at clip time `time` for a winner crossing at `finish_time`.
static func rate_at(time: float, finish_time: float) -> float:
	var slow_in: float = smoothstep(
		finish_time - SLOW_BEFORE - EASE_SECONDS, finish_time - SLOW_BEFORE, time
	)
	var slow_out: float = (
		1.0 - smoothstep(finish_time + SLOW_AFTER, finish_time + SLOW_AFTER + EASE_SECONDS, time)
	)
	return lerpf(1.0, SLOW_RATE, slow_in * slow_out)


## Real seconds the whole clip takes to play.
static func duration_of(start_time: float, end_time: float, finish_time: float) -> float:
	var step: float = 1.0 / 60.0
	var clock: float = start_time
	var real: float = 0.0
	while clock < end_time:
		clock += step * rate_at(clock, finish_time)
		real += step
	return real


## Whether a race with these results ([method Race.get_results] order) deserves a replay
## in "close finishes only" mode: a photo finish, or first and second crossed within
## [constant CLOSE_GAP] seconds.
static func is_close(results: Array[Dictionary], had_photo_finish: bool) -> bool:
	if had_photo_finish:
		return true
	if results.size() < 2 or not bool(results[0]["finished"]) or not bool(results[1]["finished"]):
		return false
	return float(results[1]["time"]) - float(results[0]["time"]) <= CLOSE_GAP


## Starts playing `recorder` on `marbles`. Returns false when there is nothing to play.
func start(recorder: ReplayRecorder, marbles: Array[Marble]) -> bool:
	if active or recorder == null or not recorder.has_clip():
		return false
	_recorder = recorder
	_marbles.clear()
	_crossed.clear()
	_home_positions.clear()
	_home_looks.clear()
	_home_states.clear()
	_home_sync.clear()
	for marble: Marble in marbles:
		if marble.id >= 0 and marble.id < recorder.marble_count:
			_marbles[marble.id] = marble
			marble.set_deferred("freeze", true)
			_home_positions[marble.id] = marble.global_position
			_home_looks[marble.id] = [marble.visible, marble.modulate.a]
			marble.replaying = true
	_begin_nodes()
	_clock = recorder.start_time()
	_frame = 0
	_event_index = 0
	_ending_sent = false
	active = true
	_apply()
	started.emit()
	return true


## Ends the replay right away and gives the marbles back.
func stop() -> void:
	_finish(true)


func _finish(restore: bool) -> void:
	if not active:
		return
	active = false
	for id: int in _marbles:
		var marble: Marble = _marbles[id]
		if not is_instance_valid(marble):
			continue
		marble.replaying = false
		if restore and marble.is_inside_tree():
			marble.global_position = _home_positions[id]
			marble.visible = _home_looks[id][0]
			marble.modulate.a = _home_looks[id][1]
	_end_nodes()
	_marbles.clear()
	if restore:
		ended.emit()


## Clip time now, in race seconds.
func clock() -> float:
	return _clock


func finish_time() -> float:
	return _recorder.finish_time() if _recorder != null else 0.0


## Where the winner is in the replay, also after they crossed the gate.
func winner_position() -> Vector2:
	var winner: Marble = _marbles.get(_recorder.winner_id()) if _recorder != null else null
	if winner == null or not is_instance_valid(winner):
		return Vector2.ZERO
	return winner.global_position


## Position of every marble that has not crossed the gate yet in the replay, id -> Vector2.
func get_position_map() -> Dictionary:
	var positions: Dictionary = {}
	for id: int in _marbles:
		if not _crossed.has(id):
			positions[id] = (_marbles[id] as Marble).global_position
	return positions


func _process(delta: float) -> void:
	if not active:
		return
	_clock += delta * rate_at(_clock, _recorder.finish_time())
	_apply()
	if not _ending_sent and _clock >= _recorder.end_time() - OUTRO_SECONDS:
		_ending_sent = true
		ending.emit()
	if _clock >= _recorder.end_time():
		stop()


func _exit_tree() -> void:
	# Leaving the scene is not a finished replay: nothing gets reported.
	_finish(false)


func _apply() -> void:
	var last: int = _recorder.frame_count() - 1
	while _frame < last - 1 and _recorder.frame_time(_frame + 1) <= _clock:
		_frame += 1
	var t0: float = _recorder.frame_time(_frame)
	var t1: float = _recorder.frame_time(_frame + 1)
	var weight: float = clampf((_clock - t0) / maxf(t1 - t0, 0.0001), 0.0, 1.0)
	for id: int in _marbles:
		var marble: Marble = _marbles[id]
		if not is_instance_valid(marble):
			continue
		var from: Vector2 = _recorder.position_at(_frame, id)
		var to: Vector2 = _recorder.position_at(_frame + 1, id)
		var mix: float = weight
		if from.distance_to(to) > TELEPORT_DISTANCE:
			mix = 0.0 if weight < 0.5 else 1.0
		marble.global_position = from.lerp(to, mix)
		marble.replay_velocity = _recorder.velocity_at(_frame, id).lerp(
			_recorder.velocity_at(_frame + 1, id), weight
		)
		var alpha: float = _recorder.alpha_at(_frame, id)
		alpha = lerpf(alpha, _recorder.alpha_at(_frame + 1, id), weight)
		marble.visible = alpha > 0.01
		marble.modulate.a = alpha
	_apply_nodes(weight)
	_play_events()


## Stops the live simulation of the map's replayable nodes, remembering how they stood.
func _begin_nodes() -> void:
	for node: Node in _recorder.nodes():
		if not is_instance_valid(node):
			_home_states.append(PackedFloat32Array())
			continue
		_home_states.append(node.call(Replayable.STATE_METHOD))
		node.set_physics_process(false)
		node.set_process(false)
		_free_moving_bodies(node)
		if node.has_method("replay_begin"):
			node.call("replay_begin")


func _apply_nodes(weight: float) -> void:
	var nodes: Array[Node] = _recorder.nodes()
	for n: int in nodes.size():
		if is_instance_valid(nodes[n]):
			nodes[n].call(
				Replayable.APPLY_METHOD,
				_recorder.node_state_at(_frame, n),
				_recorder.node_state_at(_frame + 1, n),
				weight
			)


## A body synced to physics ignores being moved outside a physics frame, but the replay moves
## things every rendered frame, so it is switched off while the replay plays.
func _free_moving_bodies(node: Node) -> void:
	if node is AnimatableBody2D and not _home_sync.has(node):
		var body: AnimatableBody2D = node as AnimatableBody2D
		_home_sync[body] = body.sync_to_physics
		body.sync_to_physics = false
	for child: Node in node.get_children():
		_free_moving_bodies(child)


## Puts the replayable nodes back as they were and lets them run again.
func _end_nodes() -> void:
	var nodes: Array[Node] = _recorder.nodes() if _recorder != null else []
	for n: int in mini(nodes.size(), _home_states.size()):
		var node: Node = nodes[n]
		if not is_instance_valid(node):
			continue
		node.call(Replayable.APPLY_METHOD, _home_states[n], _home_states[n], 0.0)
		node.set_physics_process(true)
		node.set_process(true)
		if node.has_method("replay_end"):
			node.call("replay_end")
	_home_states.clear()
	for key: Variant in _home_sync.keys():
		if is_instance_valid(key):
			(key as AnimatableBody2D).sync_to_physics = _home_sync[key]
	_home_sync.clear()


func _play_events() -> void:
	var events: Array[Dictionary] = _recorder.events()
	while _event_index < events.size() and float(events[_event_index]["time"]) <= _clock:
		_play_event(events[_event_index])
		_event_index += 1


func _play_event(event: Dictionary) -> void:
	if int(event["kind"]) == ReplayRecorder.Kind.BURST:
		_play_burst(event)
		return
	var id: int = int(event["id"])
	var marble: Marble = _marbles.get(id)
	if marble == null or not is_instance_valid(marble):
		return
	var at: Vector2 = event["position"]
	match int(event["kind"]):
		ReplayRecorder.Kind.SPLASH:
			_crossed[id] = true
			marble.splash()
			if id == _recorder.winner_id():
				marble.celebrate()
		ReplayRecorder.Kind.BOOST:
			RaceFx.burst(marble, at, RaceFx.BOOST_COLOR, 16, 130.0)
		ReplayRecorder.Kind.CURSE:
			RaceFx.burst(marble, at, RaceFx.CURSE_COLOR, 14, 70.0, Vector2(0, 30))


## A particle burst that belongs to the map, not to a fish.
func _play_burst(event: Dictionary) -> void:
	var data: Dictionary = event.get("data", {})
	RaceFx.burst(
		self,
		event["position"],
		data.get("color", Color.WHITE),
		int(data.get("amount", 14)),
		float(data.get("speed", 90.0)),
		data.get("gravity", Vector2(0, -40))
	)
