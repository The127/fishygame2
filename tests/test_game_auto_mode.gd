extends GameTestBase
## Auto mode: the game cycles lobby, countdown, race and podium without the streamer.


func _configure(settings: GameSettings) -> void:
	settings.auto_mode = true
	settings.auto_join_seconds = 20
	settings.min_players = 2


func test_settings_are_applied_to_the_flow() -> void:
	assert_true(_flow.auto_mode)
	assert_eq(_flow.lobby_seconds, 20.0)
	assert_eq(_flow.timer, 20.0)


func test_join_window_restarts_until_enough_players() -> void:
	_join(1)
	_flow.tick(20.0)
	assert_eq(_flow.state, GameFlow.State.LOBBY)
	assert_eq(_flow.timer, 20.0, "window restarted")
	assert_eq(_flow.get_contestants().size(), 1, "the joined player stays")


func test_full_cycle_runs_on_its_own() -> void:
	_join(2)
	_flow.tick(20.0)
	assert_eq(_flow.state, GameFlow.State.COUNTDOWN)
	_flow.tick(float(_flow.countdown_seconds))
	assert_eq(_flow.state, GameFlow.State.RACING)
	_finish_marbles([1, 0])
	assert_eq(_flow.state, GameFlow.State.PODIUM)
	_flow.tick(5.0)
	assert_eq(_flow.state, GameFlow.State.LOBBY)
	assert_eq(_flow.get_contestants().size(), 0, "fresh roster")
	assert_eq(_flow.timer, 20.0, "new join window")
	_join(2)
	_flow.tick(20.0)
	assert_eq(_flow.state, GameFlow.State.COUNTDOWN, "second round starts too")


func test_toggle_from_control_panel_applies_live_and_saves() -> void:
	_game.settings.save_path = "user://test_auto_mode.cfg"
	_panel.auto_mode_toggled.emit(false)
	assert_false(_flow.auto_mode)
	assert_eq(_flow.lobby_seconds, 0.0)
	_join(2)
	_flow.tick(10000.0)
	assert_eq(_flow.state, GameFlow.State.LOBBY, "manual again")
	_panel.auto_mode_toggled.emit(true)
	assert_eq(_flow.timer, 20.0, "fresh window when turned on")
	_flow.tick(20.0)
	assert_eq(_flow.state, GameFlow.State.COUNTDOWN, "roster kept, round starts")
	var saved := GameSettings.new("user://test_auto_mode.cfg")
	saved.load_settings()
	assert_true(saved.auto_mode)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_auto_mode.cfg"))


func test_manual_start_still_works_in_auto_mode() -> void:
	_join(2)
	assert_true(_flow.start_race())
	assert_eq(_flow.state, GameFlow.State.COUNTDOWN)


func test_panel_shows_the_setting() -> void:
	assert_true((_panel.get_node("Panel/Box/Auto") as CheckBox).button_pressed)
