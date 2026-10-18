extends GutTest
## The lurkers' shadows on a map: where they hide and how many show.


func _watchers(count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i: int in count:
		(
			result
			. append(
				{
					"user_id": str(i),
					"eyes": LurkerEyes.STYLES[i % LurkerEyes.STYLES.size()],
					"species": i,
				}
			)
		)
	return result


func _track(id: String) -> Track:
	var track: Track = TrackCatalog.instantiate(id)
	add_child_autofree(track)
	return track


func test_every_map_has_spots_clear_of_walls_and_off_the_route() -> void:
	for id: String in TrackCatalog.ids():
		var track: Track = _track(id)
		await wait_physics_frames(2)
		var spots: Array[Vector2] = LurkerSpots.find(track, id)
		assert_gt(spots.size(), 4, "%s has spots" % id)
		assert_lte(spots.size(), LurkerSpots.MAX_SPOTS)
		for spot: Vector2 in spots:
			assert_true(track.view_bounds.has_point(spot), "%s spot in view" % id)
			assert_gte(
				track.distance_to_route(spot), LurkerSpots.NEAR, "%s spot off the route" % id
			)
		assert_eq(spots, LurkerSpots.find(track, id), "%s spots stay put" % id)
		track.free()


func test_den_shows_one_shadow_per_lurker() -> void:
	var track: Track = _track("zigzag")
	var den := LurkerDen.new("zigzag")
	track.add_child(den)
	den.set_watchers(_watchers(3))
	await wait_physics_frames(2)
	assert_eq(den.shown_count(), 3)
	den.set_watchers(_watchers(1))
	assert_eq(den.shown_count(), 1)
	den.set_watchers(_watchers(40))
	assert_eq(den.shown_count(), LurkerSpots.MAX_SPOTS, "no more than the map has spots")
	den.set_watchers([])
	assert_eq(den.shown_count(), 0)


func test_eyes_follow_the_nearest_fish() -> void:
	var track: Track = _track("zigzag")
	var den := LurkerDen.new("zigzag")
	track.add_child(den)
	den.set_watchers(_watchers(1))
	await wait_physics_frames(2)
	var spot: Vector2 = den._shown[0]["spot"]
	den.fish_positions = func() -> Dictionary:
		return {0: spot + Vector2(-300, 0), 1: spot + Vector2(80, 0)}
	await wait_frames(30)
	assert_gt((den._shown[0]["look"] as Vector2).x, 0.5, "looks at the closer fish on the right")


func test_each_map_hides_lurkers_in_its_own_thing() -> void:
	assert_eq(LurkerSpots.hideout_of("wreck"), LurkerSpots.Hideout.PORTHOLE)
	assert_eq(LurkerSpots.hideout_of("sushi"), LurkerSpots.Hideout.CURTAIN)
	assert_eq(LurkerSpots.hideout_of("claw"), LurkerSpots.Hideout.GLASS)
	assert_eq(LurkerSpots.hideout_of("abyss"), LurkerSpots.Hideout.DARK)
	assert_eq(LurkerSpots.hideout_of("zigzag"), LurkerSpots.Hideout.KELP)
