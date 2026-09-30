extends GutTest
## The gravity flips of the Gravity Flip map.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0


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
	assert_false(flipper.up)
	assert_false(flipper.is_armed())
	assert_eq(flipper.get_schedule().size(), 0)
	assert_gt(_zone_direction(flipper).y, 0.0)


func test_same_seed_plans_the_same_flips() -> void:
	var first: GravityFlipper = _flipper(_track())
	var second: GravityFlipper = _flipper(_track())
	first.reseed(7)
	second.reseed(7)
	assert_eq(first.get_schedule(), second.get_schedule())


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


func test_gravity_flips_at_the_planned_time() -> void:
	var flipper: GravityFlipper = _flipper(_track())
	flipper.reseed(5)
	var first: float = flipper.get_schedule()[0]
	flipper.tick(first - 0.1)
	assert_false(flipper.up)
	flipper.tick(0.2)
	assert_true(flipper.up)
	assert_lt(_zone_direction(flipper).y, 0.0)
	flipper.tick(flipper.get_schedule()[1] - first)
	assert_false(flipper.up)
	assert_gt(_zone_direction(flipper).y, 0.0)


func test_flip_is_announced_by_a_signal() -> void:
	var flipper: GravityFlipper = _flipper(_track())
	watch_signals(flipper)
	flipper.flip()
	assert_signal_emitted_with_parameters(flipper, "flipped", [true])


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


func test_disarm_puts_gravity_back_down() -> void:
	var flipper: GravityFlipper = _flipper(_track())
	flipper.reseed(5)
	flipper.flip()
	flipper.disarm()
	assert_false(flipper.up)
	assert_false(flipper.is_armed())
	assert_gt(_zone_direction(flipper).y, 0.0)


func test_stop_gimmicks_disarms_the_flipper() -> void:
	var track: Track = _track()
	track.seed_gimmicks(_rng(3))
	track.stop_gimmicks()
	assert_false(_flipper(track).is_armed())


func test_a_fish_falls_up_after_the_flip() -> void:
	var track: Track = _track()
	var flipper: GravityFlipper = _flipper(track)
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	add_child_autofree(marble)
	marble.global_position = Vector2(900.0, 540.0)
	await wait_physics_frames(20)
	assert_gt(marble.linear_velocity.y, 0.0, "falls down at first")
	flipper.flip()
	await wait_physics_frames(60)
	assert_lt(marble.linear_velocity.y, 0.0, "falls up after the flip")


func test_a_sleeping_fish_wakes_when_gravity_flips() -> void:
	var track: Track = _track()
	var flipper: GravityFlipper = _flipper(track)
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	add_child_autofree(marble)
	marble.global_position = Vector2(900.0, 540.0)
	await wait_physics_frames(2)
	marble.sleeping = true
	flipper.flip()
	assert_false(marble.sleeping)


func test_gravity_leans_toward_the_finish_either_way() -> void:
	var flipper: GravityFlipper = _flipper(_track())
	assert_gt(_zone_direction(flipper).x, 0.0)
	flipper.flip()
	assert_gt(_zone_direction(flipper).x, 0.0)
	assert_almost_eq(_zone_direction(flipper).length(), 1.0, 0.001)


func test_finish_spans_the_corridor_so_both_orientations_reach_it() -> void:
	var track: Track = _track()
	var finish: Area2D = track.get_node("Finish") as Area2D
	var shape: RectangleShape2D = (
		(finish.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	)
	var top: float = finish.global_position.y - shape.size.y * 0.5
	var bottom: float = finish.global_position.y + shape.size.y * 0.5
	assert_lt(top, 150.0)
	assert_gt(bottom, 930.0)
