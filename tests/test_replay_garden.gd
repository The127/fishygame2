extends GutTest
## The finish replay on the Coral Garden map: a real race in which the coral wakes and grows is
## recorded, then played back and compared with what was recorded.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0
## Race second the clip is built around: the first beds are growing shut about it.
const ANCHOR: float = 8.0

var _track: Track
var _race: Race
var _coral: CoralHazard


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Runs a race on the garden up to the anchor and lets the winner cross. Returns the recorder.
func _record_race() -> ReplayRecorder:
	_track = TrackCatalog.instantiate("garden")
	add_child_autofree(_track)
	_race = Race.new()
	_race.marble_scene = load(MARBLE_SCENE) as PackedScene
	add_child_autofree(_race)
	_race.start(_track, 6, _rng(11), 5)
	_coral = _track.get_hazards()[0] as CoralHazard
	assert_not_null(_coral)
	while _race.elapsed < ANCHOR:
		await get_tree().physics_frame
	_track.marble_reached_finish.emit(_race.get_marbles()[0])
	await wait_physics_frames(int((ReplayRecorder.TAIL_SECONDS + 0.2) / STEP))
	var recorder: ReplayRecorder = _race.get_recorder()
	assert_true(recorder.is_done())
	return recorder


func _matches(a: PackedFloat32Array, b: PackedFloat32Array) -> bool:
	if a.size() != b.size():
		return false
	for i: int in a.size():
		if absf(a[i] - b[i]) > 0.01:
			return false
	return true


func test_garden_replay_matches_the_recording_at_every_frame() -> void:
	var recorder: ReplayRecorder = await _record_race()
	var replay: FinishReplay = FinishReplay.new()
	add_child_autofree(replay)
	assert_true(replay.start(recorder, _race.get_marbles()))
	var nodes: Array[Node] = recorder.nodes()
	assert_true(nodes.has(_coral), "the coral is recorded")
	var bad: Array[String] = []
	var growing_seen: int = 0
	var beds: Array[CoralBed] = _coral.get_beds()
	var plug_moved: bool = false
	for k: int in recorder.frame_count():
		replay._clock = recorder.frame_time(k)
		replay._apply()
		for n: int in nodes.size():
			var state: PackedFloat32Array = nodes[n].call(Replayable.STATE_METHOD)
			if not _matches(state, recorder.node_state_at(k, n)):
				bad.append("%s@%d" % [nodes[n].name, k])
		for bed: CoralBed in beds:
			if bed.growth > 0.05 and bed.growth < 0.95:
				growing_seen += 1
			var plug: Node2D = bed.get_node("Plug") as Node2D
			plug_moved = plug_moved or plug.position.length() > 20.0
	assert_eq(bad, [] as Array[String], "every node shows what was recorded")
	assert_gt(growing_seen, 0, "coral is seen mid growth in the replay")
	assert_true(plug_moved, "a plug is seen out in the opening in the replay")
	replay.stop()
