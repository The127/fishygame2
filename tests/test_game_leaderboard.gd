extends GameTestBase
## Game scene: "#top" chat command, win tracking and the lobby board.


func _win_round() -> void:
	_start_race(2)
	_finish_marbles([1, 0] as Array[int])


func test_top_replies_with_leaders() -> void:
	_join(2)
	_say("0", "#bet user1 300")
	_say("1", "#bet user1 100")
	_say("2", "#top")
	assert_eq(_source.sent.size(), 1)
	assert_string_contains(_source.sent[0], "Top 2:")
	assert_string_contains(_source.sent[0], "1. User1 900")


func test_top_is_rate_limited_for_everyone() -> void:
	_say("0", "#top")
	_say("1", "#top")
	assert_eq(_source.sent.size(), 1)
	_game._last_top_msec -= Game.TOP_COOLDOWN_MSEC
	_say("1", "#top")
	assert_eq(_source.sent.size(), 2)


func test_top_with_no_scores_says_so() -> void:
	_say("0", "#top")
	assert_string_contains(_source.sent[0], "No scores yet")


func test_winner_gets_a_win_and_name() -> void:
	_win_round()
	assert_eq(_betting.points.get_wins("1"), 1)
	assert_eq(_betting.points.get_wins("0"), 0)
	assert_eq(_betting.points.get_name("1"), "User1")
	var top: Array[Dictionary] = _betting.points.top_by_wins(5)
	assert_eq(top.size(), 1)


func test_wins_survive_a_restart() -> void:
	_win_round()
	var reloaded := PointsStore.new(POINTS_PATH, 1000)
	reloaded.load_from_disk()
	assert_eq(reloaded.get_wins("1"), 1)


func test_board_shows_in_the_next_lobby() -> void:
	_win_round()
	var overlay: Overlay = _game.get_node("Overlay") as Overlay
	_flow.tick(_flow.podium_seconds)
	assert_eq(_flow.state, GameFlow.State.LOBBY)
	assert_true(overlay._board_has_rows)
