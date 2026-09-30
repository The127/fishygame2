extends GutTest
## The rubber duck easter egg: rare, deterministic for a seed, and purely visual.

const TRACK: PackedScene = preload("res://scenes/tracks/test_track.tscn")
const BOUNDS: Rect2 = Rect2(0.0, 0.0, 1920.0, 1080.0)


func test_appears_is_deterministic_and_rare() -> void:
	assert_eq(RubberDuck.appears(1234), RubberDuck.appears(1234))
	var hits: int = 0
	for seed_value: int in range(1, 5001):
		if RubberDuck.appears(seed_value):
			hits += 1
	# One in 25 is 200 of 5000.
	assert_between(hits, 120, 300)


func test_odds_of_one_always_appears() -> void:
	assert_true(RubberDuck.appears(5, 1))


func test_route_starts_off_screen_and_crosses_the_view() -> void:
	for seed_value: int in range(1, 30):
		var duck: RubberDuck = RubberDuck.create(seed_value, BOUNDS)
		add_child_autofree(duck)
		assert_true(duck.position.x < BOUNDS.position.x or duck.position.x > BOUNDS.end.x)
		assert_between(duck.position.y, BOUNDS.position.y, BOUNDS.end.y)
		assert_gt(absf(duck.velocity.x), 0.0)
		assert_true(duck.velocity.x * (BOUNDS.get_center().x - duck.position.x) > 0.0)


func test_duck_swims_across_and_leaves() -> void:
	var duck: RubberDuck = RubberDuck.create(3, BOUNDS)
	add_child(duck)
	var frames: int = 0
	while not duck.is_queued_for_deletion() and frames < 20000:
		duck._process(0.1)
		frames += 1
	assert_true(duck.is_queued_for_deletion(), "the duck leaves once it has crossed")
	duck.free()


func test_duck_is_behind_everything_and_has_no_physics() -> void:
	var duck: RubberDuck = RubberDuck.create(9, BOUNDS)
	autofree(duck)
	assert_lt(duck.z_index, 0)
	assert_false((duck as Node) is CollisionObject2D)
	assert_eq(duck.find_children("*", "CollisionShape2D", true, false).size(), 0)


func test_track_force_duck_replaces_the_old_one() -> void:
	var track: Track = TRACK.instantiate() as Track
	add_child_autofree(track)
	track.force_duck(1)
	track.force_duck(2)
	await get_tree().process_frame
	var ducks: int = 0
	for child: Node in track.get_children():
		if child is RubberDuck and not child.is_queued_for_deletion():
			ducks += 1
	assert_eq(ducks, 1)


func test_seeding_a_track_never_draws_from_the_race_rng() -> void:
	var track: Track = TRACK.instantiate() as Track
	add_child_autofree(track)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var state: int = rng.state
	track.seed_gimmicks(rng)
	assert_eq(rng.state, state, "a map without gimmicks draws nothing, duck or not")


func test_seed_gimmicks_puts_a_duck_on_the_map_only_for_lucky_seeds() -> void:
	var lucky: int = -1
	var unlucky: int = -1
	var probe: RandomNumberGenerator = RandomNumberGenerator.new()
	for seed_value: int in range(1, 200):
		probe.seed = seed_value
		if RubberDuck.appears(hash(probe.state)):
			lucky = seed_value if lucky < 0 else lucky
		else:
			unlucky = seed_value if unlucky < 0 else unlucky
	assert_gt(lucky, 0)
	assert_gt(unlucky, 0)
	var with_duck: Track = TRACK.instantiate() as Track
	var without_duck: Track = TRACK.instantiate() as Track
	add_child_autofree(with_duck)
	add_child_autofree(without_duck)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = lucky
	with_duck.seed_gimmicks(rng)
	rng.seed = unlucky
	without_duck.seed_gimmicks(rng)
	assert_not_null(with_duck.get_node_or_null("RubberDuck"))
	assert_null(without_duck.get_node_or_null("RubberDuck"))
