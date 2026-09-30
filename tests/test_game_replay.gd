extends GameTestBase
## The finish replay in the game scene: held results, skipping, settings and cleanup.


func _configure(settings: GameSettings) -> void:
	settings.finish_replay = GameSettings.REPLAY_ALWAYS


func after_each() -> void:
	Engine.time_scale = 1.0
	super.after_each()


## Starts a race, records a few seconds of it and lets marble 0 win, then the rest follow.
func _run_race_with_clip(order: Array[int]) -> void:
	_start_race(2)
	var recorder: ReplayRecorder = _race.get_recorder()
	var t: float = -2.0
	while t < 0.0:
		recorder.sample(
			t,
			PackedVector2Array([Vector2(t * 50.0, 0.0), Vector2(t * 50.0, 40.0)]),
			PackedVector2Array([Vector2(50.0, 0.0), Vector2(50.0, 0.0)])
		)
		t += ReplayRecorder.SAMPLE_INTERVAL
	_finish_marbles(order)
	# The replay starts after a beat and a fade, outside the physics callback.
	await _wait_for_replay()


func _wait_for_replay() -> void:
	await wait_seconds(RaceSequence.REPLAY_BEAT + RaceSequence.REPLAY_FADE + 0.1)


func _replay_node() -> FinishReplay:
	for child: Node in _game.get_node("RaceSequence").get_children():
		if child is FinishReplay:
			return child as FinishReplay
	return null


func test_podium_waits_for_the_replay() -> void:
	await _run_race_with_clip([0, 1])
	assert_eq(_flow.state, GameFlow.State.RACING, "flow waits while the replay plays")
	assert_true(_replay_node().active)
	_replay_node().stop()
	assert_eq(_flow.state, GameFlow.State.PODIUM)


func test_replay_ending_reports_the_real_results() -> void:
	await _run_race_with_clip([1, 0])
	watch_signals(_flow)
	_replay_node().stop()
	assert_signal_emitted(_flow, "podium_ready")
	var podium: Array = get_signal_parameters(_flow, "podium_ready")[0]
	assert_eq(int((podium[0] as Dictionary)["id"]), 1)


func test_space_skips_the_replay_instead_of_starting() -> void:
	await _run_race_with_clip([0, 1])
	_panel.start_pressed.emit()
	assert_false(_replay_node().active)
	assert_eq(_flow.state, GameFlow.State.PODIUM)


func test_skip_button_signal_skips() -> void:
	await _run_race_with_clip([0, 1])
	_panel.skip_replay_pressed.emit()
	assert_eq(_flow.state, GameFlow.State.PODIUM)


func test_stopping_the_round_drops_the_replay_and_results() -> void:
	await _run_race_with_clip([0, 1])
	_flow.stop()
	assert_false(_replay_node().active)
	assert_eq(_flow.state, GameFlow.State.IDLE)
	assert_eq(Engine.time_scale, 1.0)
	_flow.open_lobby()
	assert_eq(_flow.state, GameFlow.State.LOBBY, "no stale results reach the new round")


func test_replay_off_goes_straight_to_the_podium() -> void:
	_game.settings.finish_replay = GameSettings.REPLAY_OFF
	await _run_race_with_clip([0, 1])
	assert_eq(_flow.state, GameFlow.State.PODIUM)
	assert_false(_replay_node().active)


func test_close_mode_skips_a_far_finish_and_plays_a_close_one() -> void:
	_game.settings.finish_replay = GameSettings.REPLAY_CLOSE
	_start_race(2)
	_race.had_photo_finish = true
	await _run_race_with_clip_from_running([0, 1])
	assert_true(_replay_node().active, "a photo finish gets a replay")


## Like _run_race_with_clip but for a race that is already running.
func _run_race_with_clip_from_running(order: Array[int]) -> void:
	var recorder: ReplayRecorder = _race.get_recorder()
	var t: float = -2.0
	while t < 0.0:
		recorder.sample(
			t,
			PackedVector2Array([Vector2(t * 50.0, 0.0), Vector2(t * 50.0, 40.0)]),
			PackedVector2Array([Vector2(50.0, 0.0), Vector2(50.0, 0.0)])
		)
		t += ReplayRecorder.SAMPLE_INTERVAL
	_finish_marbles(order)
	await _wait_for_replay()


func test_no_replay_without_a_recorded_clip() -> void:
	_start_race(2)
	_finish_marbles([0, 1])
	await get_tree().process_frame
	assert_eq(_flow.state, GameFlow.State.PODIUM, "one frame is not enough to play")


func test_stopping_during_the_replay_records_no_stats() -> void:
	await _run_race_with_clip([0, 1])
	_flow.stop()
	assert_eq(_betting.points.stats.get_counter("0", "races"), 0)


func test_stats_are_recorded_when_the_replay_ends() -> void:
	await _run_race_with_clip([0, 1])
	assert_eq(
		_betting.points.stats.get_counter("0", "races"), 0, "not yet, the race is still replaying"
	)
	_replay_node().stop()
	assert_eq(_betting.points.stats.get_counter("0", "races"), 1)


func test_replay_cuts_in_after_a_beat_not_at_once() -> void:
	_start_race(2)
	var recorder: ReplayRecorder = _race.get_recorder()
	var t: float = -2.0
	while t < 0.0:
		recorder.sample(
			t,
			PackedVector2Array([Vector2(t * 50.0, 0.0), Vector2(t * 50.0, 40.0)]),
			PackedVector2Array([Vector2(50.0, 0.0), Vector2(50.0, 0.0)])
		)
		t += ReplayRecorder.SAMPLE_INTERVAL
	_finish_marbles([0, 1])
	await wait_frames(2)
	assert_false(_replay_node().active, "the finish plays on live first")
	await _wait_for_replay()
	assert_true(_replay_node().active)


func test_leaving_the_round_during_the_beat_cancels_the_replay() -> void:
	_start_race(2)
	var recorder: ReplayRecorder = _race.get_recorder()
	recorder.sample(
		-1.0,
		PackedVector2Array([Vector2.ZERO, Vector2.ZERO]),
		PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	)
	recorder.sample(
		0.0,
		PackedVector2Array([Vector2.ZERO, Vector2.ZERO]),
		PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	)
	_finish_marbles([0, 1])
	_flow.stop()
	await _wait_for_replay()
	assert_false(_replay_node().active)


func test_leaving_the_round_during_the_fade_out_leaves_no_black_flash() -> void:
	_start_race(2)
	var recorder: ReplayRecorder = _race.get_recorder()
	recorder.sample(
		-1.0,
		PackedVector2Array([Vector2.ZERO, Vector2.ZERO]),
		PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	)
	recorder.sample(
		0.0,
		PackedVector2Array([Vector2.ZERO, Vector2.ZERO]),
		PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	)
	_finish_marbles([0, 1])
	await wait_seconds(RaceSequence.REPLAY_BEAT + RaceSequence.REPLAY_FADE * 0.5)
	_flow.stop()
	await _wait_for_replay()
	var fader: ColorRect = _game.get_node("Overlay")._fader
	assert_eq(fader.modulate.a, 0.0, "no fade back in flashes the idle screen black")
	assert_false(_replay_node().active)
