extends GutTest
## The Kraken's Lair tentacles, telegraph and eye play back as they were during the race.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _look(kraken: KrakenHazard) -> Dictionary:
	var eye: KrakenEye = kraken.get_node("Eye") as KrakenEye
	return {
		"active": kraken.get_active_tentacles(),
		"swing": kraken._swing.duplicate(),
		"phase": kraken.phase,
		"alert": eye.get_alert(),
		"look": eye._look,
	}


func test_kraken_and_eye_are_replayable() -> void:
	var track: Track = TrackCatalog.instantiate("kraken")
	add_child_autofree(track)
	var has_hazard: bool = false
	var has_eye: bool = false
	for node: Node in Replayable.find_in(track):
		has_hazard = has_hazard or node is KrakenHazard
		has_eye = has_eye or node is KrakenEye
	assert_true(has_hazard)
	assert_true(has_eye)


func test_armed_race_replays_the_recorded_tentacles_and_eye() -> void:
	var track: Track = TrackCatalog.instantiate("kraken")
	add_child_autofree(track)
	var kraken: KrakenHazard = track.get_hazards()[0] as KrakenHazard
	kraken.telegraph_seconds = 0.4
	kraken.active_seconds = 1.0
	track.arm_hazards(_rng(3), 3)
	kraken.clock = kraken.get_schedule()[0] - 0.2
	var recorder: ReplayRecorder = ReplayRecorder.new(1)
	recorder.bind_nodes(Replayable.find_in(track))
	var zero: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
	var seen: Dictionary = {}
	var time: float = 0.0
	while time < 2.0:
		await get_tree().physics_frame
		await get_tree().process_frame
		time += STEP
		if recorder.should_sample(time):
			recorder.sample(time, zero, zero)
			seen[snappedf(time, 0.001)] = _look(kraken)
	recorder.mark_finish(time, 0)
	recorder.sample(time, zero, zero)
	var swung: bool = false
	for snapshot: Dictionary in seen.values():
		swung = swung or not (snapshot["active"] as Array).is_empty()
	assert_true(swung, "an event was recorded")
	# Afterwards the kraken has gone quiet.
	kraken.disarm()
	await wait_frames(30)
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	add_child_autofree(marble)
	var replay: FinishReplay = FinishReplay.new()
	add_child_autofree(replay)
	assert_true(replay.start(recorder, [marble] as Array[Marble]))
	var compared: int = 0
	for k: int in recorder.frame_count():
		var stamp: float = snappedf(recorder.frame_time(k), 0.001)
		if not seen.has(stamp):
			continue
		replay._clock = recorder.frame_time(k)
		replay._apply()
		var want: Dictionary = seen[stamp]
		var got: Dictionary = _look(kraken)
		assert_eq(got["active"], want["active"], "tentacles at %s" % stamp)
		assert_eq(got["swing"], want["swing"], "swing at %s" % stamp)
		assert_eq(got["phase"], want["phase"], "phase at %s" % stamp)
		assert_almost_eq(got["alert"] as float, want["alert"] as float, 0.001)
		assert_almost_eq((got["look"] as Vector2).x, (want["look"] as Vector2).x, 0.001)
		compared += 1
	assert_gt(compared, 10)
	replay.stop()
	assert_true(kraken.get_active_tentacles().is_empty(), "back to quiet after the replay")
