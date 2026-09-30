extends GutTest
## Maps with several starts: how fish are dealt out and how progress reads across the routes.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const MAP: String = "fork"


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _track(id: String = MAP) -> Track:
	var track: Track = TrackCatalog.instantiate(id)
	add_child_autofree(track)
	return track


func _starts_of(track: Track, count: int) -> Array[int]:
	var result: Array[int] = []
	for i: int in count:
		result.append(track.get_start_of(i))
	return result


func _counts(starts: Array[int], start_count: int) -> Array[int]:
	var counts: Array[int] = []
	counts.resize(start_count)
	counts.fill(0)
	for start: int in starts:
		counts[start] += 1
	return counts


func test_fork_map_has_three_starts() -> void:
	assert_eq(_track().get_start_count(), 3)


func test_single_start_maps_report_one_start_and_draw_nothing() -> void:
	var track: Track = _track("zigzag")
	assert_eq(track.get_start_count(), 1)
	var rng: RandomNumberGenerator = _rng(5)
	var before: int = rng.state
	track.plan_starts(10, rng)
	assert_eq(rng.state, before, "plan_starts draws nothing on a single-start map")
	assert_eq(track.get_start_of(7), 0)


func test_fish_are_split_evenly_between_starts() -> void:
	var track: Track = _track()
	for seed_value: int in range(1, 21):
		for count: int in [1, 2, 7, 10, 20]:
			track.plan_starts(count, _rng(seed_value))
			for n: int in _counts(_starts_of(track, count), 3):
				assert_between(
					n, count / 3, (count + 2) / 3, "seed %d, %d fish" % [seed_value, count]
				)


func test_the_plan_follows_the_seed() -> void:
	var track: Track = _track()
	track.plan_starts(20, _rng(3))
	var first: Array[int] = _starts_of(track, 20)
	track.plan_starts(20, _rng(3))
	assert_eq(_starts_of(track, 20), first)
	var differs: bool = false
	for seed_value: int in range(4, 14):
		track.plan_starts(20, _rng(seed_value))
		differs = differs or _starts_of(track, 20) != first
	assert_true(differs, "other seeds deal the fish out differently")


func test_extra_fish_do_not_always_land_on_the_same_start() -> void:
	var track: Track = _track()
	var fullest: Dictionary = {}
	for seed_value: int in range(1, 31):
		track.plan_starts(10, _rng(seed_value))
		var counts: Array[int] = _counts(_starts_of(track, 10), 3)
		fullest[counts.find(counts.max())] = true
	assert_eq(fullest.size(), 3, "every start gets the extra fish sometimes")


func test_fish_spawn_at_their_own_start_without_overlapping() -> void:
	var track: Track = _track()
	track.plan_starts(20, _rng(9))
	var seen: Dictionary = {}
	for i: int in 20:
		var pos: Vector2 = track.get_spawn_position(i)
		var start: Marker2D = (
			(
				track.get_node("SpawnOrigin")
				if track.get_start_of(i) == 0
				else track.get_node("Starts").get_child(track.get_start_of(i) - 1)
			)
			as Marker2D
		)
		assert_lt(pos.distance_to(start.global_position), 220.0, "fish %d near its start" % i)
		assert_false(seen.has(pos), "fish %d has a slot of its own" % i)
		seen[pos] = true


func test_race_places_fish_by_the_plan() -> void:
	var track: Track = _track()
	var race: Race = Race.new()
	race.marble_scene = load(MARBLE_SCENE) as PackedScene
	add_child_autofree(race)
	race.start(track, 10, _rng(4))
	var marbles: Array[Marble] = race.get_marbles()
	for marble: Marble in marbles:
		assert_lt(
			marble.global_position.distance_to(track.get_spawn_position(marble.id)),
			Race.SPAWN_JITTER * 2.0,
			"marble %d" % marble.id
		)


func test_every_start_begins_at_the_bottom_of_the_progress_scale() -> void:
	var track: Track = _track()
	for start: int in 3:
		var origin: Vector2 = track.get_spawn_position(start)
		assert_lt(track.get_progress(origin), 0.06, "start %d" % start)


func test_routes_reach_the_merge_at_the_same_progress() -> void:
	var track: Track = _track()
	var merge: Vector2 = (track.get_node("Centerline") as Path2D).curve.get_point_position(0)
	for feeder: Path2D in track.get_node("Feeders").get_children():
		var end: Vector2 = feeder.curve.get_point_position(feeder.curve.point_count - 1)
		assert_eq(end, merge, "%s ends at the merge point" % feeder.name)
	assert_almost_eq(track.get_progress(merge), track.merge_progress, 0.02)


func test_progress_grows_along_every_route() -> void:
	var track: Track = _track()
	var routes: Array[Path2D] = []
	for feeder: Path2D in track.get_node("Feeders").get_children():
		routes.append(feeder)
	routes.append(track.get_node("Centerline") as Path2D)
	for route: Path2D in routes:
		var length: float = route.curve.get_baked_length()
		var last: float = -1.0
		# Skip the first and last few percent, where two routes run close together.
		for step: int in range(2, 19):
			var at: Vector2 = route.to_global(route.curve.sample_baked(length * step / 20.0))
			var progress: float = track.get_progress(at)
			assert_gt(progress, last - 0.02, "%s at %d/20" % [route.name, step])
			last = maxf(last, progress)


func test_forward_points_downstream_on_every_route() -> void:
	var track: Track = _track()
	var routes: Array[Path2D] = []
	for feeder: Path2D in track.get_node("Feeders").get_children():
		routes.append(feeder)
	routes.append(track.get_node("Centerline") as Path2D)
	for route: Path2D in routes:
		var length: float = route.curve.get_baked_length()
		var at: float = length * 0.15
		var here: Vector2 = route.curve.sample_baked(at)
		var ahead: Vector2 = route.curve.sample_baked(at + 30.0)
		var expected: Vector2 = (route.to_global(ahead) - route.to_global(here)).normalized()
		var forward: Vector2 = track.get_forward(route.to_global(here))
		assert_gt(forward.dot(expected), 0.7, route.name)


func test_finish_is_at_the_end_of_the_scale() -> void:
	var track: Track = _track()
	assert_gt(track.get_progress(track.get_finish_position()), 0.9)


func test_no_slot_overlaps_the_map() -> void:
	var track: Track = _track()
	track.plan_starts(20, _rng(9))
	await get_tree().physics_frame
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = Marble.RADIUS
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	for i: int in 20:
		query.transform = Transform2D(0.0, track.get_spawn_position(i))
		var hits: Array[Dictionary] = track.get_world_2d().direct_space_state.intersect_shape(query)
		assert_eq(hits.size(), 0, "slot of fish %d is inside the map" % i)
