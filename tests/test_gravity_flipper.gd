extends GutTest
## The gravity flips of the Gravity Flip map.


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _track() -> Track:
	var track: Track = TrackCatalog.instantiate("gravity")
	add_child_autofree(track)
	return track


func _flipper(track: Track) -> GravityFlipper:
	return track.get_node("Flipper") as GravityFlipper


func _zone_direction(flipper: GravityFlipper) -> Vector2:
	return (flipper.get_node("Zone") as Area2D).gravity_direction


func _zone_gravity(flipper: GravityFlipper) -> float:
	return (flipper.get_node("Zone") as Area2D).gravity


func test_map_is_registered() -> void:
	assert_true(TrackCatalog.has_map("gravity"))
	assert_eq(TrackCatalog.get_name_of("gravity"), "Gravity Flip")


func test_map_has_music_ambience_and_a_jingle() -> void:
	for path: String in [
		TrackCatalog.music_path("gravity"),
		TrackCatalog.ambience_path("gravity"),
		TrackCatalog.jingle_path("gravity"),
	]:
		assert_true(ResourceLoader.exists(path), path)


func test_gravity_starts_down_and_nothing_is_planned_until_seeded() -> void:
	var flipper: GravityFlipper = _flipper(_track())
	assert_eq(flipper.pull, GravityFlipper.Pull.DOWN)
	assert_false(flipper.is_armed())
	assert_eq(flipper.get_schedule().size(), 0)
	assert_gt(_zone_direction(flipper).y, 0.0)


func test_same_seed_plans_the_same_flips() -> void:
	var first: GravityFlipper = _flipper(_track())
	var second: GravityFlipper = _flipper(_track())
	first.reseed(7)
	second.reseed(7)
	assert_eq(first.get_schedule(), second.get_schedule())
	assert_eq(first.get_pulls(), second.get_pulls())


func test_different_seeds_plan_different_flips() -> void:
	var first: GravityFlipper = _flipper(_track())
	var second: GravityFlipper = _flipper(_track())
	first.reseed(7)
	second.reseed(8)
	assert_ne(first.get_schedule(), second.get_schedule())


func test_track_seeding_arms_the_flipper() -> void:
	var track: Track = _track()
	track.seed_gimmicks(_rng(3))
	assert_true(_flipper(track).is_armed())


func test_flips_are_spaced_within_the_interval() -> void:
	var flipper: GravityFlipper = _flipper(_track())
	for seed_value: int in 10:
		flipper.reseed(seed_value)
		var times: Array[float] = flipper.get_schedule()
		assert_gte(times[0], GravityFlipper.FIRST_MIN)
		assert_lte(times[0], GravityFlipper.FIRST_MAX)
		for i: int in range(1, times.size()):
			assert_gte(times[i] - times[i - 1], GravityFlipper.MIN_INTERVAL - 0.001)
			assert_lte(times[i] - times[i - 1], GravityFlipper.MAX_INTERVAL + 0.001)


func test_every_flip_changes_the_floor() -> void:
	var flipper: GravityFlipper = _flipper(_track())
	for seed_value: int in 10:
		flipper.reseed(seed_value)
		var pulls: Array[int] = flipper.get_pulls()
		assert_ne(pulls[0], GravityFlipper.Pull.DOWN)
		for i: int in range(1, pulls.size()):
			assert_ne(pulls[i], pulls[i - 1])


func test_all_four_sides_turn_up_as_the_floor() -> void:
	var flipper: GravityFlipper = _flipper(_track())
	var seen: Dictionary = {}
	for seed_value: int in 20:
		flipper.reseed(seed_value)
		for side: int in flipper.get_pulls():
			seen[side] = true
	assert_eq(seen.size(), 4)


func test_gravity_turns_at_the_planned_time() -> void:
	var flipper: GravityFlipper = _flipper(_track())
	flipper.reseed(5)
	var first: float = flipper.get_schedule()[0]
	var side: GravityFlipper.Pull = flipper.get_pulls()[0] as GravityFlipper.Pull
	flipper.tick(first - 0.1)
	assert_eq(flipper.pull, GravityFlipper.Pull.DOWN)
	flipper.tick(0.2)
	assert_eq(flipper.pull, side)
	assert_eq(_zone_direction(flipper), GravityFlipper.direction_of(side, flipper.lean))


func test_sides_pull_toward_their_wall() -> void:
	assert_gt(GravityFlipper.direction_of(GravityFlipper.Pull.DOWN).y, 0.5)
	assert_lt(GravityFlipper.direction_of(GravityFlipper.Pull.UP).y, -0.5)
	assert_gt(GravityFlipper.direction_of(GravityFlipper.Pull.RIGHT).x, 0.5)
	assert_lt(GravityFlipper.direction_of(GravityFlipper.Pull.LEFT).x, -0.5)
	for side: int in 4:
		assert_almost_eq(
			GravityFlipper.direction_of(side as GravityFlipper.Pull).length(), 1.0, 0.001
		)


func test_flip_is_announced_by_a_signal() -> void:
	var flipper: GravityFlipper = _flipper(_track())
	watch_signals(flipper)
	flipper.turn_to(GravityFlipper.Pull.UP)
	assert_signal_emitted_with_parameters(flipper, "flipped", [GravityFlipper.Pull.UP])


func test_warning_builds_in_the_second_before_a_flip() -> void:
	var flipper: GravityFlipper = _flipper(_track())
	flipper.reseed(5)
	var first: float = flipper.get_schedule()[0]
	flipper.tick(first - GravityFlipper.WARNING_SECONDS - 0.1)
	assert_eq(flipper.warning(), 0.0)
	flipper.tick(GravityFlipper.WARNING_SECONDS * 0.5 + 0.1)
	assert_between(flipper.warning(), 0.4, 0.6)
	flipper.tick(GravityFlipper.WARNING_SECONDS * 0.5 - 0.05)
	assert_gt(flipper.warning(), 0.9)


func test_the_next_pull_is_known_before_the_flip() -> void:
	var flipper: GravityFlipper = _flipper(_track())
	flipper.reseed(5)
	assert_eq(flipper.next_pull(), flipper.get_pulls()[0])


func test_gravity_thins_out_before_a_flip_and_returns_after() -> void:
	var flipper: GravityFlipper = _flipper(_track())
	flipper.reseed(5)
	var base: float = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	flipper.tick(flipper.get_schedule()[0] - 2.0)
	assert_almost_eq(flipper.weight(), 1.0, 0.001)
	flipper.tick(2.0 - 0.01)
	assert_lt(flipper.weight(), 0.3)
	assert_lt(_zone_gravity(flipper), base * 0.3)
	flipper.tick(0.02 + GravityFlipper.RETURN_SECONDS)
	assert_gt(flipper.weight(), 0.95)


func test_disarm_puts_gravity_back_down() -> void:
	var flipper: GravityFlipper = _flipper(_track())
	flipper.reseed(5)
	flipper.turn_to(GravityFlipper.Pull.LEFT)
	flipper.disarm()
	assert_eq(flipper.pull, GravityFlipper.Pull.DOWN)
	assert_false(flipper.is_armed())
	assert_gt(_zone_direction(flipper).y, 0.0)
	assert_almost_eq(flipper.weight(), 1.0, 0.001)


func test_stop_gimmicks_disarms_the_flipper() -> void:
	var track: Track = _track()
	track.seed_gimmicks(_rng(3))
	track.stop_gimmicks()
	assert_false(_flipper(track).is_armed())


func test_finish_spans_the_room_so_every_orientation_reaches_it() -> void:
	var track: Track = _track()
	var finish: Area2D = track.get_node("Finish") as Area2D
	var shape: RectangleShape2D = (
		(finish.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	)
	var top: float = finish.global_position.y - shape.size.y * 0.5
	var bottom: float = finish.global_position.y + shape.size.y * 0.5
	assert_lt(top, 100.0)
	assert_gt(bottom, 980.0)
