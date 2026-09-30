extends GutTest
## Hazard scheduling, the event phases and what each map's hazard does.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"
const STEP: float = 1.0 / 60.0


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _track(id: String) -> Track:
	var track: Track = TrackCatalog.instantiate(id)
	add_child_autofree(track)
	return track


## Steps the hazard until it reaches `phase`, up to `limit` seconds. Returns whether it did.
func _run_until(hazard: Hazard, phase: Hazard.Phase, limit: float = 100.0) -> bool:
	var spent: float = 0.0
	while hazard.phase != phase and spent < limit:
		hazard.tick(STEP)
		spent += STEP
	return hazard.phase == phase


func test_every_map_has_a_hazard() -> void:
	for id: String in TrackCatalog.ids():
		assert_gte(_track(id).get_hazards().size(), 1, "%s has a hazard" % id)


func test_frequency_zero_arms_nothing() -> void:
	var track: Track = _track("zigzag")
	track.arm_hazards(_rng(1), 0)
	assert_false(track.get_hazards()[0].is_armed())


func test_same_seed_plans_the_same_events() -> void:
	for id: String in TrackCatalog.ids():
		var first: Track = _track(id)
		var second: Track = _track(id)
		first.arm_hazards(_rng(7), 3)
		second.arm_hazards(_rng(7), 3)
		var plan: Array[float] = first.get_hazards()[0].get_schedule()
		assert_false(plan.is_empty(), "%s plans events" % id)
		assert_eq(plan, second.get_hazards()[0].get_schedule())


func test_different_seeds_plan_different_events() -> void:
	var first: Track = _track("zigzag")
	var second: Track = _track("zigzag")
	first.arm_hazards(_rng(1), 3)
	second.arm_hazards(_rng(2), 3)
	assert_ne(first.get_hazards()[0].get_schedule(), second.get_hazards()[0].get_schedule())


func test_higher_frequency_plans_more_events() -> void:
	var rare: int = 0
	var often: int = 0
	for seed_value: int in range(1, 11):
		var track: Track = _track("zigzag")
		track.arm_hazards(_rng(seed_value), 1)
		rare += track.get_hazards()[0].get_schedule().size()
		track.arm_hazards(_rng(seed_value), 5)
		often += track.get_hazards()[0].get_schedule().size()
	assert_gt(often, rare)


func test_no_more_events_than_the_cap() -> void:
	for id: String in TrackCatalog.ids():
		var track: Track = _track(id)
		track.arm_hazards(_rng(9), 5)
		assert_lte(track.get_hazards()[0].get_schedule().size(), Hazard.MAX_EVENTS, id)


func test_events_start_late_enough_and_never_overlap() -> void:
	for id: String in TrackCatalog.ids():
		var track: Track = _track(id)
		track.arm_hazards(_rng(5), 5)
		var hazard: Hazard = track.get_hazards()[0]
		var plan: Array[float] = hazard.get_schedule()
		assert_gte(plan[0], Hazard.FIRST_EVENT_MIN, id)
		for i: int in range(1, plan.size()):
			assert_gt(plan[i] - plan[i - 1], hazard.event_seconds(), "%s event %d" % [id, i])


func test_an_event_runs_telegraph_then_active_then_idle() -> void:
	var track: Track = _track("zigzag")
	watch_signals(track)
	track.arm_hazards(_rng(3), 3)
	var hazard: Hazard = track.get_hazards()[0]
	assert_eq(hazard.phase, Hazard.Phase.IDLE)
	assert_true(_run_until(hazard, Hazard.Phase.TELEGRAPH))
	assert_signal_emitted_with_parameters(track, "hazard_started", ["current"])
	assert_true(_run_until(hazard, Hazard.Phase.ACTIVE))
	assert_true(_run_until(hazard, Hazard.Phase.IDLE))


func test_telegraph_lasts_as_long_as_configured() -> void:
	var track: Track = _track("zigzag")
	track.arm_hazards(_rng(3), 3)
	var hazard: Hazard = track.get_hazards()[0]
	_run_until(hazard, Hazard.Phase.TELEGRAPH)
	var before: float = hazard.clock
	_run_until(hazard, Hazard.Phase.ACTIVE)
	assert_almost_eq(hazard.clock - before, hazard.telegraph_seconds, 2.0 * STEP)


func test_disarm_ends_the_event_and_forgets_the_plan() -> void:
	var track: Track = _track("wreck")
	track.arm_hazards(_rng(3), 3)
	var hazard: Hazard = track.get_hazards()[0]
	_run_until(hazard, Hazard.Phase.ACTIVE)
	await wait_physics_frames(20)
	track.stop_hazards()
	assert_eq(hazard.phase, Hazard.Phase.IDLE)
	assert_false(hazard.is_armed())
	assert_true(hazard.get_schedule().is_empty())
	# Planks are put back on the next physics frame.
	await wait_physics_frames(2)
	for plank: Node in hazard.get_children():
		if plank is AnimatableBody2D:
			assert_eq((plank as AnimatableBody2D).rotation, 0.0)


func test_current_pushes_marbles_in_its_zone() -> void:
	var track: Track = _track("zigzag")
	var hazard: CurrentHazard = track.get_hazards()[0] as CurrentHazard
	track.arm_hazards(_rng(3), 3)
	_run_until(hazard, Hazard.Phase.ACTIVE)
	var direction: Vector2 = hazard.get_direction()
	assert_almost_eq(direction.length(), 1.0, 0.001)
	var zone: Area2D = hazard._zone
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	marble.gravity_scale = 0.0
	add_child_autofree(marble)
	marble.global_position = zone.global_position
	# The zone only reports the marble after a physics frame.
	await wait_physics_frames(3)
	# Physics frames also tick the hazard itself, so the event may have moved on: only
	# the direction of any push matters here.
	assert_gt(marble.linear_velocity.dot(direction), 0.0, "pushed along the current")


func test_eel_is_parked_away_from_the_map_until_its_run() -> void:
	var track: Track = _track("pachinko")
	var hazard: EelHazard = track.get_hazards()[0] as EelHazard
	track.arm_hazards(_rng(3), 3)
	assert_eq(hazard._area.position, EelHazard.PARKED)
	_run_until(hazard, Hazard.Phase.TELEGRAPH)
	assert_eq(hazard._area.position, EelHazard.PARKED, "only a shadow while telegraphing")
	_run_until(hazard, Hazard.Phase.ACTIVE)
	var start: Vector2 = hazard._area.position
	assert_ne(start, EelHazard.PARKED)
	hazard.tick(0.5)
	assert_gt(hazard._area.position.distance_to(start), 1.0, "the eel swims")
	_run_until(hazard, Hazard.Phase.IDLE)
	assert_eq(hazard._area.position, EelHazard.PARKED)


func test_eel_shoves_marbles_along_its_route() -> void:
	var track: Track = _track("pachinko")
	var hazard: EelHazard = track.get_hazards()[0] as EelHazard
	track.arm_hazards(_rng(3), 3)
	_run_until(hazard, Hazard.Phase.ACTIVE)
	var along: Vector2 = Vector2.from_angle(hazard._angle)
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	marble.gravity_scale = 0.0
	add_child_autofree(marble)
	marble.global_position = hazard._area.global_position
	await wait_physics_frames(3)
	assert_gt(marble.linear_velocity.dot(along), 50.0, "shoved the way the eel swims")


func test_eel_run_length_fits_the_planned_event_time() -> void:
	var track: Track = _track("pachinko")
	var hazard: EelHazard = track.get_hazards()[0] as EelHazard
	for seed_value: int in range(1, 6):
		track.arm_hazards(_rng(seed_value), 3)
		_run_until(hazard, Hazard.Phase.TELEGRAPH)
		assert_lte(hazard.telegraph_seconds + hazard.active_seconds, hazard.event_seconds() + 0.001)


func test_plank_swings_down_then_closes() -> void:
	var track: Track = _track("wreck")
	var hazard: PlankHazard = track.get_hazards()[0] as PlankHazard
	track.arm_hazards(_rng(3), 3)
	_run_until(hazard, Hazard.Phase.ACTIVE)
	var plank: AnimatableBody2D = hazard._plank
	# A body only takes a new transform inside physics frames, which also tick the hazard.
	await wait_physics_frames(45)
	assert_almost_eq(absf(plank.rotation), hazard.open_angle(plank), 0.01, "fully open")
	# The free end is lower than the hinge while open.
	var free_end: Vector2 = plank.to_global((plank.get_node("Visual") as Polygon2D).polygon[0])
	assert_gt(free_end.y, plank.global_position.y + 30.0)
	_run_until(hazard, Hazard.Phase.IDLE)
	await wait_physics_frames(2)
	assert_eq(plank.rotation, 0.0, "shut again")


func test_wreck_has_at_least_three_trapdoors_that_break_often() -> void:
	var track: Track = _track("wreck")
	var hazard: PlankHazard = track.get_hazards()[0] as PlankHazard
	var planks: int = 0
	for child: Node in hazard.get_children():
		if child is AnimatableBody2D:
			planks += 1
	assert_gte(planks, 3)
	for seed_value: int in range(1, 9):
		track.arm_hazards(_rng(seed_value), 3)
		assert_gte(hazard.get_schedule().size(), 4, "seed %d" % seed_value)


func test_a_trapdoor_never_breaks_twice_in_a_row() -> void:
	var track: Track = _track("wreck")
	var hazard: PlankHazard = track.get_hazards()[0] as PlankHazard
	for seed_value: int in range(1, 13):
		track.arm_hazards(_rng(seed_value), 5)
		var last: AnimatableBody2D = null
		for i: int in hazard.get_schedule().size():
			assert_true(_run_until(hazard, Hazard.Phase.TELEGRAPH))
			assert_ne(hazard._plank, last, "seed %d event %d" % [seed_value, i])
			last = hazard._plank
			assert_true(_run_until(hazard, Hazard.Phase.IDLE))


func test_open_planks_stay_clear_of_the_decks_below() -> void:
	var track: Track = _track("wreck")
	var hazard: PlankHazard = track.get_hazards()[0] as PlankHazard
	# Room for a marble to roll past under the plank, with some to spare.
	var room: float = 2.0 * Marble.RADIUS + 15.0
	for child: Node in hazard.get_children():
		if not child is AnimatableBody2D:
			continue
		var plank: AnimatableBody2D = child as AnimatableBody2D
		var rest: Transform2D = Transform2D(0.0, plank.position)
		var shut: PackedVector2Array = rest * (plank.get_node("Visual") as Polygon2D).polygon
		var sign_of: float = 1.0 if hazard._centroid(plank).x > 0.0 else -1.0
		var open: Transform2D = Transform2D(sign_of * hazard.open_angle(plank), plank.position)
		var outline: PackedVector2Array = open * (plank.get_node("Visual") as Polygon2D).polygon
		for body: Node in track.get_children():
			var collider: CollisionPolygon2D = (
				body.get_node_or_null("Collider") as CollisionPolygon2D
			)
			if not body is StaticBody2D or collider == null:
				continue
			# The decks the plank sits between are meant to touch it.
			if (
				not Geometry2D.offset_polygon(shut, 2.0).is_empty()
				and not (
					Geometry2D
					. intersect_polygons(Geometry2D.offset_polygon(shut, 2.0)[0], collider.polygon)
					. is_empty()
				)
			):
				continue
			for grown: PackedVector2Array in Geometry2D.offset_polygon(outline, room):
				var hit: Array[PackedVector2Array] = Geometry2D.intersect_polygons(
					grown, collider.polygon
				)
				assert_true(hit.is_empty(), "%s open is too close to %s" % [plank.name, body.name])
