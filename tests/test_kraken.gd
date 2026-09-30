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


func test_each_event_picks_one_or_two_different_tentacles() -> void:
	var kraken: KrakenHazard = _kraken()
	var seen: Dictionary = {}
	for seed_value: int in range(1, 41):
		_arm_now(kraken, seed_value)
		await wait_until(func() -> bool: return kraken.phase == Hazard.Phase.TELEGRAPH, 2.0)
		var picked: Array[int] = kraken.get_active_tentacles()
		assert_between(picked.size(), 1, 2, "seed %d" % seed_value)
		if picked.size() == 2:
			assert_ne(picked[0], picked[1])
		seen[picked.size()] = true
		kraken.disarm()
	assert_eq(seen.size(), 2, "both single and double swats happen")


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
	await wait_physics_frames(12)
	var swing_direction: Vector2 = Vector2(-sin(start_angle), cos(start_angle)) * swing
	assert_gt(marble.linear_velocity.dot(swing_direction), 100.0, "flung along the sweep")


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
	_arm_now(kraken, 2, 1.0)
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
		assert_eq(area.position, KrakenHazard.PARKED)


func test_a_seed_replays_the_same_tentacles() -> void:
	var picks: Array = []
	for round: int in 2:
		var kraken: KrakenHazard = _kraken()
		_arm_now(kraken, 11)
		await wait_until(func() -> bool: return kraken.phase == Hazard.Phase.TELEGRAPH, 2.0)
		picks.append([kraken.get_active_tentacles(), kraken.get("_swing")])
	assert_eq(picks[0], picks[1])
