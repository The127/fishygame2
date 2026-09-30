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


## Runs a race in which the spin cycle telegraphs and whirls the drum around the winner's
## crossing, and returns the recorder.
func _record_spin_cycle() -> ReplayRecorder:
	_track = TrackCatalog.instantiate("washer")
	add_child_autofree(_track)
	_drum = _track.find_child("Drum", true, false) as WashDrum
	_race = Race.new()
	_race.marble_scene = load(MARBLE_SCENE) as PackedScene
	add_child_autofree(_race)
	_race.start(_track, 6, _rng(11), 5)
	var spin_cycle: SpinCycleHazard = _track.get_hazards()[0] as SpinCycleHazard
	assert_not_null(spin_cycle)
	assert_true(spin_cycle.is_armed())
	# The telegraph begins two seconds before the anchor, the whirl right after it.
	spin_cycle.clock = spin_cycle.get_schedule()[0] - (ANCHOR - 2.0)
	while _race.elapsed < ANCHOR + 1.0:
		await get_tree().physics_frame
	_track.marble_reached_finish.emit(_race.get_marbles()[0])
	await wait_physics_frames(int((ReplayRecorder.TAIL_SECONDS + 0.2) / STEP))
	var recorder: ReplayRecorder = _race.get_recorder()
	assert_true(recorder.is_done())
	_race._finish_race()
	return recorder


## Like [method _matches], but a drum turned by whole turns more or less looks the same: the spin
## cycle drops its turns at once when it ends, and the replay blends the angle the short way.
func _same_look(node: Node, a: PackedFloat32Array, b: PackedFloat32Array) -> bool:
	if not node is WashDrum:
		return _matches(a, b)
	return absf(angle_difference(a[0], b[0])) < 0.01 and absf(a[1] - b[1]) < 0.01


func test_the_spin_cycle_replays_with_its_glow_whirl_and_suds() -> void:
	var recorder: ReplayRecorder = await _record_spin_cycle()
	var replay: FinishReplay = FinishReplay.new()
	add_child_autofree(replay)
	assert_true(replay.start(recorder, _race.get_marbles()))
	var nodes: Array[Node] = recorder.nodes()
	assert_true(nodes.has(_track.get_hazards()[0]), "the spin cycle is recorded")
	var bad: Array[String] = []
	var glowed: int = 0
	var whirled: bool = false
	var first_angle: float = 0.0
	for k: int in recorder.frame_count():
		replay._clock = recorder.frame_time(k)
		replay._apply()
		for n: int in nodes.size():
			var state: PackedFloat32Array = nodes[n].call(Replayable.STATE_METHOD)
			if not _same_look(nodes[n], state, recorder.node_state_at(k, n)):
				bad.append("%s@%d" % [nodes[n].name, k])
		if _drum.alarm > 0.05:
			glowed += 1
		if k == 0:
			first_angle = _drum.angle
		if absf(_drum.angle - first_angle) > PI * 2.0:
			whirled = true
	assert_eq(bad, [] as Array[String], "every node shows what was recorded")
	assert_gt(glowed, 0, "the door glows in the telegraph")
	assert_true(whirled, "the drum whirls through whole turns in the clip")
	var bursts: int = 0
	for event: Dictionary in recorder.events():
		if int(event["kind"]) == ReplayRecorder.Kind.BURST:
			bursts += 1
	assert_gt(bursts, 0, "the suds flung by the whirl are part of the clip")
	replay.stop()
