extends GutTest
## Earthquake Fault: the chat meter and the quakes that open the cracks.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0

var _track: Track
var _fault: QuakeFault


func before_each() -> void:
	_track = TrackCatalog.instantiate("fault")
	add_child_autofree(_track)
	_fault = _track.get_node("Fault") as QuakeFault
	# A body only takes its transform inside physics frames.
	await wait_physics_frames(3)


func _marble_at(pos: Vector2, gravity: float = 0.0) -> Marble:
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	marble.gravity_scale = gravity
	add_child_autofree(marble)
	marble.global_position = pos
	return marble


func _tick(seconds: float) -> void:
	for i: int in int(seconds / STEP):
		_fault.tick(STEP)


func _crack(node_name: String) -> FaultCrack:
	return _fault.get_node(node_name) as FaultCrack


## Presses as `count` different viewers.
func _spam(count: int, viewers: int = 0) -> void:
	for i: int in count:
		_fault.shake("viewer%d" % i, viewers)


func test_presses_needed_scale_with_the_viewers_within_limits() -> void:
	assert_eq(QuakeFault.presses_needed(0), QuakeFault.NEED_MIN)
	assert_eq(QuakeFault.presses_needed(5), QuakeFault.NEED_MIN)
	assert_eq(QuakeFault.presses_needed(20), 8)
	assert_eq(QuakeFault.presses_needed(1000), QuakeFault.NEED_MAX)


func test_a_disarmed_fault_ignores_presses() -> void:
	assert_false(_fault.shake("a", 10))
	assert_eq(_fault.counted_presses(), 0)


func test_too_few_presses_do_not_quake() -> void:
	_fault.reseed(1)
	_spam(QuakeFault.NEED_MIN - 1)
	assert_eq(_fault.quake_count(), 0)
	assert_eq(_fault.get_phase(), QuakeFault.Phase.CALM)


func test_enough_presses_start_a_quake_that_opens_a_crack() -> void:
	_fault.reseed(1)
	_spam(QuakeFault.NEED_MIN)
	assert_eq(_fault.quake_count(), 1)
	assert_eq(_fault.get_phase(), QuakeFault.Phase.RUMBLE)
	_tick(QuakeFault.RUMBLE_SECONDS + 0.1)
	assert_eq(_fault.get_phase(), QuakeFault.Phase.CALM)
	var open: int = 0
	for crack: FaultCrack in _fault.get_cracks():
		open += 1 if crack.is_open() else 0
	assert_eq(open, 1)


func test_one_viewer_cannot_quake_the_sea_alone() -> void:
	_fault.reseed(1)
	for i: int in 30:
		_fault.shake("spammer", 0)
	assert_eq(_fault.quake_count(), 0)
	assert_eq(_fault.counted_presses(), QuakeFault.PER_VIEWER)


func test_presses_expire_after_the_window() -> void:
	_fault.reseed(1)
	_spam(QuakeFault.NEED_MIN - 1)
	_tick(QuakeFault.WINDOW + 0.5)
	# The earlier presses are gone, so one more cannot make a quake (the seeded one may have come).
	assert_false(_fault.shake("late", 0))
	assert_eq(_fault.counted_presses(), 1)


func test_a_quake_has_a_cooldown() -> void:
	_fault.reseed(1)
	_spam(QuakeFault.NEED_MIN)
	_tick(QuakeFault.RUMBLE_SECONDS + 0.1)
	_spam(QuakeFault.NEED_MIN + 2)
	assert_eq(_fault.quake_count(), 1, "still cooling down")
	_tick(QuakeFault.COOLDOWN)
	_spam(QuakeFault.NEED_MIN)
	assert_eq(_fault.quake_count(), 2)


func test_the_fault_runs_out_of_cracks() -> void:
	_fault.reseed(1)
	for quake: int in 4:
		_spam(QuakeFault.NEED_MIN)
		_tick(QuakeFault.COOLDOWN + QuakeFault.RUMBLE_SECONDS)
	assert_eq(_fault.quake_count(), 4)
	_spam(QuakeFault.NEED_MIN)
	assert_eq(_fault.quake_count(), 4)
	assert_string_contains(_fault.meter_text(), "BROKEN")


func test_a_quiet_chat_still_gets_one_quake_at_the_seeded_time() -> void:
	_fault.reseed(5)
	assert_between(_fault.auto_time(), QuakeFault.AUTO_MIN, QuakeFault.AUTO_MAX)
	_tick(_fault.auto_time() - 0.5)
	assert_eq(_fault.quake_count(), 0)
	_tick(1.0)
	assert_eq(_fault.quake_count(), 1)
	_tick(60.0)
	assert_eq(_fault.quake_count(), 1, "only once without chat")


func test_a_chat_quake_spares_the_automatic_one() -> void:
	_fault.reseed(5)
	_spam(QuakeFault.NEED_MIN)
	_tick(_fault.auto_time() + 1.0)
	assert_eq(_fault.quake_count(), 1)


func test_a_seed_picks_the_same_crack_every_time() -> void:
	var opened: Array[String] = []
	for run: int in 2:
		_fault.reseed(77)
		_tick(_fault.auto_time() + QuakeFault.RUMBLE_SECONDS + 0.1)
		for crack: FaultCrack in _fault.get_cracks():
			if crack.is_open():
				opened.append(crack.name)
	assert_eq(opened.size(), 2)
	assert_eq(opened[0], opened[1])


func test_different_seeds_open_different_cracks() -> void:
	var seen: Dictionary = {}
	for seed_value: int in 24:
		_fault.reseed(seed_value)
		_tick(_fault.auto_time() + QuakeFault.RUMBLE_SECONDS + 0.1)
		for crack: FaultCrack in _fault.get_cracks():
			if crack.is_open():
				seen[crack.name] = true
	assert_gte(seen.size(), 3)


func test_the_quake_opens_the_crack_ahead_of_the_pack() -> void:
	# A fish at the bottom of the map has passed every crack, so any shut one is fine; a fish at
	# the top has passed none, so the seeded first one opens.
	_marble_at(Vector2(100, 100))
	_fault.reseed(3)
	_spam(QuakeFault.NEED_MIN)
	_tick(QuakeFault.RUMBLE_SECONDS + 0.1)
	var opened: FaultCrack
	for crack: FaultCrack in _fault.get_cracks():
		if crack.is_open():
			opened = crack
	assert_not_null(opened)
	assert_gt(opened.center().y, 100.0)


func test_the_pack_is_thrown_about_when_the_crack_opens() -> void:
	var marble: Marble = _marble_at(Vector2(900, 100))
	marble.sleeping = true
	_fault.reseed(2)
	_spam(QuakeFault.NEED_MIN)
	_tick(QuakeFault.RUMBLE_SECONDS + 0.1)
	await wait_physics_frames(2)
	assert_false(marble.sleeping)
	assert_lt(marble.linear_velocity.y, 0.0, "thrown upward")


func test_the_view_shakes_harder_when_the_crack_opens() -> void:
	watch_signals(_fault)
	_fault.reseed(2)
	_spam(QuakeFault.NEED_MIN)
	_tick(QuakeFault.RUMBLE_SECONDS + 0.1)
	var strengths: Array = []
	for i: int in get_signal_emit_count(_fault, "quake_shaken"):
		strengths.append(get_signal_parameters(_fault, "quake_shaken", i)[0])
	assert_gte(strengths.size(), 5, "it rumbles first")
	assert_almost_eq(float(strengths.back()), QuakeFault.OPEN_SHAKE, 0.01)
	assert_lt(float(strengths[0]), float(strengths[2]) + 0.01, "growing")


func test_the_track_passes_the_shake_and_the_meter_on() -> void:
	watch_signals(_track)
	_fault.reseed(2)
	assert_signal_emitted(_track, "shake_meter_changed")
	_spam(QuakeFault.NEED_MIN)
	_tick(QuakeFault.RUMBLE_SECONDS + 0.1)
	assert_signal_emitted(_track, "quake_shaken")
	assert_signal_emitted(_track, "burst_played")


func test_the_meter_counts_up_and_shows_the_quake() -> void:
	_fault.reseed(1)
	assert_string_contains(_fault.meter_text(), "0 / %d" % QuakeFault.NEED_MIN)
	_fault.shake("a", 0)
	assert_string_contains(_fault.meter_text(), "1 / %d" % QuakeFault.NEED_MIN)
	_spam(QuakeFault.NEED_MIN)
	assert_string_contains(_fault.meter_text(), "EARTHQUAKE")
	_tick(QuakeFault.RUMBLE_SECONDS + 0.1)
	assert_string_contains(_fault.meter_text(), "RECOVERING")


func test_stopping_the_gimmicks_shuts_the_floor_and_hides_the_meter() -> void:
	watch_signals(_fault)
	_fault.reseed(1)
	_tick(_fault.auto_time() + QuakeFault.RUMBLE_SECONDS + 0.1)
	_track.stop_gimmicks()
	assert_false(_fault.is_armed())
	for crack: FaultCrack in _fault.get_cracks():
		assert_false(crack.is_open())
		assert_almost_eq(crack.openness, 0.0, 0.001)
	assert_signal_emitted_with_parameters(_fault, "meter_changed", [""])
