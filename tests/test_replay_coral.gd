extends GutTest
## The finish replay on the Coral Maze map: a real race with the tide armed is recorded, then
## played back and compared with what was recorded.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0
## Race second the clip is built around: the tide is throwing the gates about it.
const ANCHOR: float = 5.0

var _track: Track
var _race: Race
var _tide: TideHazard
var _gates: Array[FlipGate] = []


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Runs a race on the Coral in which the tide telegraphs and throws the gates, and one gate is
## flipped by hand, around the winner's crossing. Returns the recorder.
func _record_race() -> ReplayRecorder:
	_gates.clear()
	_track = TrackCatalog.instantiate("coral")
	add_child_autofree(_track)
	_race = Race.new()
	_race.marble_scene = load(MARBLE_SCENE) as PackedScene
	add_child_autofree(_race)
	_race.start(_track, 6, _rng(11), 5)
	_tide = _track.get_hazards()[0] as TideHazard
	assert_not_null(_tide)
	assert_true(_tide.is_armed())
	for child: Node in _tide.get_children():
		if child is FlipGate:
			_gates.append(child as FlipGate)
	assert_eq(_gates.size(), 6)
	# The telegraph begins two seconds before the anchor, the throws half a second after it.
	_tide.clock = _tide.get_schedule()[0] - (ANCHOR - 2.0)
	var flipped_by_hand: bool = false
	while _race.elapsed < ANCHOR:
		await get_tree().physics_frame
		if not flipped_by_hand and _race.elapsed >= ANCHOR - 1.5:
			flipped_by_hand = true
			_gates[0].flip()
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


func _show(replay: FinishReplay, recorder: ReplayRecorder, k: int, weight: float) -> void:
	var t0: float = recorder.frame_time(k)
	replay._frame = k
	replay._clock = t0 + (recorder.frame_time(k + 1) - t0) * weight
	replay._apply()


func _paddle(gate: FlipGate) -> AnimatableBody2D:
	return gate.get_node("Paddle") as AnimatableBody2D


func test_coral_replay_matches_the_recording_at_every_frame() -> void:
	var recorder: ReplayRecorder = await _record_race()
	var replay: FinishReplay = FinishReplay.new()
	add_child_autofree(replay)
	assert_true(replay.start(recorder, _race.get_marbles()))
	var nodes: Array[Node] = recorder.nodes()
	for gate: FlipGate in _gates:
		assert_true(nodes.has(gate), "%s is recorded" % gate.name)
		assert_false(_paddle(gate).sync_to_physics, "%s paddle follows the replay" % gate.name)
	assert_true(nodes.has(_tide), "the tide is recorded")
	var bad: Array[String] = []
	var flips: int = 0
	var swinging: int = 0
	var alarmed: int = 0
	var last_states: Array[int] = []
	for gate: FlipGate in _gates:
		last_states.append(gate.state)
	for k: int in recorder.frame_count():
		replay._clock = recorder.frame_time(k)
		replay._apply()
		for n: int in nodes.size():
			var state: PackedFloat32Array = nodes[n].call(Replayable.STATE_METHOD)
			if not _matches(state, recorder.node_state_at(k, n)):
				bad.append("%s@%d" % [nodes[n].name, k])
		for i: int in _gates.size():
			var gate: FlipGate = _gates[i]
			if gate.state != last_states[i]:
				flips += 1
			last_states[i] = gate.state
			if absf(_paddle(gate).rotation - gate.target_angle()) > 0.02:
				swinging += 1
			if float(gate.replay_state()[1]) > 0.05:
				alarmed += 1
	assert_eq(bad, [] as Array[String], "every node shows what was recorded")
	assert_gt(flips, 0, "gates flip during the replay")
	assert_gt(swinging, 0, "a paddle is seen mid swing in the replay")
	assert_gt(alarmed, 0, "the arrows warn during the telegraph in the replay")
	replay.stop()
	for gate: FlipGate in _gates:
		assert_true(_paddle(gate).sync_to_physics, "%s paddle syncs to physics again" % gate.name)


func test_a_flip_shows_at_the_recorded_moment() -> void:
	var recorder: ReplayRecorder = await _record_race()
	var replay: FinishReplay = FinishReplay.new()
	add_child_autofree(replay)
	assert_true(replay.start(recorder, _race.get_marbles()))
	var nodes: Array[Node] = recorder.nodes()
	var checked: int = 0
	for k: int in recorder.frame_count() - 1:
		for n: int in nodes.size():
			if not nodes[n] is FlipGate:
				continue
			var gate: FlipGate = nodes[n] as FlipGate
			var from: PackedFloat32Array = recorder.node_state_at(k, n)
			var to: PackedFloat32Array = recorder.node_state_at(k + 1, n)
			if from[0] == to[0]:
				continue
			checked += 1
			_show(replay, recorder, k, 0.25)
			assert_eq(float(gate.state), from[0], "%s still points the old way" % gate.name)
			_show(replay, recorder, k, 0.75)
			assert_eq(float(gate.state), to[0], "%s points the new way" % gate.name)
	assert_gt(checked, 0, "the clip holds a flip")
	replay.stop()
