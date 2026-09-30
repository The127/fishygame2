class_name FinishReplay
extends Node
## Plays a [ReplayRecorder] clip back on the existing (frozen) marbles: slow motion around the
## winner's crossing. It only moves the marbles to recorded poses, nothing is simulated.

signal started
signal ended

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

var active: bool = false

var _recorder: ReplayRecorder
var _marbles: Dictionary = {}
var _clock: float = 0.0
var _frame: int = 0
var _event_index: int = 0
var _crossed: Dictionary = {}
## Where each marble really ended up, put back when the replay ends.
var _home_positions: Dictionary = {}


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
	for marble: Marble in marbles:
		if marble.id >= 0 and marble.id < recorder.marble_count:
			_marbles[marble.id] = marble
			marble.set_deferred("freeze", true)
			_home_positions[marble.id] = marble.global_position
			marble.replaying = true
	_clock = recorder.start_time()
	_frame = 0
	_event_index = 0
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
	_marbles.clear()
	if restore:
		ended.emit()


## Clip time now, in race seconds.
func clock() -> float:
	return _clock


func finish_time() -> float:
	return _recorder.finish_time() if _recorder != null else 0.0


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
	_play_events()


func _play_events() -> void:
	var events: Array[Dictionary] = _recorder.events()
	while _event_index < events.size() and float(events[_event_index]["time"]) <= _clock:
		_play_event(events[_event_index])
		_event_index += 1


func _play_event(event: Dictionary) -> void:
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
