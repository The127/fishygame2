extends GutTest
## The Kraken's Lair map: tentacles that sweep across the ramps and the eye that watches them.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _kraken() -> KrakenHazard:
	var track: Track = TrackCatalog.instantiate("kraken")
	add_child_autofree(track)
	return track.get_hazards()[0] as KrakenHazard


func _marble(at: Vector2) -> Marble:
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	marble.gravity_scale = 0.0
	add_child_autofree(marble)
	marble.global_position = at
	return marble


## Arms the hazard so its first event starts at once, with a short telegraph.
func _arm_now(kraken: KrakenHazard, seed_value: int, telegraph: float = 0.05) -> void:
	kraken.telegraph_seconds = telegraph
	(kraken.get_parent() as Track).arm_hazards(_rng(seed_value), 3)
	kraken.clock = kraken.get_schedule()[0] - 0.05


func test_map_is_registered_with_a_kraken_and_four_tentacles() -> void:
	assert_true(TrackCatalog.has_map("kraken"))
	assert_eq(TrackCatalog.get_name_of("kraken"), "Kraken's Lair")
	var kraken: KrakenHazard = _kraken()
	assert_not_null(kraken)
	assert_eq(kraken.kind, "swat")
	assert_eq(kraken.roots.size(), 4)
	assert_not_null(kraken.get_node_or_null("Eye"))


func test_each_event_picks_one_to_three_different_tentacles() -> void:
	var kraken: KrakenHazard = _kraken()
	var seen: Dictionary = {}
	for seed_value: int in range(1, 41):
		_arm_now(kraken, seed_value)
		await wait_until(func() -> bool: return kraken.phase == Hazard.Phase.TELEGRAPH, 2.0)
		var picked: Array[int] = kraken.get_active_tentacles()
		assert_between(picked.size(), 1, 3, "seed %d" % seed_value)
		var unique: Dictionary = {}
		for index: int in picked:
			unique[index] = true
		assert_eq(unique.size(), picked.size(), "tentacles differ, seed %d" % seed_value)
		seen[picked.size()] = true
		kraken.disarm()
	assert_eq(seen.size(), 3, "single, double and triple swats all happen")


func test_a_sweep_swats_a_marble_along_its_swing() -> void:
	var kraken: KrakenHazard = _kraken()
	_arm_now(kraken, 4)
	await wait_until(func() -> bool: return kraken.phase == Hazard.Phase.TELEGRAPH, 2.0)
	var index: int = kraken.get_active_tentacles()[0]
	var swing: float = (kraken.get("_swing") as Array)[0]
	var start_angle: float = -PI * 0.5 - swing * kraken.half_arc
	var marble: Marble = _marble(
		kraken.roots[index] + Vector2.from_angle(start_angle) * kraken.reach * 0.7
	)
	await wait_until(func() -> bool: return kraken.phase == Hazard.Phase.ACTIVE, 2.0)
	await wait_physics_frames(20)
	var swing_direction: Vector2 = Vector2(-sin(start_angle), cos(start_angle)) * swing
	assert_gt(marble.linear_velocity.dot(swing_direction), 50.0, "flung along the sweep")


func test_a_marble_outside_the_sweep_is_left_alone() -> void:
	var kraken: KrakenHazard = _kraken()
	_arm_now(kraken, 4)
	var marble: Marble = _marble(Vector2(960.0, -300.0))
	await wait_until(func() -> bool: return kraken.phase == Hazard.Phase.ACTIVE, 2.0)
	await wait_physics_frames(12)
	assert_lt(marble.linear_velocity.length(), 1.0)


func test_the_eye_opens_for_the_telegraph_and_closes_again() -> void:
	var kraken: KrakenHazard = _kraken()
	var eye: KrakenEye = kraken.get_node("Eye") as KrakenEye
	assert_lt(eye.get_alert(), 0.05)
	_arm_now(kraken, 2, 1.5)
	await wait_until(func() -> bool: return kraken.phase == Hazard.Phase.ACTIVE, 3.0)
	assert_gt(eye.get_alert(), 0.5, "eye is wide open when the tentacle strikes")
	kraken.disarm()
	await wait_until(func() -> bool: return eye.get_alert() < 0.05, 3.0)
	assert_lt(eye.get_alert(), 0.05)


func test_disarm_parks_the_tentacles() -> void:
	var kraken: KrakenHazard = _kraken()
	_arm_now(kraken, 3)
	await wait_until(func() -> bool: return kraken.phase == Hazard.Phase.ACTIVE, 2.0)
	await wait_physics_frames(2)
	kraken.disarm()
	assert_true(kraken.get_active_tentacles().is_empty())
	for area: Area2D in kraken.find_children("*", "Area2D", false, false):
		if area != kraken.get("_sight"):
			assert_eq(area.position, KrakenHazard.PARKED)


func test_a_seed_replays_the_same_tentacles() -> void:
	var picks: Array = []
	for attempt: int in 2:
		var kraken: KrakenHazard = _kraken()
		_arm_now(kraken, 11)
		await wait_until(func() -> bool: return kraken.phase == Hazard.Phase.TELEGRAPH, 2.0)
		picks.append([kraken.get_active_tentacles(), kraken.get("_swing")])
	assert_eq(picks[0], picks[1])


func test_the_kraken_strikes_often_in_a_race() -> void:
	var kraken: KrakenHazard = _kraken()
	kraken.arm(5, 3)
	assert_gte(kraken.get_schedule().size(), 4, "at least four sweeps planned")
	var schedule: Array[float] = kraken.get_schedule()
	for i: int in range(1, schedule.size()):
		assert_lt(schedule[i] - schedule[i - 1], 9.0, "short gaps")


func test_the_eye_follows_the_leading_fish_between_sweeps() -> void:
	var kraken: KrakenHazard = _kraken()
	var eye: KrakenEye = kraken.get_node("Eye") as KrakenEye
	kraken.telegraph_seconds = 0.05
	(kraken.get_parent() as Track).arm_hazards(_rng(1), 3)
	var behind: Marble = _marble(Vector2(300.0, 200.0))
	var leader: Marble = _marble(Vector2(1500.0, 900.0))
	behind.freeze = true
	leader.freeze = true
	await wait_physics_frames(20)
	assert_eq(kraken.phase, Hazard.Phase.IDLE)
	assert_gt(eye.get_alert(), 0.1, "eye is half open while watching")
	assert_gt(eye._look.x, 0.2, "looks toward the leader on the right")
	assert_gt(eye._look.y, 0.2, "and below")


func test_idle_tentacles_hide_while_their_root_is_sweeping() -> void:
	var kraken: KrakenHazard = _kraken()
	var lurkers: KrakenLurkers = kraken.get_node("Lurkers") as KrakenLurkers
	_arm_now(kraken, 4)
	await wait_until(func() -> bool: return kraken.phase == Hazard.Phase.ACTIVE, 2.0)
	var busy: int = kraken.get_active_tentacles()[0]
	await wait_frames(60)
	assert_gt(lurkers._hidden[busy], 0.9, "the sweeping tentacle is hidden")
	kraken.disarm()
	await wait_frames(60)
	assert_lt(lurkers._hidden[busy], 0.05, "and back afterwards")
