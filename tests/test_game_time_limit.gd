extends GameTestBase
## Game scene: the race time limit turns unfinished fish into DNFs.

var _batcher: ChatBatcher
var _overlay: Overlay


func before_each() -> void:
	await super.before_each()
	_overlay = _game.get_node("Overlay") as Overlay
	_batcher = _game._batcher


func _time_up() -> void:
	_race.elapsed = _race.time_limit
	_race._physics_process(0.1)


func test_default_limit_is_a_minute_and_reaches_the_race() -> void:
	assert_eq(GameSettings.new().race_time_limit, 60)
	assert_eq(_race.time_limit, 60.0)


func test_limit_is_clamped_and_zero_means_none() -> void:
	var settings := GameSettings.new()
	settings.set_number("race_time_limit", 100000.0)
	assert_eq(settings.race_time_limit, 90, "never above the race safety timeout")
	settings.set_number("race_time_limit", 0.0)
	assert_eq(settings.race_time_limit, 0)


func test_time_left_counts_down_and_is_off_without_a_limit() -> void:
	_start_race(2)
	_race.elapsed = 25.0
	assert_almost_eq(_race.time_left(), 35.0, 0.001)
	_race.time_limit = 0.0
	assert_eq(_race.time_left(), -1.0)


func test_time_up_ends_the_race_and_marks_unfinished_fish() -> void:
	_start_race(3)
	_finish_marbles([1])
	watch_signals(_race)
	_time_up()
	assert_false(_race.running)
	var results: Array[Dictionary] = get_signal_parameters(_race, "race_finished", 0)[0]
	assert_true(results[0]["finished"])
	assert_false(results[1]["finished"])
	assert_false(results[2]["finished"])


func test_race_continues_before_the_limit() -> void:
	_start_race(2)
	_race.elapsed = 30.0
	_race._physics_process(0.1)
	assert_true(_race.running)


func test_dnf_fish_are_off_the_podium_and_counted_in_stats() -> void:
	_start_race(3)
	_finish_marbles([2])
	_time_up()
	assert_eq(_flow.state, GameFlow.State.PODIUM)
	assert_eq(_betting.points.stats.get_counter("2", "dnfs"), 0)
	assert_eq(_betting.points.stats.get_counter("0", "dnfs"), 1)
	assert_eq(_betting.points.stats.get_counter("1", "dnfs"), 1)
	assert_eq(_betting.points.stats.get_counter("0", "races"), 1)
	assert_eq(_betting.points.stats.get_counter("2", "podiums"), 1)
	assert_eq(_betting.points.stats.get_counter("0", "podiums"), 0)
	assert_eq(_betting.points.stats.get_best_time("0", _game._map_id), 0.0)


func test_result_line_names_dnf_fish() -> void:
	_join(3)
	_batcher.flush()
	_source.sent.clear()
	_flow.start_race()
	_flow.tick(3.0)
	_finish_marbles([1])
	_time_up()
	_batcher.flush()
	assert_eq(_source.sent.size(), 1)
	assert_string_contains(_source.sent[0], "Race over: User1 won. DNF: ")
	assert_string_contains(_source.sent[0], "User0")
	assert_string_contains(_source.sent[0], "User2")


func test_nobody_finished_refunds_and_says_so() -> void:
	_join(2)
	_say("100", "#bet user0 300")
	_batcher.flush()
	_source.sent.clear()
	_flow.start_race()
	_flow.tick(3.0)
	_time_up()
	_batcher.flush()
	assert_eq(_balance("100"), 1000)
	assert_eq(_source.sent, ["Race over: time is up, nobody finished."] as Array[String])


func test_bet_on_a_dnf_fish_loses() -> void:
	_join(2)
	_say("100", "#bet user0 300")
	_say("101", "#bet user1 100")
	_flow.start_race()
	_flow.tick(3.0)
	_finish_marbles([1])
	_time_up()
	assert_eq(_balance("100"), 700)
	assert_eq(_balance("101"), 1000 - 100 + 800)


func test_dnf_text_is_shortened_after_three_names() -> void:
	var text: String = _game._result_text("A", [] as Array[Dictionary], ["b", "c", "d", "e", "f"])
	assert_eq(text, "A won. DNF: b, c, d +2 more")


func test_overlay_timer_shows_only_in_the_last_ten_seconds() -> void:
	_start_race(2)
	var panel: Control = _overlay._timer_panel
	_race.elapsed = 40.0
	_game._process(0.0)
	assert_false(panel.visible)
	_race.elapsed = 52.3
	_game._process(0.0)
	assert_true(panel.visible)
	assert_eq(_overlay._timer_label.text, "0:08")
	_race.elapsed = 59.9
	_game._process(0.0)
	assert_eq(_overlay._timer_label.text, "0:01")


func test_overlay_timer_hides_when_the_podium_shows() -> void:
	_start_race(2)
	_race.elapsed = 55.0
	_game._process(0.0)
	assert_true(_overlay._timer_panel.visible)
	_time_up()
	assert_false(_overlay._timer_panel.visible)


func test_overlay_lists_dnf_fish_under_the_podium() -> void:
	_start_race(3)
	_finish_marbles([0])
	_time_up()
	assert_true(_overlay._dnf_panel.visible)
	assert_string_contains(_overlay._dnf_label.text, "DNF: ")
	assert_string_contains(_overlay._dnf_label.text, "User1")
	assert_string_contains(_overlay._dnf_label.text, "User2")


func test_no_limit_keeps_the_race_running() -> void:
	_start_race(2)
	_race.time_limit = 0.0
	_race.elapsed = 80.0
	_race._physics_process(0.1)
	assert_true(_race.running)
