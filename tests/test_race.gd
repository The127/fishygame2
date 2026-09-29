extends GutTest

const TRACK_SCENE: String = "res://scenes/tracks/test_track.tscn"
const MARBLE_SCENE: String = "res://scenes/marble.tscn"


func _make_race() -> Array:
	var track: Track = (load(TRACK_SCENE) as PackedScene).instantiate() as Track
	add_child_autofree(track)
	var race: Race = Race.new()
	race.marble_scene = load(MARBLE_SCENE) as PackedScene
	add_child_autofree(race)
	return [race, track]


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_restart_replaces_marbles_and_ignores_stale_finish() -> void:
	var parts: Array = _make_race()
	var race: Race = parts[0] as Race
	var track: Track = parts[1] as Track
	race.start(track, 4, _rng(1))
	var old: Marble = race.get_marbles()[0]
	race.start(track, 4, _rng(1))
	assert_eq(race.get_marbles().size(), 4)
	assert_false(race.get_marbles().has(old))
	watch_signals(race)
	track.marble_reached_finish.emit(old)
	assert_signal_not_emitted(race, "marble_finished")


func test_finish_signal_reports_place() -> void:
	var parts: Array = _make_race()
	var race: Race = parts[0] as Race
	var track: Track = parts[1] as Track
	race.start(track, 3, _rng(2))
	watch_signals(race)
	var marbles: Array[Marble] = race.get_marbles()
	track.marble_reached_finish.emit(marbles[2])
	assert_signal_emitted_with_parameters(race, "marble_finished", [2, 1])


func test_position_map_skips_finished_marbles() -> void:
	var parts: Array = _make_race()
	var race: Race = parts[0] as Race
	var track: Track = parts[1] as Track
	race.start(track, 3, _rng(3))
	assert_eq(race.get_position_map().size(), 3)
	track.marble_reached_finish.emit(race.get_marbles()[0])
	assert_eq(race.get_position_map().size(), 2)


func test_effects_spawn_particles_and_glow_state() -> void:
	var parts: Array = _make_race()
	var race: Race = parts[0] as Race
	var track: Track = parts[1] as Track
	race.start(track, 2, _rng(3))
	var marble: Marble = race.get_marbles()[0]
	var before: int = marble.get_child_count()
	marble.boost(Vector2.DOWN)
	assert_gt(marble.get_child_count(), before, "boost adds a burst")
	marble.curse(Vector2.DOWN)
	marble.celebrate()
	marble.splash()
	assert_true(marble.is_cursed())


func test_cheer_nudges_a_live_marble_forward() -> void:
	var parts: Array = _make_race()
	var race: Race = parts[0] as Race
	var track: Track = parts[1] as Track
	race.start(track, 2, _rng(3))
	var marble: Marble = race.get_marbles()[0]
	marble.gravity_scale = 0.0
	marble.linear_velocity = Vector2.ZERO
	assert_true(race.cheer_marble(marble.id, 2.0))
	await wait_physics_frames(2)
	var forward: Vector2 = track.get_forward(marble.global_position)
	assert_gt(marble.linear_velocity.dot(forward), 0.0)


func test_cheer_is_refused_for_finished_or_unknown_marbles() -> void:
	var parts: Array = _make_race()
	var race: Race = parts[0] as Race
	var track: Track = parts[1] as Track
	race.start(track, 3, _rng(4))
	track.marble_reached_finish.emit(race.get_marbles()[0])
	assert_false(race.cheer_marble(0, 1.0))
	assert_false(race.cheer_marble(99, 1.0))


func test_cheer_strength_is_capped_below_a_boost() -> void:
	var parts: Array = _make_race()
	var race: Race = parts[0] as Race
	var track: Track = parts[1] as Track
	race.start(track, 2, _rng(5))
	var marble: Marble = race.get_marbles()[0]
	marble.gravity_scale = 0.0
	marble.linear_velocity = Vector2.ZERO
	race.cheer_marble(marble.id, 1000.0)
	await wait_physics_frames(2)
	assert_lt(marble.linear_velocity.length(), Marble.BOOST_IMPULSE)


func _place_near_finish(marble: Marble, track: Track, distance: float, speed: float) -> void:
	marble.freeze = true
	marble.global_position = track.get_finish_position() + Vector2(0.0, -distance)
	marble.linear_velocity = Vector2(0.0, speed)


func test_photo_finish_when_chaser_is_about_to_cross() -> void:
	var parts: Array = _make_race()
	var race: Race = parts[0] as Race
	var track: Track = parts[1] as Track
	race.start(track, 3, _rng(4))
	var marbles: Array[Marble] = race.get_marbles()
	_place_near_finish(marbles[1], track, 40.0, 400.0)
	_place_near_finish(marbles[2], track, 60.0, 400.0)
	watch_signals(race)
	track.marble_reached_finish.emit(marbles[0])
	assert_signal_emitted_with_parameters(race, "photo_finish", [0, 1])


func test_no_photo_finish_when_chasers_are_far_or_slow() -> void:
	var parts: Array = _make_race()
	var race: Race = parts[0] as Race
	var track: Track = parts[1] as Track
	race.start(track, 3, _rng(4))
	var marbles: Array[Marble] = race.get_marbles()
	_place_near_finish(marbles[1], track, 900.0, 400.0)
	_place_near_finish(marbles[2], track, 40.0, 0.0)
	watch_signals(race)
	track.marble_reached_finish.emit(marbles[0])
	assert_signal_not_emitted(race, "photo_finish")


func test_photo_finish_only_for_the_winner() -> void:
	var parts: Array = _make_race()
	var race: Race = parts[0] as Race
	var track: Track = parts[1] as Track
	race.start(track, 3, _rng(4))
	var marbles: Array[Marble] = race.get_marbles()
	track.marble_reached_finish.emit(marbles[0])
	_place_near_finish(marbles[2], track, 40.0, 400.0)
	watch_signals(race)
	track.marble_reached_finish.emit(marbles[1])
	assert_signal_not_emitted(race, "photo_finish")
