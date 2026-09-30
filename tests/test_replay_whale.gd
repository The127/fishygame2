extends GutTest
## The finish replay on Inside the Whale: a real race with the burp jet going and the stomach
## lobes pulsing is recorded, then played back and compared with what was recorded.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0
## Race second the clip is built around: the burp jet is going about it.
const ANCHOR: float = 5.0

var _track: Track
var _race: Race
var _burps: CurrentHazard


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Runs a race on the whale with the burp jet telegraphing around the anchor, lets the winner
## cross and returns the recorder.
func _record_race() -> ReplayRecorder:
	_track = TrackCatalog.instantiate("whale")
	add_child_autofree(_track)
	_race = Race.new()
	_race.marble_scene = load(MARBLE_SCENE) as PackedScene
	add_child_autofree(_race)
	_race.start(_track, 6, _rng(11), 5)
	_burps = _track.get_hazards()[0] as CurrentHazard
	assert_true(_burps.is_armed())
	_burps.clock = _burps.get_schedule()[0] - (ANCHOR - 2.0)
	while _race.elapsed < ANCHOR:
		await get_tree().physics_frame
	# A fish in the acid, so a skeleton is in the clip.
	var victim: Marble = _race.get_marbles()[1]
	var pit: AcidPit = _track.find_child("AcidA") as AcidPit
	PhysicsServer2D.body_set_state(
		victim.get_rid(),
		PhysicsServer2D.BODY_STATE_TRANSFORM,
		Transform2D(0.0, pit.global_position)
	)
	# A finished fish in the blowhole, so the plume is up in the clip.
	var winner: Marble = _race.get_marbles()[0]
	var hole: Blowhole = _track.find_child("Blowhole") as Blowhole
	var spot: Vector2 = hole.global_position + Vector2(0.0, -40.0)
	PhysicsServer2D.body_set_state(
		winner.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, spot)
	)
	PhysicsServer2D.body_set_state(
		winner.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO
	)
	_track.marble_reached_finish.emit(winner)
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


func test_the_whale_replay_matches_the_recording_at_every_frame() -> void:
	var recorder: ReplayRecorder = await _record_race()
	var replay: FinishReplay = FinishReplay.new()
	add_child_autofree(replay)
	assert_true(replay.start(recorder, _race.get_marbles()))
	var nodes: Array[Node] = recorder.nodes()
	for lobe: Node in _track.find_children("Pulser*", "PulsingBumper", false, false):
		assert_true(nodes.has(lobe), "%s is recorded" % lobe.name)
	assert_true(nodes.has(_track.find_child("Blowhole")), "the blowhole is recorded")
	assert_true(nodes.has(_burps), "the burp jet is recorded")
	assert_true(nodes.has(_track.find_child("Mouth")), "the mouth is recorded")
	assert_true(nodes.has(_track.find_child("Gulps")), "the gulp is recorded")
	assert_true(nodes.has(_track.find_child("StomachWaveA")), "the rippling floor is recorded")
	assert_true(nodes.has(_track.find_child("AcidA")), "the acid pit is recorded")
	assert_true(nodes.has(_track.find_child("AcidB")), "the second acid pit is recorded")
	var bad: Array[String] = []
	var swells: Array[float] = []
	var plume: float = 0.0
	var blowhole: Blowhole = _track.find_child("Blowhole") as Blowhole
	var skeletons: int = 0
	var lobe_a: PulsingBumper = _track.find_child("Pulser1") as PulsingBumper
	for k: int in recorder.frame_count():
		replay._clock = recorder.frame_time(k)
		replay._apply()
		for n: int in nodes.size():
			var state: PackedFloat32Array = nodes[n].call(Replayable.STATE_METHOD)
			if not _matches(state, recorder.node_state_at(k, n)):
				bad.append("%s@%d" % [nodes[n].name, k])
		swells.append(lobe_a.scale.x)
		plume = maxf(plume, blowhole.replay_state()[0])
		skeletons = maxi(skeletons, (_track.find_child("AcidA") as AcidPit).skeleton_count())
	assert_eq(bad, [] as Array[String], "every node shows what was recorded")
	assert_gt(swells.max() - swells.min(), 0.1, "the lobe pulses during the replay")
	assert_gt(plume, 0.5, "the blowhole spouts during the replay")
	assert_eq(skeletons, 1, "the skeleton is shown during the replay")
	replay.stop()
