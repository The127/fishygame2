extends GutTest


func _fill(rec: ReplayRecorder, from: float, to: float) -> void:
	var t: float = from
	while t <= to:
		var pos := PackedVector2Array([Vector2(t, 0.0), Vector2(0.0, t)])
		var vel := PackedVector2Array([Vector2(1.0, 0.0), Vector2(0.0, 1.0)])
		rec.sample(t, pos, vel)
		t += ReplayRecorder.SAMPLE_INTERVAL


func test_empty_recorder_has_no_clip() -> void:
	var rec := ReplayRecorder.new(2)
	assert_false(rec.has_clip())
	assert_eq(rec.frame_count(), 0)


func test_no_clip_without_a_winner() -> void:
	var rec := ReplayRecorder.new(2)
	_fill(rec, 0.0, 1.0)
	assert_false(rec.has_clip())


func test_ring_keeps_only_the_window_and_stays_bounded() -> void:
	var rec := ReplayRecorder.new(2)
	_fill(rec, 0.0, 30.0)
	var frames: int = rec.frame_count()
	_fill(rec, 30.0, 60.0)
	assert_eq(rec.frame_count(), frames, "buffer size is fixed")
	var window: float = ReplayRecorder.LEAD_SECONDS + ReplayRecorder.TAIL_SECONDS
	assert_true(rec.end_time() - rec.start_time() <= window + 0.1)
	assert_true(rec.start_time() > 50.0, "old frames were dropped")


func test_frames_are_chronological_and_keep_per_marble_poses() -> void:
	var rec := ReplayRecorder.new(2)
	_fill(rec, 0.0, 20.0)
	for i: int in rec.frame_count() - 1:
		assert_true(rec.frame_time(i) < rec.frame_time(i + 1))
	var t: float = rec.frame_time(5)
	assert_almost_eq(rec.position_at(5, 0).x, t, 0.001)
	assert_almost_eq(rec.position_at(5, 1).y, t, 0.001)
	assert_eq(rec.velocity_at(5, 1), Vector2(0.0, 1.0))


func test_stops_recording_after_the_tail() -> void:
	var rec := ReplayRecorder.new(2)
	_fill(rec, 0.0, 10.0)
	rec.mark_finish(10.0, 1)
	assert_true(rec.has_clip())
	assert_eq(rec.winner_id(), 1)
	assert_false(rec.is_done())
	_fill(rec, 10.0, 10.0 + ReplayRecorder.TAIL_SECONDS + 0.2)
	assert_true(rec.is_done())
	assert_false(rec.should_sample(99.0))
	var end: float = rec.end_time()
	_fill(rec, 50.0, 60.0)
	assert_eq(rec.end_time(), end, "frames after the tail are ignored")
	assert_true(rec.frame_time(0) <= 10.0 - ReplayRecorder.LEAD_SECONDS + 0.1)


func test_only_first_finish_counts() -> void:
	var rec := ReplayRecorder.new(2)
	rec.mark_finish(5.0, 0)
	rec.mark_finish(6.0, 1)
	assert_eq(rec.finish_time(), 5.0)
	assert_eq(rec.winner_id(), 0)


func test_should_sample_follows_the_interval() -> void:
	var rec := ReplayRecorder.new(1)
	assert_true(rec.should_sample(0.0))
	rec.sample(0.0, PackedVector2Array([Vector2.ZERO]), PackedVector2Array([Vector2.ZERO]))
	assert_false(rec.should_sample(ReplayRecorder.SAMPLE_INTERVAL * 0.5))
	assert_true(rec.should_sample(ReplayRecorder.SAMPLE_INTERVAL))


func test_old_events_are_pruned() -> void:
	var rec := ReplayRecorder.new(2)
	rec.add_event(0.5, 0, ReplayRecorder.Kind.BOOST, Vector2.ZERO)
	_fill(rec, 0.0, 20.0)
	rec.add_event(19.9, 1, ReplayRecorder.Kind.CURSE, Vector2.ONE)
	_fill(rec, 20.0, 20.5)
	var events: Array[Dictionary] = rec.events()
	assert_eq(events.size(), 1)
	assert_eq(int(events[0]["id"]), 1)


func test_a_frame_at_the_same_instant_replaces_the_last() -> void:
	var rec := ReplayRecorder.new(1)
	rec.sample(1.0, PackedVector2Array([Vector2(1, 0)]), PackedVector2Array([Vector2.ZERO]))
	rec.sample(1.0, PackedVector2Array([Vector2(2, 0)]), PackedVector2Array([Vector2.ZERO]))
	assert_eq(rec.frame_count(), 1)
	assert_eq(rec.position_at(0, 0), Vector2(2, 0))
