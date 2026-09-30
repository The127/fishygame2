extends GutTest
## Map hazards and moving obstacles play back in sync with the fish during the finish replay.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _track(id: String) -> Track:
	var track: Track = TrackCatalog.instantiate(id)
	add_child_autofree(track)
	track.seed_gimmicks(_rng(5))
	track.arm_hazards(_rng(6), 5)
	return track


func _marble() -> Marble:
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	marble.id = 0
	add_child_autofree(marble)
	return marble


## Lets the track run `seconds` of physics frames.
func _run(seconds: float) -> void:
	for i: int in int(seconds / STEP):
		await get_tree().physics_frame


func test_every_map_state_has_a_fixed_size_and_applies_cleanly() -> void:
	for id: String in TrackCatalog.ids():
		var track: Track = _track(id)
		var nodes: Array[Node] = Replayable.find_in(track)
		var sizes: Array[int] = []
		for node: Node in nodes:
			sizes.append((node.call(Replayable.STATE_METHOD) as PackedFloat32Array).size())
		await _run(3.0)
		for n: int in nodes.size():
			var state: PackedFloat32Array = nodes[n].call(Replayable.STATE_METHOD)
			assert_eq(state.size(), sizes[n], "%s: %s keeps its state size" % [id, nodes[n].name])
			nodes[n].call(Replayable.APPLY_METHOD, state, state, 0.0)
			assert_eq(
				nodes[n].call(Replayable.STATE_METHOD),
				state,
				"%s: %s applies what it captured" % [id, nodes[n].name]
			)


func test_maps_with_moving_parts_register_them() -> void:
	var expected: Dictionary = {
		"jelly": JellyHazard,
		"vents": Geyser,
		"whirlpool": Whirlpool,
		"abyss": AnglerHazard,
		"wreck": PlankHazard,
		"coral": FlipGate,
	}
	for id: String in expected:
		if not TrackCatalog.has_map(id):
			continue
		var found: bool = false
		for node: Node in Replayable.find_in(_track(id)):
			found = found or is_instance_of(node, expected[id])
		assert_true(found, "%s has a replayable %s" % [id, expected[id]])


func test_jellyfish_replay_where_they_were_during_the_race() -> void:
	var track: Track = _track("jelly")
	var hazard: JellyHazard = track.get_hazards()[0] as JellyHazard
	var jelly: Jellyfish = hazard.get_jellies()[0]
	var recorder: ReplayRecorder = ReplayRecorder.new(1)
	recorder.bind_nodes(Replayable.find_in(track))
	var marble: Marble = _marble()
	var seen: Dictionary = {}
	var time: float = 0.0
	while time < 3.0:
		await get_tree().physics_frame
		time += STEP
		if recorder.should_sample(time):
			recorder.sample(
				time, PackedVector2Array([Vector2.ZERO]), PackedVector2Array([Vector2.ZERO])
			)
			seen[snappedf(time, 0.001)] = jelly.position
	recorder.mark_finish(time, 0)
	recorder.sample(time, PackedVector2Array([Vector2.ZERO]), PackedVector2Array([Vector2.ZERO]))
	# The race is over and the jellyfish wander off to somewhere else.
	await _run(2.0)
	var drifted: Vector2 = jelly.position
	var replay: FinishReplay = FinishReplay.new()
	add_child_autofree(replay)
	assert_true(replay.start(recorder, [marble] as Array[Marble]))
	var index: int = 0
	for k: int in recorder.frame_count():
		if recorder.frame_time(k) >= replay.clock() + 0.5:
			index = k
			break
	replay._clock = recorder.frame_time(index)
	replay._apply()
	assert_true(recorder.frame_time(index) > 0.0)
	var recorded: Vector2 = seen[snappedf(recorder.frame_time(index), 0.001)]
	assert_almost_eq(jelly.position.x, recorded.x, 0.5)
	assert_almost_eq(jelly.position.y, recorded.y, 0.5)
	replay.stop()
	assert_almost_eq(jelly.position.x, drifted.x, 0.5, "put back after the replay")
	assert_almost_eq(jelly.position.y, drifted.y, 0.5)


func test_live_nodes_stop_while_the_replay_plays_and_run_again_after() -> void:
	var track: Track = _track("jelly")
	var hazard: JellyHazard = track.get_hazards()[0] as JellyHazard
	var recorder: ReplayRecorder = ReplayRecorder.new(1)
	recorder.bind_nodes(Replayable.find_in(track))
	var zero: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
	for i: int in 4:
		recorder.sample(float(i) * 0.1, zero, zero)
	recorder.mark_finish(0.3, 0)
	var replay: FinishReplay = FinishReplay.new()
	add_child_autofree(replay)
	replay.start(recorder, [_marble()] as Array[Marble])
	assert_false(hazard.is_physics_processing())
	replay.stop()
	assert_true(hazard.is_physics_processing())


func test_hidden_fish_are_hidden_in_the_replay() -> void:
	var recorder: ReplayRecorder = ReplayRecorder.new(1)
	var zero: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
	recorder.sample(0.0, zero, zero, PackedFloat32Array([1.0]))
	recorder.sample(0.1, zero, zero, PackedFloat32Array([0.0]))
	recorder.sample(0.2, zero, zero, PackedFloat32Array([0.0]))
	recorder.mark_finish(0.2, 0)
	var marble: Marble = _marble()
	var replay: FinishReplay = FinishReplay.new()
	add_child_autofree(replay)
	replay.start(recorder, [marble] as Array[Marble])
	assert_true(marble.visible)
	replay._clock = 0.15
	replay._frame = 1
	replay._apply()
	assert_false(marble.visible)
	replay.stop()
	assert_true(marble.visible, "visible again after the replay")


func test_the_buffer_stays_small_on_the_busiest_map() -> void:
	var biggest: int = 0
	for id: String in TrackCatalog.ids():
		var recorder: ReplayRecorder = ReplayRecorder.new(30)
		recorder.bind_nodes(Replayable.find_in(_track(id)))
		biggest = maxi(biggest, recorder.memory_bytes())
	assert_true(biggest < 200 * 1024, "replay buffer is %d bytes" % biggest)


func test_gravity_map_replays_flips_warnings_and_currents_across_events() -> void:
	var track: Track = _track("gravity")
	var flipper: GravityFlipper = track.get_node("Flipper") as GravityFlipper
	var nodes: Array[Node] = Replayable.find_in(track)
	assert_true(nodes.has(flipper), "the flipper is replayable")
	assert_true(nodes.has(track.get_hazards()[0]), "the cross current is replayable")
	var recorder: ReplayRecorder = ReplayRecorder.new(1)
	recorder.bind_nodes(nodes)
	var zero: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
	var seen: Dictionary = {}
	var flips: int = 0
	var warned: bool = false
	var phases: Dictionary = {}
	var time: float = 0.0
	while time < 9.0:
		await get_tree().physics_frame
		time += STEP
		flips = maxi(flips, int(flipper.clock >= flipper.get_schedule()[0]))
		warned = warned or flipper.warning() > 0.0
		phases[(track.get_hazards()[0] as Hazard).phase] = true
		if recorder.should_sample(time):
			recorder.sample(time, zero, zero)
			var states: Array[PackedFloat32Array] = []
			for node: Node in nodes:
				states.append(node.call(Replayable.STATE_METHOD))
			seen[snappedf(time, 0.001)] = states
	recorder.mark_finish(time, 0)
	recorder.sample(time, zero, zero)
	assert_eq(flips, 1, "a flip happened in the clip")
	assert_true(warned, "a warning happened in the clip")
	assert_gt(phases.size(), 1, "the current ran through its phases")
	# The race goes on and everything moves to somewhere else.
	await _run(2.0)
	var ended_up: PackedFloat32Array = flipper.replay_state()
	var replay: FinishReplay = FinishReplay.new()
	add_child_autofree(replay)
	assert_true(replay.start(recorder, [_marble()] as Array[Marble]))
	for k: int in recorder.frame_count() - 1:
		replay._clock = recorder.frame_time(k)
		replay._frame = k
		replay._apply()
		for n: int in nodes.size():
			assert_eq(
				nodes[n].call(Replayable.STATE_METHOD),
				seen[snappedf(recorder.frame_time(k), 0.001)][n],
				"frame %d: %s matches the recording" % [k, nodes[n].name]
			)
	replay.stop()
	assert_eq(flipper.replay_state(), ended_up, "gravity is put back after the replay")
	assert_eq(
		(flipper.get_node("Zone") as Area2D).gravity_direction.y < 0.0,
		flipper.up,
		"the physics zone matches the restored flip"
	)
