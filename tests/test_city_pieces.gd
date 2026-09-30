extends GutTest
## Sunken City set pieces: bronze bells that swell and shove fish, and a flooded plaza whose slow
## current carries fish along the lane.

const MARBLE_SCENE: String = "res://scenes/marble.tscn"

var _track: Track


func before_each() -> void:
	_track = TrackCatalog.instantiate("city")
	add_child_autofree(_track)


func _bells() -> Array[PulsingBumper]:
	var bells: Array[PulsingBumper] = []
	for child: Node in _track.get_children():
		if child is PulsingBumper:
			bells.append(child as PulsingBumper)
	return bells


func _marble_at(pos: Vector2) -> Marble:
	var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
	add_child_autofree(marble)
	marble.global_position = pos
	return marble


func test_the_city_hangs_three_bells() -> void:
	assert_eq(_bells().size(), 3)


func test_bells_swell_when_they_ring() -> void:
	for bell: PulsingBumper in _bells():
		var peak: float = 0.0
		for i: int in 100:
			peak = maxf(peak, bell.scale_at(float(i) * bell.period / 100.0))
		assert_gt(peak, 1.3, "a bell swells to shove fish")


func test_the_bells_hang_clear_of_the_lanes() -> void:
	# A bell must leave room for a fish to roll under it even at full swell.
	for bell: PulsingBumper in _bells():
		var space: PhysicsDirectSpaceState2D = bell.get_world_2d().direct_space_state
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			bell.global_position, bell.global_position + Vector2(0.0, 400.0)
		)
		query.exclude = [bell.get_rid()]
		await get_tree().physics_frame
		var hit: Dictionary = space.intersect_ray(query)
		assert_false(hit.is_empty(), "a lane lies below the bell")
		var gap: float = (hit["position"] as Vector2).y - bell.global_position.y
		assert_gt(gap, 17.0 * PulsingBumper.PEAK_SCALE + 2.0 * Marble.RADIUS + 10.0)


## How far a fish dropped into the plaza travels along the lane in a second.
func _travel_through_plaza(plaza: DriftZone) -> float:
	var marble: Marble = _marble_at(plaza.global_position)
	var start: float = marble.global_position.x
	for i: int in 90:
		await get_tree().physics_frame
	var travel: float = marble.global_position.x - start
	marble.queue_free()
	return travel


func test_the_plaza_current_carries_a_fish_along_the_lane() -> void:
	var plaza: DriftZone = _track.get_node("Plaza") as DriftZone
	assert_not_null(plaza)
	await get_tree().physics_frame
	plaza.set_physics_process(false)
	var without: float = await _travel_through_plaza(plaza)
	plaza.set_physics_process(true)
	await get_tree().physics_frame
	var with_current: float = await _travel_through_plaza(plaza)
	assert_gt(with_current, without + 15.0, "the current moves the fish further")
