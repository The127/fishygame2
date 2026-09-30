extends GutTest

const MARBLE_SCENE: String = "res://scenes/marble.tscn"

var _replay: FinishReplay


func before_each() -> void:
	_replay = FinishReplay.new()
	add_child_autofree(_replay)


func _marbles(count: int) -> Array[Marble]:
	var marbles: Array[Marble] = []
	for i: int in count:
		var marble: Marble = (load(MARBLE_SCENE) as PackedScene).instantiate() as Marble
		marble.id = i
		add_child_autofree(marble)
		marbles.append(marble)
	return marbles


## Two marbles moving right at 100 px/s, finishing at `finish` seconds.
func _recording(finish: float) -> ReplayRecorder:
	var rec := ReplayRecorder.new(2)
	var t: float = 0.0
	while t <= finish + ReplayRecorder.TAIL_SECONDS:
		rec.sample(
			t,
			PackedVector2Array([Vector2(100.0 * t, 0.0), Vector2(100.0 * t, 50.0)]),
			PackedVector2Array([Vector2(100.0, 0.0), Vector2(100.0, 0.0)])
		)
		if absf(t - finish) < ReplayRecorder.SAMPLE_INTERVAL * 0.5:
			rec.mark_finish(t, 0)
			rec.add_event(t, 0, ReplayRecorder.Kind.SPLASH, Vector2(100.0 * t, 0.0))
		t += ReplayRecorder.SAMPLE_INTERVAL
	return rec


func test_rate_is_slow_around_the_finish_and_normal_elsewhere() -> void:
	assert_eq(FinishReplay.rate_at(0.0, 10.0), 1.0)
	assert_almost_eq(FinishReplay.rate_at(10.0, 10.0), FinishReplay.SLOW_RATE, 0.0001)
	assert_eq(FinishReplay.rate_at(20.0, 10.0), 1.0)
	var mid: float = FinishReplay.rate_at(10.0 - FinishReplay.SLOW_BEFORE - 0.15, 10.0)
	assert_true(mid > FinishReplay.SLOW_RATE and mid < 1.0, "eases in")


func test_clip_is_short_enough_for_auto_mode() -> void:
	var rec := _recording(10.0)
	var seconds: float = FinishReplay.duration_of(rec.start_time(), rec.end_time(), 10.0)
	assert_true(seconds <= 8.0, "replay takes %.1f s" % seconds)
	assert_true(seconds > 2.0)


func test_is_close_uses_photo_finish_or_time_gap() -> void:
	var close: Array[Dictionary] = [
		{"finished": true, "time": 10.0},
		{"finished": true, "time": 10.3},
	]
	var far: Array[Dictionary] = [
		{"finished": true, "time": 10.0},
		{"finished": true, "time": 12.0},
	]
	var lone: Array[Dictionary] = [{"finished": true, "time": 10.0}]
	assert_true(FinishReplay.is_close(close, false))
	assert_false(FinishReplay.is_close(far, false))
	assert_true(FinishReplay.is_close(far, true))
	assert_false(FinishReplay.is_close(lone, false))


func test_start_needs_a_clip() -> void:
	assert_false(_replay.start(null, _marbles(2)))
	assert_false(_replay.start(ReplayRecorder.new(2), _marbles(2)))
	assert_false(_replay.active)


func test_plays_recorded_poses_then_ends() -> void:
	var marbles: Array[Marble] = _marbles(2)
	var rec := _recording(5.0)
	watch_signals(_replay)
	assert_true(_replay.start(rec, marbles))
	assert_true(_replay.active)
	assert_signal_emitted(_replay, "started")
	assert_true(marbles[0].replaying)
	assert_almost_eq(marbles[0].global_position.x, 100.0 * rec.start_time(), 0.5)
	var safety: int = 0
	while _replay.active and safety < 2000:
		_replay._process(1.0 / 60.0)
		safety += 1
		if _replay.active:
			assert_almost_eq(marbles[1].global_position.x, 100.0 * _replay.clock(), 1.5)
			assert_eq(marbles[1].global_position.y, 50.0)
	assert_false(_replay.active)
	assert_signal_emitted(_replay, "ended")
	assert_false(marbles[0].replaying)


func test_crossed_marbles_leave_the_position_map() -> void:
	var marbles: Array[Marble] = _marbles(2)
	var rec := _recording(5.0)
	_replay.start(rec, marbles)
	assert_eq(_replay.get_position_map().size(), 2)
	while _replay.clock() < 5.0:
		_replay._process(1.0 / 60.0)
	_replay._process(1.0 / 60.0)
	var map: Dictionary = _replay.get_position_map()
	assert_false(map.has(0))
	assert_true(map.has(1))


func test_stop_ends_right_away_once() -> void:
	var marbles: Array[Marble] = _marbles(2)
	_replay.start(_recording(5.0), marbles)
	watch_signals(_replay)
	_replay.stop()
	_replay.stop()
	assert_false(_replay.active)
	assert_signal_emit_count(_replay, "ended", 1)
	assert_false(marbles[0].replaying)


func test_marbles_go_back_to_their_real_position_after_the_replay() -> void:
	var marbles: Array[Marble] = _marbles(2)
	marbles[0].global_position = Vector2(7.0, 8.0)
	_replay.start(_recording(5.0), marbles)
	assert_ne(marbles[0].global_position, Vector2(7.0, 8.0))
	_replay.stop()
	assert_eq(marbles[0].global_position, Vector2(7.0, 8.0))


func test_leaving_the_tree_reports_nothing() -> void:
	var replay := FinishReplay.new()
	add_child(replay)
	replay.start(_recording(5.0), _marbles(2))
	watch_signals(replay)
	remove_child(replay)
	assert_signal_not_emitted(replay, "ended")
	replay.free()


func test_a_portal_jump_snaps_instead_of_sliding() -> void:
	var rec := ReplayRecorder.new(1)
	rec.sample(0.0, PackedVector2Array([Vector2.ZERO]), PackedVector2Array([Vector2.ZERO]))
	rec.sample(0.1, PackedVector2Array([Vector2(1000, 0)]), PackedVector2Array([Vector2.ZERO]))
	rec.sample(0.2, PackedVector2Array([Vector2(1000, 0)]), PackedVector2Array([Vector2.ZERO]))
	rec.mark_finish(0.2, 0)
	var marbles: Array[Marble] = _marbles(1)
	_replay.start(rec, marbles)
	_replay._process(0.03)
	assert_true(marbles[0].global_position.x < 1.0 or marbles[0].global_position.x >= 999.0)
