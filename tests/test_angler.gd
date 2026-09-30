extends GutTest
## The anglerfish of the Abyss map: they swallow fish in reach and spit them out again.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _track() -> Track:
	var track: Track = TrackCatalog.instantiate("abyss")
	add_child_autofree(track)
	return track


func _anglers(track: Track) -> AnglerHazard:
	for hazard: Hazard in track.get_hazards():
		if hazard is AnglerHazard:
			return hazard as AnglerHazard
	return null


func _marble(at: Vector2) -> Marble:
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	marble.gravity_scale = 0.0
	add_child_autofree(marble)
	marble.global_position = at
	return marble


## One fish right in front of each angler's mouth, so whichever lair hunts has a meal.
func _bait(hazard: AnglerHazard) -> Array[Marble]:
	var fish: Array[Marble] = []
	for lair: int in hazard.get_lair_count():
		var lure: AnglerLure = hazard.get_child(lair) as AnglerLure
		fish.append(_marble(lure.to_global(lure.mouth_position()) + Vector2(0.0, 10.0)))
	return fish


## Arms the anglers and jumps the clock to just before the first event.
func _arm(track: Track, hazard: AnglerHazard) -> void:
	track.arm_hazards(_rng(3), 5)
	hazard.clock = hazard.get_schedule()[0] - 0.05


func _run_until(done: Callable, seconds: float = 12.0) -> bool:
	var frames: int = 0
	while not done.call() and frames < int(seconds / STEP):
		await wait_physics_frames(6)
		frames += 6
	return done.call()


func test_abyss_has_two_anglers_with_somewhere_to_spit_out() -> void:
	var hazard: AnglerHazard = _anglers(_track())
	assert_not_null(hazard)
	assert_eq(hazard.kind, "angler")
	assert_eq(hazard.get_lair_count(), 2)
	assert_eq(hazard.spit_points.size(), 2)


func test_swallow_hides_a_fish_and_release_brings_it_back() -> void:
	var marble: Marble = _marble(Vector2(300.0, 300.0))
	marble.swallow()
	assert_true(marble.eaten)
	assert_false(marble.visible)
	assert_eq(marble.collision_layer, 0)
	assert_eq(marble.times_eaten, 1)
	marble.release(Vector2(50.0, 60.0), Vector2(10.0, 0.0))
	assert_false(marble.eaten)
	assert_true(marble.visible)
	assert_ne(marble.collision_layer, 0)
	assert_eq(marble.global_position, Vector2(50.0, 60.0))


func test_a_fish_in_reach_is_eaten_then_spat_out_at_an_earlier_ramp() -> void:
	var track: Track = _track()
	var hazard: AnglerHazard = _anglers(track)
	var fish: Array[Marble] = _bait(hazard)
	watch_signals(track)
	watch_signals(hazard)
	_arm(track, hazard)
	var eaten: Callable = func() -> bool: return fish.any(func(m: Marble) -> bool: return m.eaten)
	assert_true(await _run_until(eaten), "a fish was eaten")
	assert_signal_emit_count(track, "fish_eaten", 1)
	var victim: Marble = fish.filter(func(m: Marble) -> bool: return m.eaten)[0]
	assert_false(victim.visible)
	assert_true(hazard.get_swallowed().has(victim))
	var spat: Callable = func() -> bool: return not victim.eaten
	assert_true(await _run_until(spat), "and spat out again")
	assert_signal_emitted(hazard, "fish_spat")
	assert_true(victim.visible)
	assert_true(hazard.get_swallowed().is_empty())
	var lair: int = fish.find(victim)
	assert_lt(victim.global_position.distance_to(hazard.get_spit_point(lair)), 120.0)


func test_a_fish_is_only_eaten_once() -> void:
	var track: Track = _track()
	var hazard: AnglerHazard = _anglers(track)
	var marble: Marble = _marble(Vector2(300.0, 300.0))
	assert_true(hazard._can_eat(marble))
	marble.swallow()
	assert_false(hazard._can_eat(marble), "already inside")
	marble.release(Vector2(300.0, 300.0), Vector2.ZERO)
	assert_false(hazard._can_eat(marble), "spared for the rest of the race")


func test_a_fish_that_finished_is_left_alone() -> void:
	var track: Track = _track()
	var hazard: AnglerHazard = _anglers(track)
	var fish: Array[Marble] = _bait(hazard)
	for marble: Marble in fish:
		marble.has_finished = true
	watch_signals(track)
	_arm(track, hazard)
	var idle_again: Callable = func() -> bool:
		return (
			hazard.phase == Hazard.Phase.IDLE
			and (
				hazard.clock
				> 1.0 + hazard.get_schedule()[0] + hazard.telegraph_seconds + hazard.active_seconds
			)
		)
	await _run_until(idle_again, 15.0)
	assert_signal_not_emitted(track, "fish_eaten")
	for marble: Marble in fish:
		assert_false(marble.eaten)


func test_an_event_with_nobody_in_reach_eats_nothing() -> void:
	var track: Track = _track()
	var hazard: AnglerHazard = _anglers(track)
	watch_signals(track)
	_arm(track, hazard)
	var idle_again: Callable = func() -> bool:
		return (
			hazard.clock
			> hazard.get_schedule()[0] + hazard.telegraph_seconds + hazard.active_seconds + 0.5
		)
	await _run_until(idle_again, 15.0)
	assert_signal_not_emitted(track, "fish_eaten")
	assert_eq(hazard.phase, Hazard.Phase.IDLE)
	assert_eq(hazard.get_active_lair(), -1)


func test_stopping_the_hazards_gives_swallowed_fish_back() -> void:
	var track: Track = _track()
	var hazard: AnglerHazard = _anglers(track)
	var fish: Array[Marble] = _bait(hazard)
	_arm(track, hazard)
	var eaten: Callable = func() -> bool: return fish.any(func(m: Marble) -> bool: return m.eaten)
	assert_true(await _run_until(eaten))
	track.stop_hazards()
	for marble: Marble in fish:
		assert_false(marble.eaten)
		assert_true(marble.visible)
	assert_true(hazard.get_swallowed().is_empty())


func test_eaten_fish_are_left_out_of_the_camera_framing() -> void:
	var track: Track = _track()
	var race: Race = Race.new()
	race.marble_scene = load(MARBLE_SCENE) as PackedScene
	add_child_autofree(race)
	race.start(track, 3, _rng(1))
	var marbles: Array[Marble] = race.get_marbles()
	assert_eq(race.get_position_map().size(), 3)
	marbles[1].swallow()
	assert_false(race.boost_marble(marbles[1].id), "no boosting a fish inside an angler")
	assert_false(race.curse_marble(marbles[1].id))
	assert_true(race.boost_marble(marbles[0].id))
	var positions: Dictionary = race.get_position_map()
	assert_eq(positions.size(), 2)
	assert_false(positions.has(marbles[1].id))
	race.clear()


func test_the_same_seed_replays_the_same_lairs() -> void:
	var first: AnglerHazard = _anglers(_track())
	var second: AnglerHazard = _anglers(_track())
	first.arm(9, 3)
	second.arm(9, 3)
	assert_eq(first.get_schedule(), second.get_schedule())
	var lairs: Array[int] = []
	for hazard: AnglerHazard in [first, second]:
		while hazard.phase != Hazard.Phase.TELEGRAPH:
			hazard.tick(STEP)
		lairs.append(hazard.get_active_lair())
	assert_eq(lairs[0], lairs[1])
