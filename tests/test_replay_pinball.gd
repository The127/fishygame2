extends GutTest
## The finish replay on Pinball Reef: a real race with the flippers firing is recorded, then
## played back and compared with what was recorded.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0
## Race second the clip is built around.
const ANCHOR: float = 6.0

var _track: Track
var _race: Race
var _table: PinballTable


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Runs a race with viewers pressing both sides through the clip, then lets a winner cross.
func _record_race() -> ReplayRecorder:
	_track = TrackCatalog.instantiate("pinball")
	add_child_autofree(_track)
	_table = _track.get_node("PinballTable") as PinballTable
	_race = Race.new()
	_race.marble_scene = load(MARBLE_SCENE) as PackedScene
	add_child_autofree(_race)
	_race.start(_track, 6, _rng(11), 0)
	var next_press: float = 1.0
	while _race.elapsed < ANCHOR:
		await get_tree().physics_frame
		if _race.elapsed >= next_press:
			next_press += 0.9
			_table.fire(-1 if int(next_press * 10.0) % 2 == 0 else 1, "viewer")
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


func test_the_flippers_and_the_table_are_recorded() -> void:
	var recorder: ReplayRecorder = await _record_race()
	var nodes: Array[Node] = recorder.nodes()
	assert_true(nodes.has(_table), "the table is recorded")
	for flipper: PinballFlipper in _table.get_flippers():
		assert_true(nodes.has(flipper), "%s is recorded" % flipper.name)


func test_the_replay_matches_the_recording_at_every_frame() -> void:
	var recorder: ReplayRecorder = await _record_race()
	var replay: FinishReplay = FinishReplay.new()
	add_child_autofree(replay)
	assert_true(replay.start(recorder, _race.get_marbles()))
	var nodes: Array[Node] = recorder.nodes()
	var bad: Array[String] = []
	var angles: Dictionary = {}
	for k: int in recorder.frame_count():
		replay._clock = recorder.frame_time(k)
		replay._apply()
		for n: int in nodes.size():
			var state: PackedFloat32Array = nodes[n].call(Replayable.STATE_METHOD)
			if not _matches(state, recorder.node_state_at(k, n)):
				bad.append("%s@%d" % [nodes[n].name, k])
		for flipper: PinballFlipper in _table.get_flippers():
			angles[flipper.name] = maxf(
				float(angles.get(flipper.name, 0.0)), absf(flipper.rotation - flipper.rest_angle())
			)
	assert_eq(bad, [] as Array[String], "every node shows what was recorded")
	var moved: int = 0
	for angle: float in angles.values():
		if angle > 0.3:
			moved += 1
	assert_gt(moved, 0, "a flipper swings up during the clip")
	replay.stop()


func test_the_flippers_come_back_where_the_race_left_them() -> void:
	var recorder: ReplayRecorder = await _record_race()
	var before: Dictionary = {}
	for flipper: PinballFlipper in _table.get_flippers():
		before[flipper.name] = flipper.rotation
	var replay: FinishReplay = FinishReplay.new()
	add_child_autofree(replay)
	assert_true(replay.start(recorder, _race.get_marbles()))
	replay._clock = recorder.frame_time(0)
	replay._apply()
	replay.stop()
	for flipper: PinballFlipper in _table.get_flippers():
		assert_almost_eq(flipper.rotation, float(before[flipper.name]), 0.001)
