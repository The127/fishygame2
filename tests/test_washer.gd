extends GutTest
## Washing Machine: the drum tumbles once a race starts, the spin cycle whirls it through whole
## turns and everything goes back to rest afterwards.

const STEP: float = 1.0 / 60.0

var _track: Track
var _drum: WashDrum
var _spin: SpinCycleHazard


func before_each() -> void:
	_track = TrackCatalog.instantiate("washer")
	add_child_autofree(_track)
	_drum = _track.find_child("Drum", true, false) as WashDrum
	_spin = _track.get_hazards()[0] as SpinCycleHazard


func _run(seconds: float) -> void:
	for i: int in roundi(seconds / STEP):
		_drum._physics_process(STEP)


func test_the_drum_rests_until_a_race_starts() -> void:
	assert_not_null(_drum)
	assert_false(_drum.spinning)
	_run(5.0)
	assert_eq(_drum.angle, 0.0)


func test_a_seeded_start_swings_out_and_back() -> void:
	_drum.start_delay_min = 0.0
	_drum.start_delay_max = 0.0
	_track.seed_gimmicks(RandomNumberGenerator.new())
	assert_true(_drum.spinning)
	assert_eq(_drum.angle, 0.0, "the drum does not jump when the race starts")
	_run(_drum.tumble_seconds * 0.5)
	assert_almost_eq(rad_to_deg(_drum.angle), _drum.tumble_degrees, 1.0, "half way: fully out")
	_run(_drum.tumble_seconds * 0.5)
	assert_almost_eq(_drum.angle, 0.0, 0.05, "a full swing brings it back")


func test_the_start_delay_holds_the_drum_still_for_a_moment() -> void:
	_drum.start_delay_min = 1.0
	_drum.start_delay_max = 1.0
	_drum.reseed(1)
	_run(0.9)
	assert_eq(_drum.angle, 0.0)
	_run(1.0)
	assert_gt(_drum.angle, 0.0)


func test_the_swing_never_leaves_its_range() -> void:
	_drum.reseed(4)
	var low: float = INF
	var high: float = -INF
	for i: int in roundi(_drum.tumble_seconds * 3.0 / STEP):
		_drum._physics_process(STEP)
		low = minf(low, _drum.angle)
		high = maxf(high, _drum.angle)
	assert_gte(low, -0.0001)
	assert_lte(high, deg_to_rad(_drum.tumble_degrees) + 0.0001)


func test_the_door_sweeps_past_the_bottom_every_swing() -> void:
	_drum.reseed(1)
	var passes: int = 0
	var before: float = _drum.door_world_degrees()
	for i: int in roundi(_drum.start_delay_max / STEP + _drum.tumble_seconds * 2.0 / STEP):
		_drum._physics_process(STEP)
		var now: float = _drum.door_world_degrees()
		if (before < 90.0) != (now < 90.0) and absf(now - before) < 90.0:
			passes += 1
		before = now
	assert_gte(passes, 3, "out, back, out again")


func test_stop_puts_the_drum_back_at_rest() -> void:
	_drum.reseed(2)
	_run(6.0)
	assert_ne(_drum.angle, 0.0)
	_track.stop_gimmicks()
	assert_false(_drum.spinning)
	assert_eq(_drum.angle, 0.0)


func test_the_rim_has_a_gap_where_the_door_is() -> void:
	var shapes: int = 0
	for child: Node in _drum.get_children():
		if child is CollisionPolygon2D:
			shapes += 1
	assert_eq(shapes, WashDrum.SEGMENTS - _drum.door_segments)


func test_a_spin_cycle_turns_whole_laps_and_leaves_the_drum_where_it_was() -> void:
	_drum.reseed(3)
	_run(_drum.start_delay_max + 4.0)
	_spin.arm(9, 3)
	# Runs the event by hand and compares with a drum that never spun.
	while _spin.phase != Hazard.Phase.ACTIVE:
		_spin.tick(STEP)
		_drum._physics_process(STEP)
	var peak: float = 0.0
	while _spin.phase == Hazard.Phase.ACTIVE:
		_spin.tick(STEP)
		_drum._physics_process(STEP)
		peak = maxf(peak, absf(_drum.spin))
	assert_gte(peak, TAU * 0.5, "the drum winds up at least most of a lap")
	assert_eq(_drum.spin, 0.0, "the extra turn is dropped again when the event ends")
	var swing: float = deg_to_rad(_drum.tumble_degrees)
	assert_between(_drum.angle, -0.05, swing + 0.05, "back in the usual tumble")


func test_the_spin_turns_a_whole_number_of_laps() -> void:
	_spin.arm(5, 3)
	for seed_value: int in 20:
		_spin._begin_telegraph(_rng(seed_value))
		var laps: float = absf(_spin._turns)
		assert_eq(laps, roundf(laps), "whole laps only")
		assert_gte(laps, float(SpinCycleHazard.TURNS_MIN))
		assert_lte(laps, float(SpinCycleHazard.TURNS_MAX))


func test_the_drum_turns_even_with_hazards_off() -> void:
	_track.arm_hazards(_rng(1), 0)
	_track.seed_gimmicks(_rng(1))
	_run(_drum.start_delay_max + 3.0)
	assert_ne(_drum.angle, 0.0)


func test_the_alarm_flashes_during_the_warning() -> void:
	_spin.arm(2, 3)
	while _spin.phase != Hazard.Phase.TELEGRAPH:
		_spin.tick(STEP)
	for i: int in 40:
		_spin.tick(STEP)
	assert_gt(_drum.alarm, 0.0)
	_spin.disarm()
	assert_eq(_drum.alarm, 0.0)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_fish_dropping_onto_the_left_of_the_first_lane_are_not_ahead() -> void:
	# The lane reaches left of the drum, well above the finish at the far end of the route.
	# Progress must not read the finish as the nearest point there (the follow cam chased it).
	var dropped: float = _track.get_progress(Vector2(540, 600))
	var rolling: float = _track.get_progress(Vector2(1200, 705))
	var home_run: float = _track.get_progress(Vector2(700, 925))
	assert_lt(dropped, 0.2, "a fish on the left of the first lane has barely started")
	assert_lt(dropped, rolling)
	assert_lt(rolling, home_run)


func test_the_rings_nest_and_turn_different_ways() -> void:
	var rings: Array[WashDrum] = _spin.get_drums()
	assert_eq(rings.size(), 3, "an outer drum with two rings inside")
	for i: int in rings.size() - 1:
		assert_gt(
			rings[i].outer_radius - rings[i + 1].outer_radius, 60.0, "room for a fish between"
		)
		assert_ne(rings[i].direction, rings[i + 1].direction, "neighbours swing opposite ways")
		assert_ne(rings[i].tumble_seconds, rings[i + 1].tumble_seconds, "at their own pace")
