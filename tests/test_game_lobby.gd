extends GameTestBase
## Game scene: lobby, joins, countdown, race and podium.


func test_starts_in_open_lobby_without_auto_start() -> void:
	assert_eq(_flow.state, GameFlow.State.LOBBY)
	assert_eq(_flow.lobby_seconds, 0.0)
	_join(1)
	_flow.tick(10000.0)
	assert_eq(_flow.state, GameFlow.State.LOBBY)
	assert_eq(_flow.get_contestants().size(), 1)
	assert_not_null(_current_track(), "a map is loaded for the lobby")


func test_join_duplicate_is_ignored_silently() -> void:
	_say("1", "#join")
	_say("1", "#join")
	assert_eq(_flow.get_contestants().size(), 1)
	assert_eq(_source.sent.size(), 0)


func test_join_full_lobby_replies_once_per_cooldown() -> void:
	_join(4)
	_say("9", "#join")
	_say("9", "#join")
	assert_eq(_flow.get_contestants().size(), 4)
	assert_eq(_source.sent.size(), 1, "second rejection falls inside the reply cooldown")
	assert_string_contains(_source.sent[0], "full")
	_say("8", "#join")
	assert_eq(_source.sent.size(), 2, "another viewer still gets a reply")


func test_join_after_start_is_rejected_with_reply() -> void:
	_start_race(2)
	_say("9", "#join")
	assert_eq(_flow.get_contestants().size(), 2)
	assert_eq(_source.sent.size(), 1)
	assert_string_contains(_source.sent[0], "no open lobby")


func test_join_while_idle_stays_silent() -> void:
	_panel.stop_pressed.emit()
	assert_eq(_flow.state, GameFlow.State.IDLE)
	_say("1", "#join")
	assert_eq(_flow.get_contestants().size(), 0)
	assert_eq(_source.sent.size(), 0)


func test_reopen_lobby_from_idle_via_panel() -> void:
	_panel.stop_pressed.emit()
	_panel.open_lobby_pressed.emit()
	assert_eq(_flow.state, GameFlow.State.LOBBY)
	_join(1)
	assert_eq(_flow.get_contestants().size(), 1)


func test_open_lobby_ignored_while_lobby_is_open() -> void:
	_join(2)
	_panel.open_lobby_pressed.emit()
	assert_eq(_flow.get_contestants().size(), 2, "roster survives a second open press")


func test_manual_start_needs_a_player() -> void:
	_panel.start_pressed.emit()
	assert_eq(_flow.state, GameFlow.State.LOBBY)
	_join(1)
	_panel.start_pressed.emit()
	assert_eq(_flow.state, GameFlow.State.COUNTDOWN)


func test_countdown_ticks_then_race_spawns_a_marble_per_player() -> void:
	_join(3)
	watch_signals(_flow)
	_panel.start_pressed.emit()
	_flow.tick(1.0)
	_flow.tick(1.0)
	assert_signal_emit_count(_flow, "countdown_tick", 3)
	assert_eq(_race.get_marbles().size(), 0, "no marbles during the countdown")
	_flow.tick(1.0)
	assert_eq(_flow.state, GameFlow.State.RACING)
	assert_eq(_race.get_marbles().size(), 3)
	var contestants: Array[Contestant] = _flow.get_contestants()
	for i: int in 3:
		var marble: Marble = _marble(i)
		assert_eq(marble.color, contestants[i].color)
		assert_eq(marble.label_text, contestants[i].display_name)


func test_race_to_podium_then_back_to_fresh_lobby() -> void:
	_start_race(3)
	_finish_marbles([2, 0, 1])
	assert_eq(_flow.state, GameFlow.State.PODIUM)
	_flow.tick(5.5)
	assert_eq(_flow.state, GameFlow.State.LOBBY)
	assert_eq(_flow.get_contestants().size(), 0)
	assert_eq(_race.get_marbles().size(), 0, "marbles are cleared for the next round")
	_say("0", "#join")
	assert_eq(_flow.get_contestants().size(), 1, "the same viewer can join the next round")


func test_second_round_runs_like_the_first() -> void:
	_start_race(2)
	_finish_marbles([0, 1])
	_flow.tick(5.5)
	_start_race(3)
	assert_eq(_race.get_marbles().size(), 3)
	_finish_marbles([1, 0, 2])
	assert_eq(_flow.state, GameFlow.State.PODIUM)


func test_podium_signal_carries_winner() -> void:
	_join(3)
	watch_signals(_flow)
	_flow.start_race()
	_flow.tick(3.0)
	_finish_marbles([1, 2, 0])
	var podium: Array = get_signal_parameters(_flow, "podium_ready", 0)[0]
	assert_eq(podium[0]["name"], "User1")
	assert_eq(podium[0]["place"], 1)


func test_timeout_with_a_finisher_still_pays_the_winner() -> void:
	_join(3)
	_say("100", "#bet user2 100")
	_flow.start_race()
	_flow.tick(3.0)
	var track: Track = _current_track()
	track.marble_reached_finish.emit(_marble(2))
	_race.timeout_seconds = 0.0
	await wait_physics_frames(2)
	assert_eq(_flow.state, GameFlow.State.PODIUM)
	assert_eq(_balance("100"), 900 + 300)
