extends GutTest


func _ids(n: int) -> Array[int]:
	var ids: Array[int] = []
	for i: int in n:
		ids.append(i)
	return ids


func _order(results: Array[Dictionary]) -> Array[int]:
	var out: Array[int] = []
	for r: Dictionary in results:
		out.append(r["id"])
	return out


func test_finish_order_assigns_places_in_arrival_order() -> void:
	var ranking: RaceRanking = RaceRanking.new(_ids(3))
	assert_eq(ranking.record_finish(2, 10.0), 1)
	assert_eq(ranking.record_finish(0, 11.5), 2)
	assert_eq(ranking.record_finish(1, 12.0), 3)
	assert_true(ranking.all_finished())
	assert_eq(_order(ranking.get_results()), [2, 0, 1] as Array[int])


func test_duplicate_and_unknown_finishes_are_ignored() -> void:
	var ranking: RaceRanking = RaceRanking.new(_ids(2))
	assert_eq(ranking.record_finish(1, 5.0), 1)
	assert_eq(ranking.record_finish(1, 6.0), 0)
	assert_eq(ranking.record_finish(99, 6.0), 0)
	assert_eq(ranking.finished_count(), 1)
	assert_false(ranking.all_finished())


func test_results_record_finish_time_and_flag() -> void:
	var ranking: RaceRanking = RaceRanking.new(_ids(2))
	ranking.record_finish(1, 7.25)
	var results: Array[Dictionary] = ranking.get_results({0: 0.4})
	assert_true(results[0]["finished"])
	assert_eq(results[0]["time"], 7.25)
	assert_false(results[1]["finished"])
	assert_eq(results[1]["time"], -1.0)
	assert_eq(results[1]["place"], 2)


func test_timeout_ranks_unfinished_by_progress() -> void:
	var ranking: RaceRanking = RaceRanking.new(_ids(4))
	ranking.record_finish(3, 20.0)
	var progress: Dictionary = {0: 0.2, 1: 0.9, 2: 0.5}
	assert_eq(_order(ranking.get_results(progress)), [3, 1, 2, 0] as Array[int])


func test_finished_marbles_always_beat_unfinished() -> void:
	var ranking: RaceRanking = RaceRanking.new(_ids(3))
	ranking.record_finish(0, 30.0)
	var progress: Dictionary = {1: 0.99, 2: 0.98}
	var results: Array[Dictionary] = ranking.get_results(progress)
	assert_eq(results[0]["id"], 0)
	assert_eq(results[1]["id"], 1)


func test_timeout_ties_broken_by_lower_id() -> void:
	var ranking: RaceRanking = RaceRanking.new(_ids(3))
	var progress: Dictionary = {0: 0.5, 1: 0.5, 2: 0.5}
	assert_eq(_order(ranking.get_results(progress)), [0, 1, 2] as Array[int])


func test_missing_progress_counts_as_zero() -> void:
	var ranking: RaceRanking = RaceRanking.new(_ids(3))
	assert_eq(_order(ranking.get_results({2: 0.1})), [2, 0, 1] as Array[int])


func test_no_finishers_all_ranked_by_progress() -> void:
	var ranking: RaceRanking = RaceRanking.new(_ids(3))
	var results: Array[Dictionary] = ranking.get_results({0: 0.1, 1: 0.3, 2: 0.2})
	assert_eq(_order(results), [1, 2, 0] as Array[int])
	for r: Dictionary in results:
		assert_false(r["finished"])


func test_track_progress_increases_along_centerline() -> void:
	var track: Track = (
		(load("res://scenes/tracks/test_track.tscn") as PackedScene).instantiate() as Track
	)
	add_child_autofree(track)
	var start: float = track.get_progress(track.get_spawn_position(0))
	var mid: float = track.get_progress(Vector2(900, 270))
	var end: float = track.get_progress(Vector2(1580, 1030))
	assert_lt(start, 0.05)
	assert_gt(mid, start)
	assert_gt(end, mid)
	assert_gt(end, 0.95)
