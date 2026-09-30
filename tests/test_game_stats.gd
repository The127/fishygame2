extends GameTestBase
## Game scene: stats are recorded from the round events and "#stats" reports them.


func _stats() -> ViewerStats:
	return _betting.points.stats


func test_finished_race_counts_races_podiums_and_times() -> void:
	_start_race(4)
	_race.elapsed = 12.5
	_finish_marbles([2, 0, 1, 3])
	var map_id: String = _game._map_id
	for id: int in 4:
		assert_eq(_stats().get_counter(str(id), "races"), 1, "viewer %d raced" % id)
	assert_eq(_stats().get_counter("2", "podiums"), 1)
	assert_eq(_stats().get_counter("0", "podiums"), 1)
	assert_eq(_stats().get_counter("1", "podiums"), 1)
	assert_eq(_stats().get_counter("3", "podiums"), 0)
	assert_eq(_stats().get_best_time("3", map_id), 12.5)


func test_stats_are_saved_with_the_points() -> void:
	_start_race(2)
	_finish_marbles([0, 1])
	var reloaded := PointsStore.new(_betting.points.save_path, 1000)
	assert_true(reloaded.load_from_disk())
	assert_eq(reloaded.stats.get_counter("0", "races"), 1)
	assert_eq(reloaded.stats.get_counter("0", "podiums"), 1)


func test_unfinished_marbles_get_a_race_but_no_time_or_podium() -> void:
	_start_race(2)
	_finish_marbles([0])
	_race.timeout_seconds = 0.0
	_race._physics_process(0.1)
	assert_eq(_stats().get_counter("1", "races"), 1)
	assert_eq(_stats().get_counter("1", "podiums"), 0)
	assert_eq(_stats().get_best_time("1", _game._map_id), 0.0)


func test_aborted_round_counts_nothing() -> void:
	_start_race(2)
	_flow.stop()
	assert_eq(_stats().get_counter("0", "races"), 0)


func test_settled_bets_count_won_and_lost_with_net() -> void:
	_join(2)
	_say("100", "#bet user0 100")
	_say("101", "#bet user1 40")
	_flow.start_race()
	_flow.tick(3.0)
	_finish_marbles([0, 1])
	assert_eq(_stats().get_counter("100", "bets_won"), 1)
	assert_eq(_stats().get_bet_net("100"), 180, "pool of 140, doubled to 280, for a 100 bet")
	assert_eq(_stats().get_counter("101", "bets_lost"), 1)
	assert_eq(_stats().get_bet_net("101"), -40)


func test_free_picks_do_not_count_as_bets() -> void:
	_join(2)
	_say("100", "#pick user0")
	_say("101", "#pick user1")
	_flow.start_race()
	_flow.tick(3.0)
	_finish_marbles([0, 1])
	for id: String in ["100", "101"]:
		assert_eq(_stats().get_counter(id, "bets_won"), 0)
		assert_eq(_stats().get_counter(id, "bets_lost"), 0)
		assert_eq(_stats().get_bet_net(id), 0)


func test_refunded_bets_do_not_count() -> void:
	_join(2)
	_say("100", "#bet user0 100")
	_flow.start_race()
	_flow.tick(3.0)
	_flow.stop()
	assert_false(_stats().has_stats("100"))


func test_boosts_and_curses_count() -> void:
	_start_race(3)
	_say("100", "#boost user0")
	_say("101", "#curse user1")
	assert_eq(_stats().get_counter("100", "boosts"), 1)
	assert_eq(_stats().get_counter("101", "curses"), 1)
	assert_eq(_stats().get_counter("100", "curses"), 0)


func test_rejected_boost_does_not_count() -> void:
	_join(2)
	_say("100", "#boost user0")
	assert_false(_stats().has_stats("100"))


func test_stats_replies_with_the_callers_summary() -> void:
	_start_race(2)
	_finish_marbles([0, 1])
	_say("0", "#stats")
	assert_eq(_source.sent.size(), 1)
	assert_string_starts_with(_source.sent[0], "User0: 1 race, 1 win, 1 podium")


func test_stats_for_a_viewer_with_nothing() -> void:
	_say("9", "#stats")
	assert_eq(_source.sent.size(), 1)
	assert_string_contains(_source.sent[0], "no stats yet")


func test_stats_can_look_up_another_viewer() -> void:
	_start_race(2)
	_finish_marbles([1, 0])
	_say("0", "#stats @user1")
	assert_eq(_source.sent.size(), 1)
	assert_string_starts_with(_source.sent[0], "User1: 1 race, 1 win")


func test_stats_for_an_unknown_name() -> void:
	_say("0", "#stats @nobody")
	assert_eq(_source.sent.size(), 1)
	assert_string_contains(_source.sent[0], "No stats found")


func test_stats_cooldown_is_per_viewer() -> void:
	_say("0", "#stats")
	_say("0", "#stats")
	assert_eq(_source.sent.size(), 1)
	_say("1", "#stats")
	assert_eq(_source.sent.size(), 2)
	_game._last_stats_msec["0"] -= Game.STATS_COOLDOWN_MSEC
	_say("0", "#stats")
	assert_eq(_source.sent.size(), 3)


func test_stats_is_silent_when_replies_are_off() -> void:
	_game.settings.chat_replies = false
	_say("0", "#stats")
	assert_eq(_source.sent.size(), 0)


func test_stats_does_not_share_other_cooldowns() -> void:
	_say("0", "#help")
	_say("0", "#stats")
	assert_eq(_source.sent.size(), 2)


func test_an_eaten_fish_is_counted_and_announced() -> void:
	_start_race(3)
	var marble: Marble = _race.get_marbles()[1]
	_game._track.fish_eaten.emit(marble)
	assert_eq(_stats().get_counter("1", "eaten"), 1)
	assert_eq(_stats().get_counter("0", "eaten"), 0)
	assert_string_contains(_game._overlay._notice.text, "got eaten")
	assert_string_contains(_game._overlay._notice.text, "@" + marble.label_text)
