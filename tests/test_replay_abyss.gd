extends GutTest
## The finish replay on the Abyss map: a real race with the anglerfish and the rift armed is
## recorded, then played back and compared with what was recorded.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0

var _track: Track
var _race: Race
var _anglers: AnglerHazard
var _rift: RiftHazard
var _spat: bool = false


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Runs a race on the Abyss until a fish was eaten and spat out and a fish went through a
## rift portal, then lets the winner cross and the recorder fill up. Returns the recorder.
func _record_race() -> ReplayRecorder:
	_spat = false
	_track = TrackCatalog.instantiate("abyss")
	add_child_autofree(_track)
	_race = Race.new()
	_race.marble_scene = load(MARBLE_SCENE) as PackedScene
	add_child_autofree(_race)
	_race.start(_track, 5, _rng(7), 5)
	for hazard: Hazard in _track.get_hazards():
		assert_true(hazard.is_armed())
		hazard.clock = hazard.get_schedule()[0] - 0.05
		if hazard is AnglerHazard:
			_anglers = hazard as AnglerHazard
		elif hazard is RiftHazard:
			_rift = hazard as RiftHazard
	_anglers.fish_spat.connect(func(_m: Marble) -> void: _spat = true)
	var marbles: Array[Marble] = _race.get_marbles()
	for marble: Marble in marbles:
		marble.gravity_scale = 0.0
	# Bait in front of each anglerfish's mouth.
	for lair: int in _anglers.get_lair_count():
		var lure: AnglerLure = _anglers.get_child(lair) as AnglerLure
		marbles[1 + lair].global_position = lure.to_global(lure.mouth_position()) + Vector2(0, 10)
	var sent: bool = false
	var frames: int = 0
	while not _spat and frames < 900:
		await get_tree().physics_frame
		frames += 1
		var pair: PortalPair = _rift.get_active_pair()
		if not sent and pair != null and _rift.phase == Hazard.Phase.ACTIVE:
			sent = true
			marbles[3].global_position = pair.to_global(pair.entry_point)
	assert_true(_spat, "a fish was eaten and spat out")
	assert_true(sent, "a fish went into the unstable portal")
	await wait_physics_frames(15)
	_track.marble_reached_finish.emit(marbles[0])
	await wait_physics_frames(int((ReplayRecorder.TAIL_SECONDS + 0.2) / STEP))
	var recorder: ReplayRecorder = _race.get_recorder()
	assert_true(recorder.is_done())
	return recorder


func _float_arrays_match(a: PackedFloat32Array, b: PackedFloat32Array) -> bool:
	if a.size() != b.size():
		return false
	for i: int in a.size():
		if absf(a[i] - b[i]) > 0.01:
			return false
	return true


func test_abyss_replay_matches_the_recording_at_every_frame() -> void:
	var recorder: ReplayRecorder = await _record_race()
	var marbles: Array[Marble] = _race.get_marbles()
	var replay: FinishReplay = FinishReplay.new()
	add_child_autofree(replay)
	assert_true(replay.start(recorder, marbles))
	var nodes: Array[Node] = recorder.nodes()
	assert_true(nodes.has(_anglers), "the anglers are recorded")
	assert_true(nodes.has(_rift), "the rift is recorded")
	var hidden: int = 0
	var diverted: int = 0
	var lures_moved: int = 0
	var bad_states: Array[String] = []
	var bad_looks: int = 0
	for k: int in recorder.frame_count():
		replay._clock = recorder.frame_time(k)
		replay._apply()
		for n: int in nodes.size():
			var state: PackedFloat32Array = nodes[n].call(Replayable.STATE_METHOD)
			if not _float_arrays_match(state, recorder.node_state_at(k, n)):
				bad_states.append("%s@%d" % [nodes[n].name, k])
		for marble: Marble in marbles:
			var alpha: float = recorder.alpha_at(k, marble.id)
			if marble.visible != (alpha > 0.01):
				bad_looks += 1
			if not marble.visible:
				hidden += 1
		for node: Node in nodes:
			if node is PortalPair and (node as PortalPair).diverted:
				diverted += 1
		if _anglers.get_child(0).position != Vector2.ZERO and _anglers.get_active_lair() >= 0:
			lures_moved += 1
	assert_eq(bad_states, [] as Array[String], "every node shows what was recorded")
	assert_eq(bad_looks, 0, "fish visibility follows the recording")
	assert_gt(hidden, 0, "the swallowed fish is hidden for a while in the replay")
	assert_gt(diverted, 0, "the portal is diverted in the replay")
	assert_gt(lures_moved, 0, "an angler is out hunting in the replay")
	replay.stop()
	for marble: Marble in marbles:
		assert_true(marble.visible or marble.eaten, "%d is shown again after" % marble.id)


func test_bites_spits_and_portal_sparks_are_replayed() -> void:
	var recorder: ReplayRecorder = await _record_race()
	var expected: int = 0
	for event: Dictionary in recorder.events():
		if (
			int(event["kind"]) == ReplayRecorder.Kind.BURST
			and float(event["time"]) <= recorder.end_time()
		):
			expected += 1
	# A bite, a swallow, a spit and the two sparks of the portal at the least.
	assert_gte(expected, 5, "the race recorded its particle bursts")
	var replay: FinishReplay = FinishReplay.new()
	add_child_autofree(replay)
	assert_true(replay.start(recorder, _race.get_marbles()))
	for k: int in recorder.frame_count():
		replay._clock = recorder.frame_time(k)
		replay._apply()
	var played: int = replay.find_children("*", "CPUParticles2D", false, false).size()
	# Marble splashes and the like also add particles, so count at least the recorded bursts.
	assert_gte(played, expected, "the replay lets off the same bursts")
	replay.stop()
