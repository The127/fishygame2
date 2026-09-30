extends GameTestBase
## Leaving the race scene for the home screen.


func _configure(settings: GameSettings) -> void:
	settings.auto_mode = true
	settings.auto_join_seconds = 20
	settings.min_players = 2


func before_each() -> void:
	super.before_each()
	_game.home_scene = ""


func test_home_button_in_lobby_leaves_without_asking() -> void:
	assert_eq(_flow.state, GameFlow.State.LOBBY)
	_panel.home_pressed.emit()
	assert_eq(_flow.state, GameFlow.State.IDLE)
	assert_false((_panel.get_node("Panel/Box/LeaveConfirm") as Control).visible)


func test_home_button_mid_race_asks_first_and_keeps_the_round() -> void:
	_start_race(2)
	_panel.home_pressed.emit()
	assert_eq(_flow.state, GameFlow.State.RACING, "round keeps running until confirmed")
	assert_true((_panel.get_node("Panel/Box/LeaveConfirm") as Control).visible)


func test_home_button_during_countdown_asks_first() -> void:
	_join(2)
	_flow.start_race()
	_panel.home_pressed.emit()
	assert_eq(_flow.state, GameFlow.State.COUNTDOWN)
	assert_true((_panel.get_node("Panel/Box/LeaveConfirm") as Control).visible)


func test_stay_dismisses_the_question() -> void:
	_start_race(2)
	_panel.home_pressed.emit()
	(_panel.get_node("Panel/Box/LeaveConfirm/Answers/Stay") as Button).pressed.emit()
	assert_false((_panel.get_node("Panel/Box/LeaveConfirm") as Control).visible)
	assert_eq(_flow.state, GameFlow.State.RACING)


func _press_esc() -> void:
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	_panel._unhandled_input(esc)


func test_esc_mid_race_does_nothing_and_never_goes_home() -> void:
	_start_race(2)
	_press_esc()
	assert_eq(_flow.state, GameFlow.State.RACING)
	assert_false((_panel.get_node("Panel/Box/LeaveConfirm") as Control).visible)


func test_esc_cancels_an_open_leave_question() -> void:
	_start_race(2)
	_panel.home_pressed.emit()
	_press_esc()
	assert_false((_panel.get_node("Panel/Box/LeaveConfirm") as Control).visible)
	assert_eq(_flow.state, GameFlow.State.RACING)


func test_esc_on_the_podium_returns_to_an_empty_map() -> void:
	_start_race(2)
	_finish_marbles([1, 0])
	assert_eq(_flow.state, GameFlow.State.PODIUM)
	_press_esc()
	assert_eq(_flow.state, GameFlow.State.LOBBY)
	assert_eq(_flow.get_contestants().size(), 0)


func test_esc_in_an_empty_lobby_does_nothing() -> void:
	_press_esc()
	assert_eq(_flow.state, GameFlow.State.LOBBY)


func test_confirmed_leave_refunds_bets_and_chaos_and_stops_auto_mode() -> void:
	_join(2)
	_say("100", "#bet user0 100")
	_flow.start_race()
	_flow.tick(float(_flow.countdown_seconds))
	_say("100", "#boost user1")
	assert_eq(_balance("100"), 1000 - 100 - _chaos.boost_cost)
	_panel.home_pressed.emit()
	(_panel.get_node("Panel/Box/LeaveConfirm/Answers/Leave") as Button).pressed.emit()
	assert_eq(_flow.state, GameFlow.State.IDLE)
	assert_eq(_balance("100"), 1000, "bet and chaos stake refunded")
	assert_eq(_chaos.points.stake_of("100"), 0)
	assert_false(_flow.auto_mode)
	_flow.tick(10000.0)
	assert_eq(_flow.state, GameFlow.State.IDLE, "no auto round after leaving")
	assert_true(_game.settings.auto_mode, "saved setting untouched")


func test_stay_puts_a_hidden_panel_back_out_of_sight() -> void:
	_start_race(2)
	_panel.set_open(false)
	_panel.home_pressed.emit()
	assert_true(_panel.is_open(), "question must be visible")
	(_panel.get_node("Panel/Box/LeaveConfirm/Answers/Stay") as Button).pressed.emit()
	assert_false(_panel.is_open())


func test_question_goes_away_when_the_round_ends_on_its_own() -> void:
	_start_race(2)
	_panel.home_pressed.emit()
	_finish_marbles([1, 0])
	assert_eq(_flow.state, GameFlow.State.PODIUM)
	assert_false((_panel.get_node("Panel/Box/LeaveConfirm") as Control).visible)
