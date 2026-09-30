extends GutTest
## The finish replay on the Fork Reef map (three starts): a real race with the geysers and the
## current armed is recorded, then played back and compared with what was recorded.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0
## Race second the clip is built around: the geysers start erupting just before it.
const ANCHOR: float = 5.0

var _track: Track
var _race: Race
var _current: CurrentHazard


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Runs a race on Fork Reef in which every geyser and the current go through all their phases
## around the winner's crossing. Returns the recorder.
func _record_race() -> ReplayRecorder:
	_track = TrackCatalog.instantiate("fork")
	add_child_autofree(_track)
	_race = Race.new()
	_race.marble_scene = load(MARBLE_SCENE) as PackedScene
	add_child_autofree(_race)
	_race.start(_track, 6, _rng(11), 5)
	assert_gt(_track.get_geysers().size(), 0)
	for geyser: Geyser in _track.get_geysers():
		assert_true(geyser.is_armed())
		# Put the eruption to start a little before the anchor, the clock being at zero.
		var start: float = geyser.get_cycle() - geyser.telegraph_seconds - geyser.erupt_seconds
		geyser.set("_offset", fposmod(start - (ANCHOR - 0.9), geyser.get_cycle()))
	for hazard: Hazard in _track.get_hazards():
		assert_true(hazard.is_armed())
		if hazard is CurrentHazard:
			_current = hazard as CurrentHazard
			# The event's telegraph begins about two seconds before the anchor.
			_current.clock = _current.get_schedule()[0] - (ANCHOR - 2.0)
	assert_not_null(_current)
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


func _show(replay: FinishReplay, recorder: ReplayRecorder, k: int, weight: float) -> void:
	var t0: float = recorder.frame_time(k)
	replay._frame = k
	replay._clock = t0 + (recorder.frame_time(k + 1) - t0) * weight
	replay._apply()


func test_fork_replay_matches_the_recording_at_every_frame() -> void:
	var recorder: ReplayRecorder = await _record_race()
	var replay: FinishReplay = FinishReplay.new()
	add_child_autofree(replay)
	assert_true(replay.start(recorder, _race.get_marbles()))
	var nodes: Array[Node] = recorder.nodes()
	var geysers: Array[Geyser] = _track.get_geysers()
	for geyser: Geyser in geysers:
		assert_true(nodes.has(geyser), "%s is recorded" % geyser.name)
	assert_true(nodes.has(_current), "the current is recorded")
	var moving: int = 0
	for node: Node in nodes:
		if node is TrapDoor or node is FlipGate:
			moving += 1
	assert_eq(moving, 3, "the two trapdoors and the switch are recorded")
	var bad: Array[String] = []
	var geyser_phases: Dictionary = {}
	var current_phases: Dictionary = {}
	var pushed: int = 0
	for k: int in recorder.frame_count():
		replay._clock = recorder.frame_time(k)
		replay._apply()
		for n: int in nodes.size():
			var state: PackedFloat32Array = nodes[n].call(Replayable.STATE_METHOD)
			if not _matches(state, recorder.node_state_at(k, n)):
				bad.append("%s@%d" % [nodes[n].name, k])
		for geyser: Geyser in geysers:
			geyser_phases[geyser.phase_at(geyser.clock)] = true
		current_phases[_current.phase] = true
		if _current.phase == Hazard.Phase.ACTIVE and _current.get_direction() != Vector2.ZERO:
			pushed += 1
	assert_eq(bad, [] as Array[String], "every node shows what was recorded")
	for phase: Geyser.Phase in Geyser.Phase.values():
		assert_true(geyser_phases.has(phase), "a geyser is in phase %d in the replay" % phase)
	for phase: Hazard.Phase in Hazard.Phase.values():
		assert_true(current_phases.has(phase), "the current is in phase %d in the replay" % phase)
	assert_gt(pushed, 0, "the current flows in the replay")
	replay.stop()


func test_phase_changes_happen_where_they_were_recorded() -> void:
	var recorder: ReplayRecorder = await _record_race()
	var replay: FinishReplay = FinishReplay.new()
	add_child_autofree(replay)
	assert_true(replay.start(recorder, _race.get_marbles()))
	var nodes: Array[Node] = recorder.nodes()
	var checked: int = 0
	for k: int in recorder.frame_count() - 1:
		for n: int in nodes.size():
			if not nodes[n] is Hazard:
				continue
			var hazard: Hazard = nodes[n] as Hazard
			var from: PackedFloat32Array = recorder.node_state_at(k, n)
			var to: PackedFloat32Array = recorder.node_state_at(k + 1, n)
			if from[1] == to[1]:
				continue
			checked += 1
			_show(replay, recorder, k, 0.25)
			assert_eq(int(hazard.phase), int(from[1]), "%s is still in its old phase" % hazard.name)
			_show(replay, recorder, k, 0.75)
			assert_eq(int(hazard.phase), int(to[1]), "%s is in its new phase" % hazard.name)
	assert_gt(checked, 0, "the clip holds a phase change of the current")
	replay.stop()


func test_fish_from_every_start_replay_where_they_were_recorded() -> void:
	var recorder: ReplayRecorder = await _record_race()
	var starts: Dictionary = {}
	for i: int in _race.get_marbles().size():
		starts[_track.get_start_of(i)] = true
	assert_eq(starts.size(), _track.get_start_count(), "fish began at every start")
	var replay: FinishReplay = FinishReplay.new()
	add_child_autofree(replay)
	assert_true(replay.start(recorder, _race.get_marbles()))
	var bad: Array[String] = []
	for k: int in recorder.frame_count():
		replay._clock = recorder.frame_time(k)
		replay._apply()
		for marble: Marble in _race.get_marbles():
			var want: Vector2 = recorder.position_at(k, marble.id)
			if marble.global_position.distance_to(want) > 0.5:
				bad.append("%d@%d" % [marble.id, k])
	assert_eq(bad, [] as Array[String], "every fish is where it was recorded")
	replay.stop()
