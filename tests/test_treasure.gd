extends GutTest
## Treasures: the seeded plan, collection by the first fish, and cleanup.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"


func _make_race(map_id: String = "zigzag", seed_value: int = 5, enabled: bool = true) -> Race:
	var track: Track = TrackCatalog.instantiate(map_id)
	add_child_autofree(track)
	var race: Race = Race.new()
	race.marble_scene = load(MARBLE_SCENE) as PackedScene
	race.treasures_enabled = enabled
	add_child_autofree(race)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	race.start(track, 3, rng)
	return race


func test_plan_is_a_pure_function_of_the_seed() -> void:
	assert_eq(Treasure.plan(42), Treasure.plan(42))
	var differs: bool = false
	for seed_value: int in range(1, 20):
		differs = differs or Treasure.plan(seed_value) != Treasure.plan(seed_value + 1)
	assert_true(differs, "different seeds give different plans")


func test_plan_has_two_to_four_spread_out_treasures() -> void:
	var counts: Dictionary = {}
	for seed_value: int in 200:
		var plan: Array[Dictionary] = Treasure.plan(seed_value)
		counts[plan.size()] = true
		assert_between(plan.size(), Treasure.MIN_COUNT, Treasure.MAX_COUNT)
		var last: float = 0.0
		for entry: Dictionary in plan:
			var progress: float = float(entry["progress"])
			assert_gt(progress, last, "sorted and apart")
			assert_between(progress, Treasure.FIRST_PROGRESS, Treasure.LAST_PROGRESS)
			last = progress
	assert_eq(counts.size(), 3, "every count from 2 to 4 shows up")


func test_values_are_small() -> void:
	for kind: int in Treasure.VALUES:
		assert_between(Treasure.value_of(kind as Treasure.Kind), 1, 50)


func test_every_map_places_treasures_on_its_route() -> void:
	for map_id: String in TrackCatalog.ids():
		var track: Track = TrackCatalog.instantiate(map_id)
		add_child_autofree(track)
		var spots: Array[Dictionary] = track.treasure_spots(7)
		assert_gte(spots.size(), Treasure.MIN_COUNT, map_id)
		assert_eq(spots, track.treasure_spots(7), "%s is deterministic" % map_id)


func test_race_places_treasures_and_does_not_advance_the_rng() -> void:
	var race: Race = _make_race()
	assert_between(race.treasures_left(), Treasure.MIN_COUNT, Treasure.MAX_COUNT)
	var with_treasures: RandomNumberGenerator = RandomNumberGenerator.new()
	var without: RandomNumberGenerator = RandomNumberGenerator.new()
	with_treasures.seed = 9
	without.seed = 9
	var track: Track = TrackCatalog.instantiate("zigzag")
	add_child_autofree(track)
	var other: Race = Race.new()
	other.marble_scene = load(MARBLE_SCENE) as PackedScene
	other.treasures_enabled = false
	add_child_autofree(other)
	other.start(track, 3, without)
	race.start(track, 3, with_treasures)
	assert_eq(with_treasures.state, without.state, "treasures draw nothing from the race rng")


func test_disabled_means_none() -> void:
	assert_eq(_make_race("zigzag", 5, false).treasures_left(), 0)


func test_the_first_fish_in_reach_takes_it() -> void:
	var race: Race = _make_race()
	var treasure: Treasure = race._treasures.treasures[0]
	var marbles: Array[Marble] = race.get_marbles()
	marbles[1].global_position = treasure.global_position + Vector2(10, 0)
	marbles[2].global_position = treasure.global_position + Vector2(-10, 0)
	var before: int = race.treasures_left()
	watch_signals(race)
	race._treasures.collect()
	assert_signal_emit_count(race, "treasure_collected", 1)
	var args: Array = get_signal_parameters(race, "treasure_collected", 0)
	assert_eq(args[0], marbles[1].id, "the lower id wins a tie")
	assert_eq(args[2], treasure.value())
	assert_eq(race.treasures_left(), before - 1)
	race._treasures.collect()
	assert_signal_emit_count(race, "treasure_collected", 1, "a treasure is taken only once")


func test_a_far_fish_takes_nothing() -> void:
	var race: Race = _make_race()
	for marble: Marble in race.get_marbles():
		marble.global_position = Vector2(-5000, -5000)
	watch_signals(race)
	race._treasures.collect()
	assert_signal_not_emitted(race, "treasure_collected")


func test_clear_removes_the_treasures() -> void:
	var race: Race = _make_race()
	race.clear()
	assert_eq(race.treasures_left(), 0)
