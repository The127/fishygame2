extends GutTest

var _flow: GameFlow
var _source: DebugChatSource
var _chat: Node


func before_each() -> void:
	_flow = GameFlow.new()
	_flow.lobby_seconds = 10.0
	_flow.countdown_seconds = 3
	_flow.podium_seconds = 5.0
	_flow.max_players = 3
	add_child_autofree(_flow)
	_chat = load("res://scripts/chat/chat.gd").new()
	add_child_autofree(_chat)
	_source = DebugChatSource.new()
	_chat.set_source(_source)
	_chat.command_received.connect(_flow.handle_command)


func _join(user_id: String, name_text: String) -> void:
	_source.inject(user_id, name_text, "#join")


func _results(ids: Array[int]) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for i: int in ids.size():
		results.append({"id": ids[i], "place": i + 1, "finished": true, "time": 10.0 + i})
	return results


func test_starts_idle_and_ignores_joins() -> void:
	assert_eq(_flow.state, GameFlow.State.IDLE)
	_join("1", "A")
	assert_eq(_flow.get_contestants().size(), 0)


func test_join_in_lobby_and_duplicate_ignored() -> void:
	_flow.open_lobby()
	_join("1", "Alice")
	_join("1", "Alice")
	_join("2", "Bob")
	assert_eq(_flow.get_contestants().size(), 2)
	assert_eq(_flow.get_contestants()[0].display_name, "Alice")


func test_max_players_enforced() -> void:
	_flow.open_lobby()
	watch_signals(_flow)
	for i: int in 5:
		_join(str(i), "P%d" % i)
	assert_eq(_flow.get_contestants().size(), 3)
	assert_signal_emit_count(_flow, "join_rejected", 2)


func test_colors_distinct_per_lobby() -> void:
	var seen: Array[Color] = []
	for i: int in Contestant.PALETTE.size():
		var c: Color = Contestant.color_for_slot(i)
		assert_false(seen.has(c), "slot %d repeats a color" % i)
		seen.append(c)
	_flow.open_lobby()
	_join("1", "A")
	_join("2", "B")
	assert_ne(_flow.get_contestants()[0].color, _flow.get_contestants()[1].color)


func test_manual_start_needs_players() -> void:
	_flow.open_lobby()
	assert_false(_flow.start_race())
	assert_eq(_flow.state, GameFlow.State.LOBBY)
	_join("1", "A")
	assert_true(_flow.start_race())
	assert_eq(_flow.state, GameFlow.State.COUNTDOWN)


func test_no_join_after_countdown_starts() -> void:
	_flow.open_lobby()
	_join("1", "A")
	_flow.start_race()
	_join("2", "B")
	assert_eq(_flow.get_contestants().size(), 1)


func test_lobby_timer_auto_starts() -> void:
	_flow.open_lobby()
	_join("1", "A")
	_flow.tick(9.0)
	assert_eq(_flow.state, GameFlow.State.LOBBY)
	_flow.tick(1.5)
	assert_eq(_flow.state, GameFlow.State.COUNTDOWN)


func test_lobby_timer_resets_when_empty() -> void:
	_flow.open_lobby()
	_flow.tick(11.0)
	assert_eq(_flow.state, GameFlow.State.LOBBY)
	assert_almost_eq(_flow.timer, 10.0, 0.01)


func test_manual_only_when_lobby_seconds_zero() -> void:
	_flow.lobby_seconds = 0.0
	_flow.open_lobby()
	_join("1", "A")
	_flow.tick(1000.0)
	assert_eq(_flow.state, GameFlow.State.LOBBY)


func test_countdown_ticks_then_race_starts() -> void:
	_flow.open_lobby()
	_join("1", "A")
	watch_signals(_flow)
	_flow.start_race()
	_flow.tick(1.0)
	_flow.tick(1.0)
	assert_signal_emit_count(_flow, "countdown_tick", 3)
	assert_eq(_flow.state, GameFlow.State.COUNTDOWN)
	_flow.tick(1.0)
	assert_eq(_flow.state, GameFlow.State.RACING)
	assert_signal_emitted(_flow, "race_started")


func test_race_finished_goes_to_podium_then_lobby() -> void:
	_flow.open_lobby()
	for i: int in 3:
		_join(str(i), "P%d" % i)
	_flow.start_race()
	_flow.tick(3.0)
	watch_signals(_flow)
	_flow.report_race_finished(_results([2, 0, 1]))
	assert_eq(_flow.state, GameFlow.State.PODIUM)
	var podium: Array = get_signal_parameters(_flow, "podium_ready", 0)[0]
	assert_eq(podium.size(), 3)
	assert_eq(podium[0]["name"], "P2")
	assert_eq(podium[1]["place"], 2)
	_flow.tick(5.5)
	assert_eq(_flow.state, GameFlow.State.LOBBY)
	assert_eq(_flow.get_contestants().size(), 0)


func test_podium_limited_to_top_three() -> void:
	_flow.max_players = 5
	_flow.open_lobby()
	for i: int in 5:
		_join(str(i), "P%d" % i)
	_flow.start_race()
	_flow.tick(3.0)
	watch_signals(_flow)
	_flow.report_race_finished(_results([4, 3, 2, 1, 0]))
	var podium: Array = get_signal_parameters(_flow, "podium_ready", 0)[0]
	assert_eq(podium.size(), 3)


func test_stop_returns_to_idle() -> void:
	_flow.open_lobby()
	_join("1", "A")
	_flow.stop()
	assert_eq(_flow.state, GameFlow.State.IDLE)
	assert_eq(_flow.get_contestants().size(), 0)


func test_report_ignored_outside_racing() -> void:
	_flow.open_lobby()
	_flow.report_race_finished(_results([0]))
	assert_eq(_flow.state, GameFlow.State.LOBBY)


func test_min_players_clamped_to_one() -> void:
	_flow.min_players = 0
	assert_eq(_flow.min_players, 1)
	_flow.open_lobby()
	assert_false(_flow.start_race())


func test_rejection_reasons_and_texts() -> void:
	var msg := ChatMessage.create("1", "alice", "Alice", "#join")
	assert_string_contains(GameFlow.rejection_text("full", msg), "full")
	assert_string_contains(GameFlow.rejection_text("closed", msg), "Alice")
	assert_eq(GameFlow.rejection_text("duplicate", msg), "")
	watch_signals(_flow)
	_join("1", "A")
	assert_signal_emit_count(_flow, "join_rejected", 1)


func test_full_lobby_rejects_with_full_reason() -> void:
	_flow.open_lobby()
	for i: int in 3:
		_join(str(i), "P%d" % i)
	watch_signals(_flow)
	_join("9", "Late")
	assert_eq(get_signal_parameters(_flow, "join_rejected", 0)[1], "full")


func test_min_players_clamp_values() -> void:
	_flow.min_players = -5
	assert_eq(_flow.min_players, 1)
	_flow.min_players = 2
	assert_eq(_flow.min_players, 2)
