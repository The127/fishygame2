extends GutTest
## Toilet Flush: the bowl is a dressed-up whirlpool with a flush lever, a rubber duck bobs in a
## chamber of the pipe, and a real race finishes well inside the time limit.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0
## Fish are 28 px across: the duck always leaves at least this much room above the pipe floor.
const DUCK_ROOM: float = 40.0

var _track: Track


func before_each() -> void:
	_track = TrackCatalog.instantiate("flush")
	add_child_autofree(_track)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _bowl() -> FlushBowl:
	return _track.get_node("Bowl") as FlushBowl


func _duck() -> DuckBumper:
	return _track.get_node("Duck") as DuckBumper


func _polygon_bounds(body_name: String) -> Rect2:
	var collider: CollisionPolygon2D = (
		_track.get_node("%s/Collider" % body_name) as CollisionPolygon2D
	)
	var bounds: Rect2 = Rect2(collider.polygon[0], Vector2.ZERO)
	for point: Vector2 in collider.polygon:
		bounds = bounds.expand(point)
	return bounds


func test_map_has_a_bowl_a_duck_and_a_surge() -> void:
	var kinds: PackedStringArray = []
	for hazard: Hazard in _track.get_hazards():
		kinds.append(hazard.kind)
	assert_eq(kinds, PackedStringArray(["flush", "surge"]))
	assert_true(_track.get_hazards()[0] is Whirlpool, "the bowl is a whirlpool")
	assert_true(_track.get_hazards()[1] is CurrentHazard)
	assert_not_null(_duck())
	assert_eq(_track.find_children("*", "Spinner", false, false).size(), 1, "one impeller")


func test_surge_only_ever_pushes_forward() -> void:
	var surge: CurrentHazard = _track.get_hazards()[1] as CurrentHazard
	assert_eq(surge.against_chance, 0.0)


func test_lever_rests_then_follows_the_flush() -> void:
	var bowl: FlushBowl = _bowl()
	assert_almost_eq(bowl.get_lever_angle(), 0.0, 0.0001)
	bowl._surge = 1.0
	assert_almost_eq(bowl.get_lever_angle(), FlushBowl.LEVER_DOWN, 0.0001)
	bowl._surge = 0.0
	bowl.phase = Hazard.Phase.TELEGRAPH
	bowl.phase_time = bowl.telegraph_seconds * 0.5
	assert_ne(bowl.get_lever_angle(), 0.0, "the lever twitches in the warning")


func test_the_flush_spins_the_vortex_up() -> void:
	var bowl: FlushBowl = _bowl()
	var resting: float = bowl.get_strength()
	bowl._surge = 1.0
	assert_gt(bowl.get_strength(), resting)


func test_bowl_has_one_drain_and_a_short_dwell() -> void:
	assert_eq(_bowl().exit_degrees.size(), 1)
	assert_almost_eq(_bowl().exit_degrees[0], 90.0, 0.001, "the drain is at the bottom")
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	add_child_autofree(marble)
	var longest: float = 0.0
	var shortest: float = INF
	for id: int in 40:
		marble.id = id
		var needed: float = _bowl()._dwell_needed(marble)
		longest = maxf(longest, needed)
		shortest = minf(shortest, needed)
	assert_gte(shortest, FlushBowl.BOWL_MIN_DWELL)
	assert_lte(longest, FlushBowl.BOWL_MIN_DWELL + FlushBowl.BOWL_DWELL_SPREAD)
	assert_lt(longest, Whirlpool.MIN_DWELL + Whirlpool.DWELL_SPREAD, "shorter than a whirlpool")


func test_duck_stays_inside_its_chamber_and_clear_of_the_floor() -> void:
	var duck: DuckBumper = _duck()
	var left: float = _polygon_bounds("ChamberLeft").end.x
	var right: float = _polygon_bounds("ChamberRight").position.x
	var roof: float = _polygon_bounds("ChamberRoof").end.y
	var radius: float = (
		((duck.get_node("Collider") as CollisionShape2D).shape as CircleShape2D).radius
	)
	var lowest: float = -INF
	for step: int in 200:
		var at: Vector2 = duck.path_at(TAU * float(step) / 200.0)
		assert_gt(at.x - radius, left, "clear of the left wall")
		assert_lt(at.x + radius, right, "clear of the right wall")
		assert_gt(at.y - radius, roof, "under the roof")
		lowest = maxf(lowest, at.y + radius)
		# The floor under the duck, read off the first lane 1 floor segment that spans its x.
		var floor_y: float = _floor_y_under(at.x)
		assert_lt(at.y + radius, floor_y - DUCK_ROOM, "fish can always roll under the duck")
	assert_gt(lowest, 0.0)


## Top of the lane 1 floor at `x`: the highest point of the floor's colliders at that x.
func _floor_y_under(x: float) -> float:
	var best: float = INF
	for child: Node in _track.get_node("Lane1Floor").get_children():
		var collider: CollisionPolygon2D = child as CollisionPolygon2D
		if collider == null:
			continue
		var points: PackedVector2Array = collider.polygon
		# Each quad is (a.x, top a), (b.x, top b), (b.x, bottom b), (a.x, bottom a).
		if x >= points[0].x and x <= points[1].x:
			var weight: float = (x - points[0].x) / (points[1].x - points[0].x)
			best = minf(best, lerpf(points[0].y, points[1].y, weight))
	return best


func test_duck_start_comes_from_the_seed() -> void:
	var first: DuckBumper = _duck()
	first.reseed(1234)
	var phase: float = first.get_phase()
	first.reseed(1234)
	assert_eq(first.get_phase(), phase, "the same seed gives the same start")
	first.reseed(4321)
	assert_ne(first.get_phase(), phase, "another seed starts elsewhere")


func test_seeding_a_race_moves_the_duck_and_replays_the_same_way() -> void:
	_track.seed_gimmicks(_rng(5))
	var phase: float = _duck().get_phase()
	_track.seed_gimmicks(_rng(5))
	assert_eq(_duck().get_phase(), phase)
	_track.seed_gimmicks(_rng(6))
	assert_ne(_duck().get_phase(), phase, "another race starts the duck elsewhere")


func test_duck_moves_with_physics_time_only() -> void:
	var duck: DuckBumper = _duck()
	duck.reseed(10)
	var phase: float = duck.get_phase()
	for i: int in 60:
		await get_tree().physics_frame
	assert_almost_eq(duck.get_phase(), fposmod(phase + duck.speed, TAU), 0.03, "one second on")
	# The body follows its path, a physics step behind at most.
	var behind: float = duck.global_position.distance_to(duck.path_at(duck.get_phase()))
	assert_lt(behind, 3.0)
	assert_true(duck.is_in_group(Replayable.GROUP), "the duck is part of the finish replay")


func test_duck_replay_state_has_a_fixed_size_and_blends() -> void:
	var duck: DuckBumper = _duck()
	duck.sync_to_physics = false
	duck.reseed(10)
	var from: PackedFloat32Array = duck.replay_state()
	for i: int in 30:
		duck._physics_process(STEP)
	var to: PackedFloat32Array = duck.replay_state()
	assert_eq(from.size(), to.size())
	duck.replay_apply(from, to, 0.5)
	assert_almost_eq(duck.get_phase(), (from[0] + to[0]) * 0.5, 0.0001)
	assert_eq(duck.position, duck.path_at(duck.get_phase()))
	duck.replay_apply(from, to, 1.0)
	assert_eq(duck.replay_state(), to)


func test_treasure_spots_lie_in_open_water_above_a_floor() -> void:
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState2D = _track.get_world_2d().direct_space_state
	var spots: Node = _track.get_node("TreasureSpots")
	assert_gte(spots.get_child_count(), 8, "room for a spread of treasures")
	for spot: Marker2D in spots.get_children():
		var point: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
		point.position = spot.global_position
		assert_true(space.intersect_point(point).is_empty(), "%s is inside a wall" % spot.name)
		var down: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			spot.global_position, spot.global_position + Vector2(0.0, 60.0)
		)
		assert_false(space.intersect_ray(down).is_empty(), "%s floats above the floor" % spot.name)


func test_a_real_race_finishes_well_inside_the_time_limit() -> void:
	var race: Race = Race.new()
	race.marble_scene = load(MARBLE_SCENE) as PackedScene
	add_child_autofree(race)
	var results: Array = []
	race.race_finished.connect(func(list: Array[Dictionary]) -> void: results.assign(list))
	race.start(_track, 8, _rng(3), 3)
	var frames: int = 0
	while results.is_empty() and frames < 50 * 60:
		await get_tree().physics_frame
		frames += 1
	assert_eq(results.size(), 8, "the race ended")
	assert_lt(race.elapsed, 50.0)
	for result: Dictionary in results:
		assert_true(result["finished"], "every fish finished")
