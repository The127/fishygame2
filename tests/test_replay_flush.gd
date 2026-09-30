extends GutTest
## Toilet Flush in the finish replay: the duck keeps bobbing and the cistern lever follows the
## flush, both as they were recorded.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
## Seconds into the flush at which the winner crosses the gate, so the lever is down.
const FINISH_AFTER_ACTIVE: float = 1.0

var _track: Track
var _race: Race
var _bowl: FlushBowl
var _duck: DuckBumper


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _record_race() -> ReplayRecorder:
	_track = TrackCatalog.instantiate("flush")
	add_child_autofree(_track)
	_race = Race.new()
	_race.marble_scene = load(MARBLE_SCENE) as PackedScene
	add_child_autofree(_race)
	_race.start(_track, 4, _rng(11), 5)
	_bowl = _track.get_node("Bowl") as FlushBowl
	_duck = _track.get_node("Duck") as DuckBumper
	var recorder: ReplayRecorder = _race.get_recorder()
	var frames: int = 0
	while frames < 60 * 40 and not _flush_under_way():
		await get_tree().physics_frame
		frames += 1
	_track.marble_reached_finish.emit(_race.get_marbles()[0])
	while _race.running and not recorder.is_done() and frames < 60 * 60:
		await get_tree().physics_frame
		frames += 1
	return recorder


func _flush_under_way() -> bool:
	return _bowl.phase == Hazard.Phase.ACTIVE and _bowl.phase_time >= FINISH_AFTER_ACTIVE


func _start_replay(recorder: ReplayRecorder) -> FinishReplay:
	var replay: FinishReplay = FinishReplay.new()
	add_child_autofree(replay)
	assert_true(replay.start(recorder, _race.get_marbles()))
	return replay


func test_the_duck_replays_where_it_was_and_moves_during_the_clip() -> void:
	var recorder: ReplayRecorder = await _record_race()
	assert_true(recorder.has_clip())
	var index: int = recorder.nodes().find(_duck)
	assert_ne(index, -1, "the duck is recorded")
	var replay: FinishReplay = _start_replay(recorder)
	var phases: Dictionary = {}
	for k: int in recorder.frame_count():
		replay._clock = recorder.frame_time(k)
		replay._apply()
		var recorded: PackedFloat32Array = recorder.node_state_at(replay._frame, index)
		if replay._frame != k:
			recorded = recorder.node_state_at(replay._frame + 1, index)
		assert_eq(_duck.replay_state(), recorded, "frame %d" % k)
		assert_eq(_duck.position, _duck.path_at(_duck.get_phase()), "frame %d position" % k)
		phases[snappedf(_duck.get_phase(), 0.001)] = true
	assert_gt(phases.size(), 10, "the duck moves through the clip")
	replay.stop()


func test_the_lever_is_down_in_the_replayed_flush() -> void:
	var recorder: ReplayRecorder = await _record_race()
	var replay: FinishReplay = _start_replay(recorder)
	var lowest: float = 0.0
	var phases: Dictionary = {}
	for k: int in recorder.frame_count():
		replay._clock = recorder.frame_time(k)
		replay._apply()
		phases[_bowl.phase] = true
		lowest = maxf(lowest, _bowl.get_lever_angle())
	assert_true(phases.has(Hazard.Phase.ACTIVE), "the clip shows the flush")
	assert_gt(lowest, FlushBowl.LEVER_DOWN * 0.5, "the lever is pulled in the replay")
	replay.stop()


func test_the_duck_is_put_back_after_the_replay() -> void:
	var recorder: ReplayRecorder = await _record_race()
	var before: PackedFloat32Array = _duck.replay_state()
	var replay: FinishReplay = _start_replay(recorder)
	replay._frame = 0
	replay._clock = recorder.frame_time(0)
	replay._apply()
	replay.stop()
	assert_eq(_duck.replay_state(), before, "same state as when the race ended")
