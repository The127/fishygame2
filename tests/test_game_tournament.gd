extends GameTestBase
## Tournaments in the game: rounds run on their own on the picked maps, the roster carries
## over, race awards add up and the final podium is paid a bonus.


func _configure(settings: GameSettings) -> void:
	settings.win_reward = 100
	settings.second_reward = 50
	settings.third_reward = 25
	settings.auto_join_seconds = 20
	settings.min_players = 1


func _board() -> TournamentBoard:
	for child: Node in _game.get_children():
		if child is TournamentBoard:
			return child as TournamentBoard
	return null


func _run_round(order: Array[int]) -> void:
	assert_eq(_flow.state, GameFlow.State.LOBBY)
	assert_true(_flow.start_race(), "round starts")
	_flow.tick(float(_flow.countdown_seconds))
	assert_eq(_flow.state, GameFlow.State.RACING)
	_finish_marbles(order)
	assert_eq(_flow.state, GameFlow.State.PODIUM)


func test_two_rounds_add_up_and_pay_the_podium_bonus() -> void:
	assert_true(_game.start_tournament(["zigzag", "zigzag"]))
	assert_true(_game._tournament.is_running())
	assert_true(_flow.auto_mode, "rounds run on their own")
	_join(3)
	var start: int = _balance("0")
	_run_round([0, 1, 2])
	assert_true(_board().is_shown())
	assert_eq(_board().lines()[0], "TOURNAMENT AFTER 1/2")
	_flow.tick(_flow.podium_seconds)
	assert_eq(_flow.state, GameFlow.State.LOBBY)
	assert_eq(_flow.get_contestants().size(), 3, "last round's racers are back in")
	_run_round([2, 0, 1])
	# 0: 100 + 50, 2: 25 + 100, 1: 50 + 25. Bonus 300 / 150 / 75.
	assert_false(_game._tournament.is_running())
	assert_eq(_balance("0"), start + 150 + 300)
	assert_eq(_balance("2"), start + 125 + 150)
	assert_eq(_balance("1"), start + 75 + 75)
	assert_eq(_board().lines()[0], "TOURNAMENT FINAL")
	assert_eq(_board().lines()[1], "1. User0  150  +300 bonus")
	assert_eq(_board().lines()[2], "2. User2  125  +150 bonus")
	assert_gte(_flow.timer, TournamentDirector.FINAL_SECONDS, "final standings stay up longer")
	assert_false(_flow.auto_mode, "auto mode goes back to the setting")
	_flow.tick(_flow.timer)
	assert_eq(_flow.state, GameFlow.State.LOBBY)
	assert_eq(_flow.get_contestants().size(), 0, "no carry-over after the tournament")
	assert_false(_board().is_shown())


func test_rounds_play_the_picked_maps() -> void:
	assert_true(_game.start_tournament(["pachinko", "zigzag", "pachinko"]))
	assert_eq(_game._map_id, "pachinko")


func test_bets_do_not_count() -> void:
	assert_true(_game.start_tournament(["zigzag", "zigzag"]))
	_join(2)
	_say("viewer", "#bet User0 100")
	_run_round([0, 1])
	_flow.tick(_flow.podium_seconds)
	_run_round([0, 1])
	var lines: PackedStringArray = _board().lines()
	assert_eq(lines.size(), 3, "only the racers stand")
	assert_eq(lines[1], "1. User0  200  +300 bonus")


func test_not_during_a_race() -> void:
	_start_race(2)
	assert_false(_game.start_tournament(["zigzag", "zigzag"]))
	assert_false(_game._tournament.is_running())


func test_invalid_round_count_is_rejected() -> void:
	assert_false(_game.start_tournament(["zigzag", "zigzag", "zigzag", "zigzag"]))
	assert_false(_game._tournament.is_running())


func test_stop_cancels_without_a_bonus() -> void:
	assert_true(_game.start_tournament(["zigzag", "zigzag"]))
	_join(2)
	var start: int = _balance("0")
	_run_round([0, 1])
	_flow.stop()
	assert_false(_game._tournament.is_running())
	assert_false(_flow.auto_mode)
	assert_eq(_balance("0"), start + 100, "only the race reward")
	assert_false(_board().is_shown())


func test_control_panel_starts_the_picked_tournament() -> void:
	_panel.set_tournament(["pachinko", "zigzag", "zigzag"])
	assert_eq(_panel.tournament_maps(), PackedStringArray(["pachinko", "zigzag", "zigzag"]))
	(_panel.get_node("Panel/Box/StartTournament") as Button).pressed.emit()
	assert_true(_game._tournament.is_running())
	assert_eq(_game._map_id, "pachinko")


func test_rival_rewards_count() -> void:
	_game.settings.rival_reward = 5
	assert_true(_game.start_tournament(["zigzag", "zigzag"]))
	_join(2)
	_say("0", "#rival User1")
	_run_round([0, 1])
	assert_eq(_game._tournament._tournament.points_of("0"), 105, "win plus rival reward")
