extends GutTest
## Pachinko: race progress while falling through the peg field (the follow cam chases the leader).

const FIELD_XS: Array[float] = [80.0, 500.0, 960.0, 1400.0, 1800.0]


func _track() -> Track:
	var track: Track = TrackCatalog.instantiate("pachinko")
	add_child_autofree(track)
	return track


func test_progress_in_the_field_does_not_depend_on_the_side_a_fish_is_on() -> void:
	# The first lane runs under the right half of the field. Measured against the route, a fish
	# on the right read as already on that lane, far ahead of fish at the same depth.
	var track: Track = _track()
	for y: float in [150.0, 600.0, 1000.0, 1450.0]:
		var reference: float = track.get_progress(Vector2(960.0, y))
		for x: float in FIELD_XS:
			assert_almost_eq(track.get_progress(Vector2(x, y)), reference, 0.0001, "%d,%d" % [x, y])


func test_progress_grows_with_depth_through_the_field() -> void:
	var track: Track = _track()
	for x: float in FIELD_XS:
		var last: float = -1.0
		for y: float in range(0.0, 1500.0, 50.0):
			var progress: float = track.get_progress(Vector2(x, y))
			assert_gte(progress, last, "%d,%d" % [x, y])
			last = progress


func test_a_fish_in_the_field_is_behind_one_on_the_lanes() -> void:
	var track: Track = _track()
	var deep_in_field: float = track.get_progress(Vector2(1500.0, 1400.0))
	var on_first_lane: float = track.get_progress(Vector2(1500.0, 1590.0))
	var on_second_lane: float = track.get_progress(Vector2(1300.0, 1800.0))
	assert_lt(deep_in_field, on_first_lane)
	assert_lt(on_first_lane, on_second_lane)
	assert_lt(on_second_lane, track.get_progress(track.get_finish_position()) + 0.0001)


func test_progress_does_not_jump_where_the_field_meets_the_lanes() -> void:
	var track: Track = _track()
	var above: float = track.get_progress(Vector2(960.0, track.fall_zone_bottom - 5.0))
	var below: float = track.get_progress(Vector2(960.0, track.fall_zone_bottom + 5.0))
	assert_lt(absf(below - above), 0.01)
	for x: float in FIELD_XS:
		var before: float = track.get_progress(Vector2(x, track.fall_zone_bottom - 1.0))
		var after: float = track.get_progress(Vector2(x, track.fall_zone_bottom + 1.0))
		assert_gte(after, before - 0.0001, "%d" % x)


func test_other_maps_measure_progress_above_the_frame_as_before() -> void:
	var track: Track = TrackCatalog.instantiate("fork")
	add_child_autofree(track)
	assert_eq(track.fall_zone_bottom, 0.0)
	var above: float = track.get_progress(Vector2(500.0, -100.0))
	var at_top: float = track.get_progress(Vector2(500.0, 0.0))
	assert_almost_eq(above, at_top, 0.2)
