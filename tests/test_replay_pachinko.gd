extends GutTest
## Pachinko's eel hazard in the finish replay: a real race with the hazard armed is recorded
## across a telegraph/active boundary and the replay shows what the recording holds.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const MAP_ID: String = "pachinko"
const STEP: float = 1.0 / 60.0
## Seconds into the active phase at which the winner crosses the gate.
const FINISH_AFTER_ACTIVE: float = 0.6

var _track: Track
var _race: Race
var _hazard: EelHazard


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Runs a real race on the map until the hazard has been active for a moment, then lets the
## first fish cross the gate and runs on until the recording is complete.
func _record_race() -> ReplayRecorder:
	_track = TrackCatalog.instantiate(MAP_ID)
	add_child_autofree(_track)
	_race = Race.new()
	_race.marble_scene = load(MARBLE_SCENE) as PackedScene
	add_child_autofree(_race)
	_race.start(_track, 4, _rng(11), 5)
	_hazard = _track.get_hazards()[0] as EelHazard
	var recorder: ReplayRecorder = _race.get_recorder()
	var frames: int = 0
	while frames < 60 * 40 and not _hazard_active_long_enough():
		await get_tree().physics_frame
		frames += 1
	_track.marble_reached_finish.emit(_race.get_marbles()[0])
	while _race.running and not recorder.is_done() and frames < 60 * 60:
		await get_tree().physics_frame
		frames += 1
	return recorder


func _hazard_active_long_enough() -> bool:
	return _hazard.phase == Hazard.Phase.ACTIVE and _hazard.phase_time >= FINISH_AFTER_ACTIVE


## The eel is one of several replayed parts (spinners and bumpers join too).
func _node_index(recorder: ReplayRecorder) -> int:
	return recorder.nodes().find(_hazard)


func _start_replay(recorder: ReplayRecorder) -> FinishReplay:
	var replay: FinishReplay = FinishReplay.new()
	add_child_autofree(replay)
	assert_true(replay.start(recorder, _race.get_marbles()))
	return replay


func _phases(recorder: ReplayRecorder) -> Array[int]:
	var phases: Array[int] = []
	for k: int in recorder.frame_count():
		phases.append(int(recorder.node_state_at(k, _node_index(recorder))[1]))
	return phases


func _check_the_recording_spans_telegraph_and_active(recorder: ReplayRecorder) -> void:
	assert_true(recorder.has_clip())
	var phases: Array[int] = _phases(recorder)
	assert_true(phases.has(Hazard.Phase.TELEGRAPH), "telegraph is in the clip")
	assert_true(phases.has(Hazard.Phase.ACTIVE), "active is in the clip")
	assert_lt(phases.find(Hazard.Phase.TELEGRAPH), phases.find(Hazard.Phase.ACTIVE))


func _check_every_recorded_frame_replays_as_recorded(recorder: ReplayRecorder) -> void:
	var replay: FinishReplay = _start_replay(recorder)
	for k: int in recorder.frame_count():
		replay._clock = recorder.frame_time(k)
		replay._apply()
		var recorded: PackedFloat32Array = recorder.node_state_at(
			replay._frame, _node_index(recorder)
		)
		var blend: float = 0.0
		if replay._frame != k:
			# Landed on the closing frame of the last pair.
			blend = 1.0
			recorded = recorder.node_state_at(replay._frame + 1, _node_index(recorder))
		assert_eq(_hazard.replay_state(), recorded, "frame %d (%.2f)" % [k, blend])
		_assert_looks_like_recorded(recorded)
	replay.stop()


## The eel the viewer sees (route, angle, head) follows the recorded state.
func _assert_looks_like_recorded(recorded: PackedFloat32Array) -> void:
	var phase: int = int(recorded[1])
	assert_eq(int(_hazard.phase), phase)
	var at: int = Hazard.REPLAY_BASE
	assert_eq(_hazard._on_route, recorded[at] > 0.5, "on the route as recorded")
	if phase == Hazard.Phase.IDLE:
		assert_false(_hazard._on_route, "no eel while idle")
		return
	assert_true(_hazard._on_route, "the eel is drawn during the event")
	assert_eq(_hazard._start, Vector2(recorded[at + 1], recorded[at + 2]))
	assert_eq(_hazard._end, Vector2(recorded[at + 3], recorded[at + 4]))
	assert_eq(_hazard._angle, recorded[at + 5])


func _check_frames_between_recordings_follow_the_nearer_one_across_the_boundary(
	recorder: ReplayRecorder
) -> void:
	var replay: FinishReplay = _start_replay(recorder)
	var crossed: bool = false
	for k: int in recorder.frame_count() - 1:
		var from: PackedFloat32Array = recorder.node_state_at(k, _node_index(recorder))
		var to: PackedFloat32Array = recorder.node_state_at(k + 1, _node_index(recorder))
		for weight: float in [0.25, 0.75]:
			replay._frame = k
			replay._clock = lerpf(recorder.frame_time(k), recorder.frame_time(k + 1), weight)
			replay._apply()
			var nearer: PackedFloat32Array = from if weight < 0.5 else to
			assert_eq(int(_hazard.phase), int(nearer[1]), "phase at frame %d, %.2f" % [k, weight])
			# Inside a phase the timer is blended, across a boundary it is not.
			var timer: float = lerpf(from[2], to[2], weight) if from[1] == to[1] else nearer[2]
			assert_almost_eq(_hazard.phase_time, timer, 0.0001, "phase time at frame %d" % k)
			assert_almost_eq(_hazard.clock, lerpf(from[0], to[0], weight), 0.0001)
			_assert_looks_like_recorded(nearer)
		crossed = crossed or (from[1] != to[1] and to[1] == float(Hazard.Phase.ACTIVE))
	assert_true(crossed, "a telegraph to active boundary was replayed")
	replay.stop()


func _check_the_eel_swims_along_its_route(recorder: ReplayRecorder) -> void:
	var replay: FinishReplay = _start_replay(recorder)
	var heads: Array[Vector2] = []
	for k: int in recorder.frame_count():
		replay._clock = recorder.frame_time(k)
		replay._apply()
		if _hazard.phase == Hazard.Phase.ACTIVE:
			heads.append(_hazard._head)
			var along: Vector2 = (_hazard._end - _hazard._start).normalized()
			var offset: Vector2 = _hazard._head - _hazard._start
			assert_almost_eq(offset.cross(along), 0.0, 0.5, "the head stays on the route")
	assert_gt(heads.size(), 2)
	assert_gt(heads[0].distance_to(heads[-1]), 10.0, "the head moves during the replay")
	replay.stop()


func _check_the_live_hazard_is_put_back_after_the_replay(recorder: ReplayRecorder) -> void:
	var before: PackedFloat32Array = _hazard.replay_state()
	var replay: FinishReplay = _start_replay(recorder)
	assert_false(_hazard.is_physics_processing(), "the hazard stands still while replaying")
	replay._clock = recorder.frame_time(recorder.frame_count() / 2)
	replay._apply()
	replay.stop()
	assert_eq(_hazard.replay_state(), before)
	assert_true(_hazard.is_physics_processing())


## One recorded race feeds every check: recording a real race takes several seconds.
func test_a_real_race_replays_its_eel_hazard() -> void:
	var recorder: ReplayRecorder = await _record_race()
	_check_the_recording_spans_telegraph_and_active(recorder)
	_check_every_recorded_frame_replays_as_recorded(recorder)
	_check_frames_between_recordings_follow_the_nearer_one_across_the_boundary(recorder)
	_check_the_eel_swims_along_its_route(recorder)
	_check_the_live_hazard_is_put_back_after_the_replay(recorder)
