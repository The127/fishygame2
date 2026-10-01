extends GutTest
## Whirlpool: a real race with the vortex armed, recorded and replayed. The swirl angle, the
## surge and the telegraph glow all play back as they happened.

const TRACK_SCENE: String = "res://scenes/tracks/whirlpool_track.tscn"
const MARBLE_SCENE: String = "res://scenes/marble.tscn"

var _race: Race
var _track: Track
var _pool: Whirlpool
## Live look of the vortex around each recorded frame, by frame time: after that physics frame
## and after the two before it (the recorder may sample before or after the vortex updates).
var _seen: Dictionary = {}


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## [swirl angle, surge, phase, time in phase]: what the vortex draws from.
func _live_look() -> Array:
	return [_pool._turn, _pool._surge, float(_pool.phase), _pool.phase_time]


func _matches(live: Array, options: Array) -> bool:
	for option: Array in options:
		var same: bool = true
		for i: int in live.size():
			same = same and is_equal_approx(float(live[i]), float(option[i]))
		if same:
			return true
	return false


func _record_race() -> ReplayRecorder:
	_track = (load(TRACK_SCENE) as PackedScene).instantiate() as Track
	add_child_autofree(_track)
	_race = Race.new()
	_race.marble_scene = load(MARBLE_SCENE) as PackedScene
	add_child_autofree(_race)
	_race.start(_track, 3, _rng(4), 5)
	_pool = _track.get_hazards()[0] as Whirlpool
	_pool.arm(1, 5)
	var recorder: ReplayRecorder = _race.get_recorder()
	# The surge is well under way a moment after the telegraph turns into the event.
	var finish_at: float = _pool.get_schedule()[0] + _pool.telegraph_seconds + 0.8
	var finished: bool = false
	var frames: int = 0
	var history: Array = [_live_look(), _live_look()]
	while not recorder.is_done() and frames < 2000:
		await get_tree().physics_frame
		frames += 1
		var count: int = recorder.frame_count()
		var key: float = snappedf(recorder.frame_time(count - 1), 0.0001) if count > 0 else -1.0
		if count > 0 and not _seen.has(key):
			_seen[key] = [_live_look(), history[0], history[1]]
		history = [_live_look(), history[0]]
		if not finished and _pool.clock >= finish_at:
			finished = true
			_track.marble_reached_finish.emit(_race.get_marbles()[0])
	return recorder


func _replay(recorder: ReplayRecorder) -> FinishReplay:
	var replay: FinishReplay = FinishReplay.new()
	add_child_autofree(replay)
	assert_true(replay.start(recorder, _race.get_marbles()))
	return replay


func test_replayed_vortex_matches_the_race_across_telegraph_and_surge() -> void:
	var recorder: ReplayRecorder = await _record_race()
	assert_true(recorder.has_clip())
	var replay: FinishReplay = _replay(recorder)
	var phases: Dictionary = {}
	var compared: int = 0
	for k: int in recorder.frame_count() - 1:
		var key: float = snappedf(recorder.frame_time(k), 0.0001)
		if not _seen.has(key):
			continue
		replay._frame = k
		replay._clock = recorder.frame_time(k)
		replay._apply()
		phases[_pool.phase] = true
		compared += 1
		assert_true(_matches(_live_look(), _seen[key]), "frame %d" % k)
	assert_true(compared > 30, "compared %d frames" % compared)
	assert_true(phases.has(Hazard.Phase.TELEGRAPH), "the clip shows the telegraph")
	assert_true(phases.has(Hazard.Phase.ACTIVE), "the clip shows the surge")
	replay.stop()


func test_between_frames_the_swirl_blends_and_phase_and_spin_switch() -> void:
	var recorder: ReplayRecorder = await _record_race()
	var replay: FinishReplay = _replay(recorder)
	var index: int = recorder.nodes().find(_pool)
	var crossed: bool = false
	var blended: bool = false
	for k: int in recorder.frame_count() - 1:
		var from: PackedFloat32Array = recorder.node_state_at(k, index)
		var to: PackedFloat32Array = recorder.node_state_at(k + 1, index)
		replay._frame = k
		replay._clock = lerpf(recorder.frame_time(k), recorder.frame_time(k + 1), 0.5)
		if absf(from[3] - to[3]) > 0.001:
			replay._apply()
			blended = true
			assert_almost_eq(_pool._turn, (from[3] + to[3]) * 0.5, 0.001, "swirl angle blends")
		if int(from[1]) == Hazard.Phase.TELEGRAPH and int(to[1]) == Hazard.Phase.ACTIVE:
			crossed = true
			replay._clock = lerpf(recorder.frame_time(k), recorder.frame_time(k + 1), 0.25)
			replay._apply()
			assert_eq(_pool.phase, Hazard.Phase.TELEGRAPH)
			assert_almost_eq(_pool.phase_time, from[2], 0.0001, "telegraph timer not blended")
			replay._clock = lerpf(recorder.frame_time(k), recorder.frame_time(k + 1), 0.75)
			replay._apply()
			assert_eq(_pool.phase, Hazard.Phase.ACTIVE)
			assert_almost_eq(_pool.phase_time, to[2], 0.0001, "event timer not blended")
	assert_true(blended)
	assert_true(crossed, "the clip crosses from telegraph to active")
	replay.stop()


func test_the_vortex_is_put_back_after_the_replay() -> void:
	var recorder: ReplayRecorder = await _record_race()
	var before: Array = _live_look()
	var replay: FinishReplay = _replay(recorder)
	replay._frame = 0
	replay._clock = recorder.frame_time(0)
	replay._apply()
	replay.stop()
	assert_true(_matches(_live_look(), [before]), "same state as when the race ended")
