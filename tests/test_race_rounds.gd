extends GutTest
## Lap counting and cuts of a round race, without any physics.

var _rounds: RaceRounds


func _ids(count: int) -> Array[int]:
	var ids: Array[int] = []
	for i: int in count:
		ids.append(i)
	return ids


func _begin(count: int, laps: int = 3) -> void:
	_rounds = RaceRounds.new(_ids(count), laps)
	for id: int in count:
		# The grid is just past the lap line.
		_rounds.update(id, 0.02)


## Takes the fish round a whole lap, back to just past the line.
func _cross(id: int) -> void:
	for fraction: float in [0.3, 0.6, 0.9, 0.97, 0.03]:
		_rounds.update(id, fraction)


func test_cut_count_is_a_third_and_never_the_last_two() -> void:
	assert_eq(RaceRounds.cut_count(20), 6)
	assert_eq(RaceRounds.cut_count(10), 3)
	assert_eq(RaceRounds.cut_count(7), 2)
	assert_eq(RaceRounds.cut_count(5), 1)
	assert_eq(RaceRounds.cut_count(3), 1)
	assert_eq(RaceRounds.cut_count(2), 0)
	assert_eq(RaceRounds.cut_count(1), 0)
	assert_eq(RaceRounds.cut_count(0), 0)


func test_a_grid_past_the_line_counts_no_lap() -> void:
	_begin(3)
	assert_eq(_rounds.laps_done(0), 0)
	assert_false(_rounds.has_finished(0))


func test_crossing_the_line_counts_a_lap_and_backing_over_it_takes_it_back() -> void:
	_begin(1)
	_rounds.update(0, 0.5)
	_rounds.update(0, 0.9)
	assert_true(_rounds.update(0, 0.03), "the jump at the end of the loop is a crossing")
	assert_eq(_rounds.laps_done(0), 1)
	assert_false(_rounds.update(0, 0.05))
	assert_false(_rounds.update(0, 0.97), "backing over the line is not a crossing forwards")
	assert_eq(_rounds.laps_done(0), 0)
	_rounds.update(0, 0.02)
	assert_eq(_rounds.laps_done(0), 1)


func test_small_moves_and_middle_of_the_loop_count_nothing() -> void:
	_begin(1)
	for fraction: float in [0.1, 0.4, 0.6, 0.8, 0.74, 0.5, 0.26, 0.1]:
		_rounds.update(0, fraction)
	assert_eq(_rounds.laps_done(0), 0)


func test_total_rises_along_the_race() -> void:
	_begin(1)
	var last: float = _rounds.total(0)
	for lap: int in 3:
		for fraction: float in [0.25, 0.5, 0.75, 0.97, 0.03]:
			_rounds.update(0, fraction)
			assert_gte(_rounds.total(0), last - 0.0001)
			last = _rounds.total(0)


func test_the_slowest_third_is_cut_when_the_rest_have_crossed() -> void:
	_begin(10)
	var racing: Array[int] = _ids(10)
	for id: int in 7:
		assert_eq(_rounds.take_cut(racing), [] as Array[int], "not yet, %d through" % id)
		_cross(id)
	assert_eq(_rounds.take_cut(racing), [7, 8, 9] as Array[int])
	assert_true(_rounds.is_cut(8))
	assert_eq(_rounds.cut_round(8), 1)
	assert_false(_rounds.is_cut(0))
	assert_eq(_rounds.cut_round(0), 0)


func test_a_second_cut_follows_the_second_lap_and_the_last_lap_has_none() -> void:
	_begin(10)
	var racing: Array[int] = _ids(10)
	for id: int in 7:
		_cross(id)
	var first: Array[int] = _rounds.take_cut(racing)
	assert_eq(first.size(), 3)
	racing = [0, 1, 2, 3, 4, 5, 6] as Array[int]
	assert_eq(_rounds.next_round(), 2)
	for id: int in 4:
		_cross(id)
		assert_eq(_rounds.take_cut(racing), [] as Array[int])
	_cross(4)
	assert_eq(
		_rounds.take_cut(racing), [5, 6] as Array[int], "a third of seven is two, five carry on"
	)
	assert_eq(_rounds.next_round(), 0, "nothing is cut on the last lap")
	for id: int in 5:
		assert_false(_rounds.has_finished(id))
		_cross(id)
		assert_true(_rounds.has_finished(id))
	assert_eq(_rounds.take_cut([0, 1, 2, 3, 4] as Array[int]), [] as Array[int])


func test_fish_that_cross_together_are_cut_together_only_if_behind() -> void:
	_begin(6)
	var racing: Array[int] = _ids(6)
	for id: int in 6:
		if id != 5:
			_cross(id)
	# Five crossed in one frame: the four needed are far exceeded, only the one behind is cut.
	assert_eq(_rounds.take_cut(racing), [5] as Array[int])


func test_no_one_is_cut_from_two_fish() -> void:
	_begin(2)
	_cross(0)
	assert_eq(_rounds.take_cut(_ids(2)), [] as Array[int])
	assert_eq(_rounds.next_round(), 1, "the round stays open")


func test_one_lap_is_a_plain_race() -> void:
	_begin(10, 1)
	assert_eq(_rounds.next_round(), 0)
	_cross(0)
	assert_true(_rounds.has_finished(0))
	assert_eq(_rounds.take_cut(_ids(10)), [] as Array[int])


func test_a_cut_fish_keeps_its_total() -> void:
	_begin(3)
	_rounds.update(2, 0.6)
	_cross(0)
	_cross(1)
	var cut: Array[int] = _rounds.take_cut(_ids(3))
	assert_eq(cut, [2] as Array[int])
	var before: float = _rounds.total(2)
	assert_almost_eq(before, 0.6, 0.0001)
	assert_lt(before, _rounds.total(0))
