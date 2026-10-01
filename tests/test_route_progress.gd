extends GutTest
## Race progress must follow a fish along the zigzag maps. It is the nearest point on the
## centerline, which read a fish dropping from one ramp to the next, or thrown up off a ramp by a
## vent, as being on the other leg, and the follow cam hopped between fish.

const MAX_STEP: float = 0.05


func _track(map_id: String) -> Track:
	var track: Track = TrackCatalog.instantiate(map_id)
	add_child_autofree(track)
	return track


## Largest change in progress between neighbouring samples along the path, and the smallest
## change (negative when progress went backwards).
func _walk(track: Track, path: Array[Vector2]) -> Vector2:
	var biggest: float = 0.0
	var smallest: float = 0.0
	var last: float = track.get_progress(path[0])
	for i: int in range(1, path.size()):
		var steps: int = 60
		for s: int in range(1, steps + 1):
			var now: float = track.get_progress(path[i - 1].lerp(path[i], float(s) / steps))
			biggest = maxf(biggest, now - last)
			smallest = minf(smallest, now - last)
			last = now
	return Vector2(biggest, smallest)


func _assert_smooth(map_id: String, path: Array[Vector2]) -> void:
	var track: Track = _track(map_id)
	var steps: Vector2 = _walk(track, path)
	assert_lt(steps.x, MAX_STEP, "%s: progress jumped forward" % map_id)
	assert_gt(steps.y, -MAX_STEP, "%s: progress jumped back" % map_id)
	assert_gt(track.get_progress(path[path.size() - 1]), 0.9, "%s: reaches the end" % map_id)


func test_kraken_progress_is_smooth_down_the_ramps_and_drops() -> void:
	var path: Array[Vector2] = [
		Vector2(40, 120),
		Vector2(1400, 300),
		Vector2(1450, 360),
		Vector2(1500, 440),
		Vector2(1500, 550),
		Vector2(520, 680),
		Vector2(490, 760),
		Vector2(480, 820),
		Vector2(1300, 930),
		Vector2(1600, 1000),
	]
	_assert_smooth("kraken", path)


func test_vents_progress_is_smooth_down_the_ramps_and_drops() -> void:
	var path: Array[Vector2] = [
		Vector2(40, 100),
		Vector2(1560, 330),
		Vector2(1600, 420),
		Vector2(1600, 510),
		Vector2(330, 710),
		Vector2(315, 800),
		Vector2(310, 850),
		Vector2(1300, 965),
		Vector2(1600, 1005),
	]
	_assert_smooth("vents", path)


func test_vents_fish_thrown_up_off_the_last_ramp_stay_on_it() -> void:
	# A vent throws a fish up to about y 735, between the middle ramp and the last one.
	var track: Track = _track("vents")
	var path: Array[Vector2] = [Vector2(900, 925), Vector2(900, 690)]
	var steps: Vector2 = _walk(track, path)
	assert_lt(absf(steps.x), MAX_STEP, "no jump on the way up")
	assert_gt(steps.y, -MAX_STEP, "no jump on the way up")
	assert_gt(track.get_progress(Vector2(900, 735)), 0.7, "still on the last ramp")


func test_wreck_progress_is_smooth_down_the_drop_from_the_upper_deck() -> void:
	var path: Array[Vector2] = [
		Vector2(950, 285),
		Vector2(1340, 330),
		Vector2(1420, 400),
		Vector2(1450, 520),
		Vector2(1430, 640),
		Vector2(1152, 680),
	]
	var steps: Vector2 = _walk(_track("wreck"), path)
	assert_lt(steps.x, MAX_STEP, "no jump on the way down")
	assert_gt(steps.y, -MAX_STEP, "no jump on the way down")


func test_cave_progress_depends_on_depth_across_the_whole_maze() -> void:
	# The route is a thin line down the left, so across the maze the nearest point on it flipped
	# between its top and its bottom.
	var track: Track = _track("cave")
	var last: float = 0.0
	for y: int in range(180, 960, 40):
		var left: float = track.get_progress(Vector2(100, y))
		for x: int in range(300, 1800, 300):
			assert_almost_eq(track.get_progress(Vector2(x, y)), left, 0.0001, "(%d, %d)" % [x, y])
		assert_gt(left, last, "deeper is further on at y %d" % y)
		last = left
	assert_lt(track.get_progress(Vector2(900, 170)), track.get_progress(Vector2(900, 180)) + 0.01)


func test_jelly_progress_depends_on_depth_below_the_first_ramp() -> void:
	# Under the ramp the nearest route point flipped between the ramp and the first drop.
	var track: Track = _track("jelly")
	var steps: Vector2 = _walk(
		track, [Vector2(100, 700), Vector2(400, 790), Vector2(780, 930), Vector2(960, 1100)]
	)
	assert_lt(steps.x, MAX_STEP, "no jump rolling down the first floor")
	assert_gt(steps.y, -MAX_STEP, "no jump rolling down the first floor")
	assert_almost_eq(
		track.get_progress(Vector2(400, 800)), track.get_progress(Vector2(1500, 800)), 0.0001
	)
