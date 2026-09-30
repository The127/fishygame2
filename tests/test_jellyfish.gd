extends GutTest
## The jellyfish map: drifting bumpers on seeded paths and the surge event.

const STEP: float = 1.0 / 60.0
const MARBLE_SCENE: PackedScene = preload("res://scenes/marble.tscn")


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _swarm() -> JellyHazard:
	var track: Track = TrackCatalog.instantiate("jelly")
	add_child_autofree(track)
	return track.get_hazards()[0] as JellyHazard


func _positions(swarm: JellyHazard) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for jelly: Jellyfish in swarm.get_jellies():
		result.append(jelly.target_position())
	return result


func test_map_has_a_field_of_jellyfish() -> void:
	assert_gte(_swarm().get_jellies().size(), 8)


func test_map_is_several_screens_tall_with_jellyfish_in_every_section() -> void:
	var track: Track = TrackCatalog.instantiate("jelly")
	add_child_autofree(track)
	assert_gt(track.view_bounds.size.y, 2.0 * 1080.0, "taller than two screens")
	var sections: Dictionary = {}
	for jelly: Jellyfish in (track.get_hazards()[0] as JellyHazard).get_jellies():
		assert_true(track.view_bounds.has_point(jelly.position), "jellyfish inside the bounds")
		sections[int(jelly.position.y / 600.0)] = true
	assert_gte(sections.size(), 4, "jellyfish spread over the whole height")
	var finish: Area2D = track.get_node("Finish")
	assert_gt(finish.position.y, 2000.0, "the finish is at the bottom")


func test_jellyfish_never_reach_the_walls_or_floors() -> void:
	var track: Track = TrackCatalog.instantiate("jelly")
	add_child_autofree(track)
	for jelly: Jellyfish in (track.get_hazards()[0] as JellyHazard).get_jellies():
		# Everything the bell can sweep over, with room for a fish to pass.
		var reach: Vector2 = jelly.drift + Vector2.ONE * (jelly.radius + Marble.RADIUS)
		var box: Rect2 = Rect2(jelly.position - reach, reach * 2.0)
		for body: Node in track.get_children():
			var collider: CollisionPolygon2D = (
				body.get_node_or_null("Collider") as CollisionPolygon2D
			)
			if not body is StaticBody2D or collider == null:
				continue
			var hit: Array[PackedVector2Array] = Geometry2D.intersect_polygons(
				collider.polygon,
				PackedVector2Array(
					[
						box.position,
						Vector2(box.end.x, box.position.y),
						box.end,
						Vector2(box.position.x, box.end.y)
					]
				)
			)
			assert_true(hit.is_empty(), "%s clear of %s" % [jelly.name, body.name])


func test_centerline_runs_from_top_to_the_finish() -> void:
	var track: Track = TrackCatalog.instantiate("jelly")
	add_child_autofree(track)
	var curve: Curve2D = (track.get_node("Centerline") as Path2D).curve
	var end: Vector2 = curve.get_point_position(curve.point_count - 1)
	var finish: Area2D = track.get_node("Finish")
	assert_lt(end.distance_to(finish.position), 100.0)


func test_jellyfish_stay_near_their_anchor() -> void:
	var swarm: JellyHazard = _swarm()
	swarm.reseed(3)
	for i: int in 3600:
		for jelly: Jellyfish in swarm.get_jellies():
			jelly.advance(STEP)
			assert_true(absf(jelly.target_position().x - jelly.anchor.x) <= jelly.drift.x + 0.01)
			assert_true(absf(jelly.target_position().y - jelly.anchor.y) <= jelly.drift.y + 0.01)


func test_same_seed_drifts_the_same_way() -> void:
	var first: JellyHazard = _swarm()
	var second: JellyHazard = _swarm()
	first.reseed(9)
	second.reseed(9)
	for i: int in 300:
		for jelly: Jellyfish in first.get_jellies():
			jelly.advance(STEP)
		for jelly: Jellyfish in second.get_jellies():
			jelly.advance(STEP)
	assert_eq(_positions(first), _positions(second))


func test_different_seeds_drift_differently() -> void:
	var first: JellyHazard = _swarm()
	var second: JellyHazard = _swarm()
	first.reseed(1)
	second.reseed(2)
	assert_ne(_positions(first), _positions(second))


func test_track_seeds_the_gimmick_from_the_race_rng() -> void:
	var first: Track = TrackCatalog.instantiate("jelly")
	var second: Track = TrackCatalog.instantiate("jelly")
	add_child_autofree(first)
	add_child_autofree(second)
	first.seed_gimmicks(_rng(5))
	second.seed_gimmicks(_rng(5))
	assert_eq(_positions(first.get_hazards()[0]), _positions(second.get_hazards()[0]))
	second.seed_gimmicks(_rng(6))
	assert_ne(_positions(first.get_hazards()[0]), _positions(second.get_hazards()[0]))


func test_maps_without_gimmicks_draw_nothing_from_the_rng() -> void:
	var track: Track = TrackCatalog.instantiate("zigzag")
	add_child_autofree(track)
	var rng: RandomNumberGenerator = _rng(4)
	track.seed_gimmicks(rng)
	assert_eq(rng.randi(), _rng(4).randi())


func test_marble_touching_a_jellyfish_is_kicked_away() -> void:
	var swarm: JellyHazard = _swarm()
	var jelly: Jellyfish = swarm.get_jellies()[0]
	var marble: Marble = MARBLE_SCENE.instantiate() as Marble
	add_child_autofree(marble)
	marble.global_position = jelly.global_position + Vector2(jelly.radius + 10.0, 0.0)
	marble.linear_velocity = Vector2.ZERO
	jelly._on_ring_body_entered(marble)
	await wait_physics_frames(1)
	assert_gt(marble.linear_velocity.x, 100.0)


func test_surge_speeds_the_jellyfish_up_then_settles() -> void:
	var swarm: JellyHazard = _swarm()
	swarm.arm(1, 3)
	var jelly: Jellyfish = swarm.get_jellies()[0]
	var reached: bool = false
	var spent: float = 0.0
	while swarm.phase != Hazard.Phase.ACTIVE and spent < 100.0:
		swarm._physics_process(STEP)
		spent += STEP
	assert_eq(swarm.phase, Hazard.Phase.ACTIVE)
	for i: int in 120:
		swarm._physics_process(STEP)
		reached = reached or swarm.surge_level() >= 1.0
	assert_true(reached, "the surge reaches full strength")
	assert_gt(jelly.excite, 0.9)
	assert_gt(jelly.kick_scale, 1.4)
	swarm.disarm()
	assert_eq(swarm.surge_level(), 0.0)
	assert_eq(jelly.kick_scale, 1.0)
	assert_eq(jelly.excite, 0.0)


func _marble() -> Marble:
	var marble: Marble = MARBLE_SCENE.instantiate() as Marble
	add_child_autofree(marble)
	return marble


func test_tentacles_catch_a_fish_then_release_it() -> void:
	var jelly: Jellyfish = _swarm().get_jellies()[0]
	var marble: Marble = _marble()
	assert_true(jelly.catch_marble(marble))
	assert_true(jelly.is_holding(marble))
	for i: int in int((Jellyfish.CATCH_SECONDS - 0.1) / STEP):
		jelly.advance(STEP)
	assert_true(jelly.is_holding(marble), "still held before the time is up")
	for i: int in int(0.3 / STEP):
		jelly.advance(STEP)
	assert_false(jelly.is_holding(marble))
	assert_true(jelly.is_immune(marble))


func test_a_held_fish_is_dragged_along_and_slowed() -> void:
	var jelly: Jellyfish = _swarm().get_jellies()[0]
	var marble: Marble = _marble()
	marble.global_position = jelly.global_position + Vector2(0.0, jelly.radius * 1.5)
	marble.linear_velocity = Vector2(0.0, 600.0)
	jelly.catch_marble(marble)
	for i: int in 20:
		jelly.advance(STEP)
		await wait_physics_frames(1)
	assert_lt(marble.linear_velocity.length(), 300.0)


func test_a_released_fish_is_not_caught_again_until_its_immunity_ends() -> void:
	var jelly: Jellyfish = _swarm().get_jellies()[0]
	var marble: Marble = _marble()
	jelly.catch_marble(marble)
	for i: int in int((Jellyfish.CATCH_SECONDS + 0.1) / STEP):
		jelly.advance(STEP)
	assert_false(jelly.catch_marble(marble))
	for i: int in int(Jellyfish.IMMUNE_SECONDS / STEP):
		jelly.advance(STEP)
	assert_false(jelly.is_immune(marble))
	assert_true(jelly.catch_marble(marble))


func test_a_held_fish_cannot_be_caught_twice() -> void:
	var jelly: Jellyfish = _swarm().get_jellies()[0]
	var marble: Marble = _marble()
	assert_true(jelly.catch_marble(marble))
	assert_false(jelly.catch_marble(marble))
	assert_eq(jelly.held_count(), 1)


func test_reseeding_lets_go_of_every_fish() -> void:
	var swarm: JellyHazard = _swarm()
	var jelly: Jellyfish = swarm.get_jellies()[0]
	var marble: Marble = _marble()
	jelly.catch_marble(marble)
	swarm.reseed(2)
	assert_false(jelly.is_holding(marble))
	assert_false(jelly.is_immune(marble))


func test_a_fish_freed_while_held_is_forgotten() -> void:
	var jelly: Jellyfish = _swarm().get_jellies()[0]
	var marble: Marble = _marble()
	jelly.catch_marble(marble)
	marble.free()
	jelly.advance(STEP)
	assert_eq(jelly.held_count(), 0)


func test_a_frozen_fish_is_not_held() -> void:
	var jelly: Jellyfish = _swarm().get_jellies()[0]
	var marble: Marble = _marble()
	marble.freeze = true
	assert_false(jelly.catch_marble(marble))
