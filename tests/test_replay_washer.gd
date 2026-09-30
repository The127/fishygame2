extends GutTest
## The finish replay on the Washing Machine: the drum turns in the clip exactly as recorded and
## comes back to where the race left it.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0
## Race second the clip is built around.
const ANCHOR: float = 6.0

var _track: Track
var _race: Race
var _drum: WashDrum


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _record_race() -> ReplayRecorder:
	_track = TrackCatalog.instantiate("washer")
	add_child_autofree(_track)
	_drum = _track.find_child("Drum", true, false) as WashDrum
	_race = Race.new()
	_race.marble_scene = load(MARBLE_SCENE) as PackedScene
	add_child_autofree(_race)
	_race.start(_track, 6, _rng(11), 3)
	while _race.elapsed < ANCHOR:
		await get_tree().physics_frame
	_track.marble_reached_finish.emit(_race.get_marbles()[0])
	await wait_physics_frames(int((ReplayRecorder.TAIL_SECONDS + 0.2) / STEP))
	var recorder: ReplayRecorder = _race.get_recorder()
	assert_true(recorder.is_done())
	_race._finish_race()
	return recorder


func _matches(a: PackedFloat32Array, b: PackedFloat32Array) -> bool:
	if a.size() != b.size():
		return false
	for i: int in a.size():
		if absf(a[i] - b[i]) > 0.01:
			return false
	return true


func test_the_drum_replays_the_way_it_was_recorded() -> void:
	var recorder: ReplayRecorder = await _record_race()
	var replay: FinishReplay = FinishReplay.new()
	add_child_autofree(replay)
	assert_true(replay.start(recorder, _race.get_marbles()))
	var nodes: Array[Node] = recorder.nodes()
	assert_true(nodes.has(_drum), "the drum is recorded")
	var bad: Array[String] = []
	var angles: Array[float] = []
	for k: int in recorder.frame_count():
		replay._clock = recorder.frame_time(k)
		replay._apply()
		for n: int in nodes.size():
			var state: PackedFloat32Array = nodes[n].call(Replayable.STATE_METHOD)
			if not _matches(state, recorder.node_state_at(k, n)):
				bad.append("%s@%d" % [nodes[n].name, k])
		angles.append(_drum.angle)
	assert_eq(bad, [] as Array[String], "every node shows what was recorded")
	assert_ne(angles[0], angles[-1], "the drum moves during the clip")
	replay.stop()


func test_the_drum_comes_back_where_the_race_left_it() -> void:
	var recorder: ReplayRecorder = await _record_race()
	var left: float = _drum.angle
	var replay: FinishReplay = FinishReplay.new()
	add_child_autofree(replay)
	assert_true(replay.start(recorder, _race.get_marbles()))
	replay._clock = recorder.frame_time(0)
	replay._apply()
	assert_ne(_drum.angle, left, "the clip starts with the drum elsewhere")
	replay.stop()
	assert_almost_eq(_drum.angle, left, 0.001)
