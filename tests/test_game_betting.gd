extends GameTestBase
## Game scene: bets, payouts and refunds across a round.


func test_bet_placed_debits_balance() -> void:
	_join(2)
	watch_signals(_betting)
	_say("100", "#bet user0 250")
	assert_signal_emit_count(_betting, "bet_placed", 1)
	assert_eq(_balance("100"), 750)
	assert_true(_betting.has_bet("100"))
	assert_eq(_betting.total_wagered(), 250)


func test_bet_rejections() -> void:
	_join(2)
	watch_signals(_betting)
	_say("100", "#bet")
	_say("100", "#bet nobody 10")
	_say("100", "#bet user0 abc")
	_say("100", "#bet user0 0")
	_say("100", "#bet user0 5000")
	var reasons: Array[String] = []
	for i: int in 5:
		reasons.append(str(get_signal_parameters(_betting, "bet_rejected", i)[1]))
	assert_eq(
		reasons, ["usage", "unknown_fish", "invalid_amount", "invalid_amount", "insufficient"]
	)
	assert_eq(_balance("100"), 1000, "rejected bets cost nothing")


func test_second_bet_same_round_rejected() -> void:
	_join(2)
	_say("100", "#bet user0 100")
	watch_signals(_betting)
	_say("100", "#bet user1 100")
	assert_eq(get_signal_parameters(_betting, "bet_rejected", 0)[1], "already_bet")
	assert_eq(_balance("100"), 900)


func test_bet_all_in() -> void:
	_join(2)
	_say("100", "#bet user0 all")
	assert_eq(_balance("100"), 0)


func test_bet_allowed_during_countdown_but_not_during_race() -> void:
	_join(2)
	_panel.start_pressed.emit()
	assert_eq(_flow.state, GameFlow.State.COUNTDOWN)
	_say("100", "#bet user0 100")
	assert_true(_betting.has_bet("100"), "countdown still takes bets")
	_flow.tick(3.0)
	watch_signals(_betting)
	_say("101", "#bet user0 100")
	assert_signal_emit_count(_betting, "bet_rejected", 1)
	assert_false(_betting.has_bet("101"))
	assert_eq(_balance("101"), 1000)


func test_bet_on_unjoined_viewer_rejected() -> void:
	_join(1)
	watch_signals(_betting)
	_say("100", "#bet user5 100")
	assert_eq(get_signal_parameters(_betting, "bet_rejected", 0)[1], "unknown_fish")


func test_winning_bet_takes_the_doubled_pool() -> void:
	_join(4)
	_say("100", "#bet user1 100")
	_say("101", "#bet user2 200")
	_flow.start_race()
	_flow.tick(3.0)
	watch_signals(_betting)
	_finish_marbles([1, 0, 2, 3])
	assert_signal_emit_count(_betting, "payouts_settled", 1)
	assert_eq(_balance("100"), 900 + 600, "pool of 300, doubled")
	assert_eq(_balance("101"), 800, "lost bets are gone")
	assert_false(_betting.has_bet("100"), "bets are cleared after settling")
	var results: Array = get_signal_parameters(_betting, "payouts_settled", 0)[0]
	assert_eq(results.size(), 2)


func test_stake_cleared_after_settlement() -> void:
	_join(2)
	_say("100", "#bet user0 100")
	_flow.start_race()
	_flow.tick(3.0)
	assert_eq(_betting.points.stake_of("100"), 100)
	_finish_marbles([0, 1])
	assert_eq(_betting.points.stake_of("100"), 0)


func test_points_command_reports_balance() -> void:
	watch_signals(_betting)
	_say("100", "#points")
	assert_signal_emit_count(_betting, "balance_reported", 1)
	assert_eq(get_signal_parameters(_betting, "balance_reported", 0)[1], 1000)


func test_payouts_persist_to_disk() -> void:
	_join(2)
	_say("100", "#bet user0 100")
	_flow.start_race()
	_flow.tick(3.0)
	_finish_marbles([0, 1])
	var reloaded := PointsStore.new(POINTS_PATH, 1000)
	assert_true(reloaded.load_from_disk())
	assert_eq(reloaded.get_balance("100"), 1000 + 100)
	assert_eq(reloaded.stake_of("100"), 0)


func test_stop_in_lobby_refunds_bets_and_clears_roster() -> void:
	_join(2)
	_say("100", "#bet user0 300")
	_panel.stop_pressed.emit()
	assert_eq(_flow.state, GameFlow.State.IDLE)
	assert_eq(_balance("100"), 1000)
	assert_eq(_flow.get_contestants().size(), 0)
	assert_false(_betting.has_bet("100"))
	assert_eq(_betting.points.stake_of("100"), 0)


func test_stop_during_countdown_refunds_bets() -> void:
	_join(2)
	_say("100", "#bet user0 300")
	_panel.start_pressed.emit()
	_panel.stop_pressed.emit()
	assert_eq(_flow.state, GameFlow.State.IDLE)
	assert_eq(_balance("100"), 1000)


func test_stop_during_race_refunds_bets_and_clears_marbles() -> void:
	_join(2)
	_say("100", "#bet user0 300")
	_flow.start_race()
	_flow.tick(3.0)
	assert_eq(_race.get_marbles().size(), 2)
	_panel.stop_pressed.emit()
	assert_eq(_flow.state, GameFlow.State.IDLE)
	assert_eq(_balance("100"), 1000)
	assert_eq(_race.get_marbles().size(), 0)
	assert_false(_race.running)


func test_race_with_no_finisher_refunds_bets() -> void:
	_join(2)
	_say("100", "#bet user0 300")
	_flow.start_race()
	_flow.tick(3.0)
	watch_signals(_betting)
	_race.timeout_seconds = 0.0
	await wait_physics_frames(2)
	assert_eq(_flow.state, GameFlow.State.PODIUM)
	assert_eq(_balance("100"), 1000, "nobody finished so the stake comes back")
	assert_signal_not_emitted(_betting, "payouts_settled")


func test_new_lobby_forgets_previous_roster_for_bets() -> void:
	_start_race(2)
	_finish_marbles([0, 1])
	_flow.tick(5.5)
	watch_signals(_betting)
	_say("100", "#bet user0 100")
	assert_eq(get_signal_parameters(_betting, "bet_rejected", 0)[1], "unknown_fish")


func test_bet_during_podium_rejected() -> void:
	_start_race(2)
	_finish_marbles([0, 1])
	watch_signals(_betting)
	_say("100", "#bet user0 100")
	assert_eq(get_signal_parameters(_betting, "bet_rejected", 0)[1], "closed")
	assert_eq(_balance("100"), 1000)
