extends GutTest
## The whirlpool map: the vortex that spins marbles and flings them out of the exits.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _whirlpool() -> Whirlpool:
	var track: Track = TrackCatalog.instantiate("whirlpool")
	add_child_autofree(track)
	return track.get_hazards()[0] as Whirlpool


func _marble(at: Vector2) -> Marble:
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	marble.gravity_scale = 0.0
	add_child_autofree(marble)
	marble.global_position = at
	return marble


func test_map_is_registered_with_a_hazard_and_three_exits() -> void:
	assert_true(TrackCatalog.has_map("whirlpool"))
	assert_eq(TrackCatalog.get_name_of("whirlpool"), "Whirlpool")
	var whirlpool: Whirlpool = _whirlpool()
	assert_not_null(whirlpool)
	assert_eq(whirlpool.exit_degrees.size(), 3)


func test_vortex_spins_a_marble_around_the_middle() -> void:
	var whirlpool: Whirlpool = _whirlpool()
	var center: Vector2 = whirlpool.get_center()
	var marble: Marble = _marble(center + Vector2(0.0, -150.0))
	await wait_physics_frames(20)
	var offset: Vector2 = marble.global_position - center
	var around: Vector2 = Vector2(-offset.y, offset.x).normalized()
	assert_gt(marble.linear_velocity.dot(around), 100.0, "spun in the direction of the vortex")


func test_marble_at_an_exit_is_flung_out_of_it_after_a_while() -> void:
	var whirlpool: Whirlpool = _whirlpool()
	var center: Vector2 = whirlpool.get_center()
	var exit: Vector2 = whirlpool.get_exit_direction(1)
	var marble: Marble = _marble(center + exit * whirlpool.get_radius() * 0.8)
	marble.id = 0
	await wait_physics_frames(3)
	whirlpool._needed[marble.get_instance_id()] = 0.0
	whirlpool._dwell[marble.get_instance_id()] = Whirlpool.MIN_DWELL
	await wait_physics_frames(2)
	assert_gt(marble.linear_velocity.dot(exit), Whirlpool.EJECT_SPEED * 0.8, "flung outward")


func test_marble_circling_too_long_is_flung_toward_an_exit() -> void:
	var whirlpool: Whirlpool = _whirlpool()
	var center: Vector2 = whirlpool.get_center()
	# Halfway between two exits, so no exit is within reach.
	var away: Vector2 = Vector2.from_angle(deg_to_rad(57.5))
	var marble: Marble = _marble(center + away * whirlpool.get_radius() * 0.8)
	await wait_physics_frames(3)
	whirlpool._dwell[marble.get_instance_id()] = Whirlpool.MAX_DWELL
	await wait_physics_frames(2)
	assert_gt(marble.linear_velocity.length(), Whirlpool.EJECT_SPEED * 0.5, "released")
	assert_gt(marble.linear_velocity.dot(away), 0.0, "heading out")


func test_marble_leaves_alone_for_a_while_after_release() -> void:
	var whirlpool: Whirlpool = _whirlpool()
	var center: Vector2 = whirlpool.get_center()
	var marble: Marble = _marble(center + Vector2(0.0, 120.0))
	await wait_physics_frames(3)
	whirlpool._cooldown[marble.get_instance_id()] = 1.0
	marble.linear_velocity = Vector2.ZERO
	await wait_physics_frames(5)
	assert_lt(marble.linear_velocity.length(), 1.0, "no vortex force during the cooldown")


func test_surge_strengthens_the_vortex_then_calms() -> void:
	var whirlpool: Whirlpool = _whirlpool()
	assert_eq(whirlpool.get_strength(), 1.0)
	whirlpool.arm(3, 3)
	var spent: float = 0.0
	while whirlpool.phase != Hazard.Phase.ACTIVE and spent < 100.0:
		whirlpool.tick(STEP)
		spent += STEP
	assert_eq(whirlpool.phase, Hazard.Phase.ACTIVE)
	for i: int in 90:
		whirlpool._physics_process(STEP)
	assert_gt(whirlpool.get_strength(), 1.3)
	whirlpool.disarm()
	assert_eq(whirlpool.get_strength(), 1.0)


func test_the_spin_never_reverses() -> void:
	var whirlpool: Whirlpool = _whirlpool()
	for seed_value: int in range(1, 40):
		whirlpool.arm(seed_value, 3)
		whirlpool._begin_telegraph(_rng(seed_value))
		assert_eq(whirlpool.get_spin(), 1.0, "seed %d" % seed_value)


func test_a_marble_cannot_drop_out_of_a_closed_exit() -> void:
	var whirlpool: Whirlpool = _whirlpool()
	var center: Vector2 = whirlpool.get_center()
	for exit: int in whirlpool.exit_degrees.size():
		var dir: Vector2 = whirlpool.get_exit_direction(exit)
		var marble: Marble = _marble(center + dir * whirlpool.get_radius() * 0.6)
		marble.linear_velocity = dir * 700.0
		await wait_physics_frames(1)
		whirlpool._needed[marble.get_instance_id()] = 1000.0
		await wait_physics_frames(40)
		var gone: float = (marble.global_position - center).dot(dir)
		assert_lt(gone, whirlpool.get_radius() + 4.0, "exit %d stayed shut" % exit)


func test_a_released_marble_passes_its_gate_and_the_gate_shuts_behind_it() -> void:
	var whirlpool: Whirlpool = _whirlpool()
	var center: Vector2 = whirlpool.get_center()
	var dir: Vector2 = whirlpool.get_exit_direction(1)
	var marble: Marble = _marble(center + dir * whirlpool.get_radius() * 0.8)
	marble.id = 0
	await wait_physics_frames(3)
	whirlpool._needed[marble.get_instance_id()] = 0.0
	whirlpool._dwell[marble.get_instance_id()] = Whirlpool.MIN_DWELL
	await wait_physics_frames(60)
	var out: float = (marble.global_position - center).dot(dir)
	assert_gt(out, whirlpool.get_radius() + 40.0, "flung out through the gate")
	await wait_physics_frames(int(Whirlpool.EJECT_COOLDOWN * 60.0) + 10)
	assert_true(whirlpool._passing.is_empty(), "gate pass handed back")


func test_a_marble_freed_during_its_gate_pass_is_dropped_quietly() -> void:
	var whirlpool: Whirlpool = _whirlpool()
	var center: Vector2 = whirlpool.get_center()
	var dir: Vector2 = whirlpool.get_exit_direction(1)
	var marble: Marble = _marble(center + dir * whirlpool.get_radius() * 0.8)
	marble.id = 0
	await wait_physics_frames(3)
	whirlpool._needed[marble.get_instance_id()] = 0.0
	whirlpool._dwell[marble.get_instance_id()] = Whirlpool.MIN_DWELL
	await wait_physics_frames(3)
	assert_false(whirlpool._passing.is_empty(), "released")
	marble.free()
	await wait_physics_frames(int(Whirlpool.EJECT_COOLDOWN * 60.0) + 10)
	assert_true(whirlpool._passing.is_empty(), "pass dropped")


func test_the_vortex_runs_without_hazards_armed() -> void:
	var whirlpool: Whirlpool = _whirlpool()
	assert_false(whirlpool.is_armed())
	var marble: Marble = _marble(whirlpool.get_center() + Vector2(100.0, 0.0))
	await wait_physics_frames(10)
	assert_gt(marble.linear_velocity.length(), 50.0)


func test_time_in_the_basin_differs_between_marbles_and_between_races() -> void:
	var first: Whirlpool = _whirlpool()
	var second: Whirlpool = _whirlpool()
	first.arm(1, 3)
	second.arm(2, 3)
	var spot: Vector2 = first.get_center()
	var a: Marble = _marble(spot)
	var b: Marble = _marble(spot)
	a.id = 1
	b.id = 2
	assert_ne(first._dwell_needed(a), first._dwell_needed(b), "marbles differ")
	assert_ne(first._dwell_needed(a), second._dwell_needed(a), "seeds differ")
	assert_eq(first._dwell_needed(a), first._dwell_needed(a), "replays exactly")
	var needed: float = first._dwell_needed(a)
	assert_gte(needed, Whirlpool.MIN_DWELL)
	assert_lte(needed, Whirlpool.MIN_DWELL + Whirlpool.DWELL_SPREAD)


func _track() -> Track:
	var track: Track = TrackCatalog.instantiate("whirlpool")
	add_child_autofree(track)
	return track


func test_progress_is_the_same_all_the_way_round_the_basin() -> void:
	# Measured against the route it read 0.45 to 0.6 depending on the side the fish was on,
	# so the follow cam hopped between the fish circling in it.
	var track: Track = _track()
	var whirlpool: Whirlpool = track.get_hazards()[0] as Whirlpool
	var center: Vector2 = whirlpool.get_center()
	var first: float = track.get_progress(center)
	for step: int in 36:
		for fraction: float in [0.3, 0.6, 0.95]:
			var at: Vector2 = (
				center + Vector2.from_angle(TAU * step / 36.0) * whirlpool.get_radius() * fraction
			)
			assert_almost_eq(track.get_progress(at), first, 0.0001, "%s" % at)


func test_progress_never_jumps_between_the_entry_the_basin_and_the_exits() -> void:
	var track: Track = _track()
	var whirlpool: Whirlpool = track.get_hazards()[0] as Whirlpool
	var center: Vector2 = whirlpool.get_center()
	var finish: Vector2 = track.get_finish_position()
	# Down the entry ramp, through the basin, out of each exit and on to the finish.
	var walks: Array[PackedVector2Array] = []
	for exit: int in whirlpool.exit_degrees.size():
		var out: Vector2 = whirlpool.get_exit_direction(exit)
		var walk: PackedVector2Array = PackedVector2Array(
			[Vector2(100, 160), Vector2(400, 250), Vector2(690, 335), center]
		)
		walk.append(center + out * whirlpool.get_radius() * 1.2)
		walk.append(Vector2(center.x + out.x * 450.0, finish.y - 40.0))
		walk.append(finish)
		walks.append(walk)
	for walk: PackedVector2Array in walks:
		var last: float = track.get_progress(walk[0])
		for i: int in range(1, walk.size()):
			var steps: int = 40
			for s: int in range(1, steps + 1):
				var at: Vector2 = walk[i - 1].lerp(walk[i], float(s) / steps)
				var now: float = track.get_progress(at)
				assert_lt(absf(now - last), 0.06, "jumped at %s" % at)
				assert_gte(now, last - 0.02, "went backwards at %s" % at)
				last = now
		assert_gt(last, 0.95, "reaches the finish")
