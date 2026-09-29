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
	watch_signals(_panel)
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


func test_esc_key_requests_home_and_cancels_the_question() -> void:
	_start_race(2)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	_panel._unhandled_input(esc)
	assert_true((_panel.get_node("Panel/Box/LeaveConfirm") as Control).visible)
	_panel._unhandled_input(esc)
	assert_false((_panel.get_node("Panel/Box/LeaveConfirm") as Control).visible)
	assert_eq(_flow.state, GameFlow.State.RACING)


func test_confirmed_leave_refunds_bets_and_chaos_and_stops_auto_mode() -> void:
	_join(2)
	_say("100", "#bet user0 100")
	_flow.start_race()
	_flow.tick(float(_flow.countdown_seconds))
	_say("100", "#boost user1")
	assert_eq(_balance("100"), 1000 - 100 - _chaos.boost_cost)
	_panel.home_pressed.emit()
	_panel.leave_confirmed.emit()
	assert_eq(_flow.state, GameFlow.State.IDLE)
	assert_eq(_balance("100"), 1000, "bet and chaos stake refunded")
	assert_eq(_chaos.points.stake_of("100"), 0)
	assert_false(_flow.auto_mode)
	_flow.tick(10000.0)
	assert_eq(_flow.state, GameFlow.State.IDLE, "no auto round after leaving")
	assert_true(_game.settings.auto_mode, "saved setting untouched")
