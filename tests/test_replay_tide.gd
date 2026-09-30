extends GutTest
## The finish replay on Ebb Tide: a real race with the water draining and a fish stranded is
## recorded, then played back and compared with what was recorded.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0
## Race second the clip is built around.
const ANCHOR: float = 5.0

var _track: Track
var _race: Race
var _water: WaterLevel
var _stranded: Marble
## Where the waterline stood when the race ended.
var _held_level: float = 0.0


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Runs a race on Ebb Tide with the tide already partway down, strands one fish in the lead of
## the clip and lets the winner cross. Returns the recorder.
func _record_race() -> ReplayRecorder:
	_track = TrackCatalog.instantiate("tide")
	add_child_autofree(_track)
	_water = _track.get_node("WaterLevel") as WaterLevel
	_race = Race.new()
	_race.marble_scene = load(MARBLE_SCENE) as PackedScene
	add_child_autofree(_race)
	_race.start(_track, 6, _rng(11), 5)
	assert_true(_water.draining)
	# Far enough into the drain that the waterline moves through the whole clip.
	_water.clock = _water.start_delay + 8.0
	_stranded = _race.get_marbles()[1]
	var stranded_now: bool = false
	while _race.elapsed < ANCHOR:
		await get_tree().physics_frame
		if not stranded_now and _race.elapsed >= ANCHOR - 1.8:
			stranded_now = true
			_stranded.strand()
	_track.marble_reached_finish.emit(_race.get_marbles()[0])
	await wait_physics_frames(int((ReplayRecorder.TAIL_SECONDS + 0.2) / STEP))
	var recorder: ReplayRecorder = _race.get_recorder()
	assert_true(recorder.is_done())
	# The race ends: the tide stops where it is, as it does before the replay plays.
	_race._finish_race()
	_held_level = _water.level
	return recorder


func _matches(a: PackedFloat32Array, b: PackedFloat32Array) -> bool:
	if a.size() != b.size():
		return false
	for i: int in a.size():
		if absf(a[i] - b[i]) > 0.01:
			return false
	return true


func test_the_tide_replay_matches_the_recording_at_every_frame() -> void:
	var recorder: ReplayRecorder = await _record_race()
	var replay: FinishReplay = FinishReplay.new()
	add_child_autofree(replay)
	assert_true(replay.start(recorder, _race.get_marbles()))
	var nodes: Array[Node] = recorder.nodes()
	assert_true(nodes.has(_water), "the waterline is recorded")
	assert_true(nodes.has(_track.get_hazards()[0]), "the rip current is recorded")
	var bad: Array[String] = []
	var levels: Array[float] = []
	for k: int in recorder.frame_count():
		replay._clock = recorder.frame_time(k)
		replay._apply()
		for n: int in nodes.size():
			var state: PackedFloat32Array = nodes[n].call(Replayable.STATE_METHOD)
			if not _matches(state, recorder.node_state_at(k, n)):
				bad.append("%s@%d" % [nodes[n].name, k])
		levels.append(_water.level)
		assert_almost_eq(_water.position.y, _water.level, 0.001, "the drawn water follows")
	assert_eq(bad, [] as Array[String], "every node shows what was recorded")
	assert_gt(levels[-1], levels[0], "the water drains during the clip")
	replay.stop()


func test_the_waterline_comes_back_where_the_race_left_it() -> void:
	var recorder: ReplayRecorder = await _record_race()
	var replay: FinishReplay = FinishReplay.new()
	add_child_autofree(replay)
	assert_true(replay.start(recorder, _race.get_marbles()))
	replay._clock = recorder.frame_time(0)
	replay._apply()
	assert_ne(_water.level, _held_level, "the clip starts with the water higher")
	replay.stop()
	assert_almost_eq(_water.level, _held_level, 0.001)
	assert_false(_water.draining)


func test_a_stranded_fish_flops_and_fades_in_the_replay() -> void:
	var recorder: ReplayRecorder = await _record_race()
	var replay: FinishReplay = FinishReplay.new()
	add_child_autofree(replay)
	assert_true(replay.start(recorder, _race.get_marbles()))
	var id: int = _stranded.id
	var saw_full: bool = false
	var saw_fading: bool = false
	var low: float = INF
	var high: float = -INF
	for k: int in recorder.frame_count():
		replay._clock = recorder.frame_time(k)
		replay._apply()
		var alpha: float = recorder.alpha_at(k, id)
		assert_almost_eq(_stranded.modulate.a, alpha, 0.001)
		assert_eq(_stranded.visible, alpha > 0.01)
		if alpha >= 0.99:
			saw_full = true
		elif alpha > 0.01:
			saw_fading = true
		if alpha > 0.01 and k > 0 and recorder.velocity_at(k, id).length() < 0.01:
			low = minf(low, _stranded.global_position.y)
			high = maxf(high, _stranded.global_position.y)
	assert_true(saw_full, "the fish is seen before it strands")
	assert_true(saw_fading, "the fish fades in the clip")
	assert_gt(high - low, 2.0, "the fish hops while it flops")
	replay.stop()
