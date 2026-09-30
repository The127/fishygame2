extends GameTestBase
## Game scene: #boost and #curse across a round.


func test_boost_during_race_charges_and_pushes_marble() -> void:
	_start_race(2)
	var marble: Marble = _marble(0)
	var before: int = marble.get_child_count()
	watch_signals(_chaos)
	_say("100", "#boost user0")
	assert_signal_emit_count(_chaos, "effect_applied", 1)
	assert_eq(_balance("100"), 1000 - _chaos.boost_cost)
	assert_gt(marble.get_child_count(), before, "boost adds a burst")


func test_bet_and_chaos_stakes_add_up_and_refund_on_reload() -> void:
	_join(2)
	_say("100", "#bet user0 100")
	_flow.start_race()
	_flow.tick(3.0)
	_say("100", "#boost user1")
	assert_eq(_chaos.points.stake_of("100"), 100 + _chaos.boost_cost)
	var reloaded := PointsStore.new(_chaos.points.save_path, 1000)
	assert_true(reloaded.load_from_disk())
	assert_eq(reloaded.refund_stakes(), 1)
	assert_eq(reloaded.get_balance("100"), 1000)


func test_curse_during_race_charges_and_curses_marble() -> void:
	_start_race(2)
	_say("100", "#curse user1")
	assert_eq(_balance("100"), 1000 - _chaos.curse_cost)
	assert_true(_marble(1).is_cursed())
	assert_false(_marble(0).is_cursed())


func test_chaos_rejected_outside_race() -> void:
	_join(2)
	watch_signals(_chaos)
	_say("100", "#boost user0")
	assert_eq(get_signal_parameters(_chaos, "effect_rejected", 0)[1], "closed")
	assert_eq(_balance("100"), 1000)
	_panel.start_pressed.emit()
	_say("100", "#curse user0")
	assert_eq(get_signal_parameters(_chaos, "effect_rejected", 1)[1], "closed")


func test_chaos_viewer_cooldown_and_fish_lockout() -> void:
	_start_race(3)
	watch_signals(_chaos)
	_say("100", "#boost user0")
	_say("100", "#boost user1")
	assert_eq(get_signal_parameters(_chaos, "effect_rejected", 0)[1], "cooldown")
	_say("101", "#boost user0")
	assert_eq(get_signal_parameters(_chaos, "effect_rejected", 1)[1], "fish_busy")
	_chaos.tick(_chaos.viewer_cooldown + 1.0)
	_say("100", "#boost user1")
	assert_signal_emit_count(_chaos, "effect_applied", 2)


func test_chaos_on_finished_fish_rejected() -> void:
	_start_race(3)
	_finish_marbles([0])
	watch_signals(_chaos)
	_say("100", "#boost user0")
	assert_eq(get_signal_parameters(_chaos, "effect_rejected", 0)[1], "finished")
	assert_eq(_balance("100"), 1000)


func test_chaos_insufficient_points() -> void:
	_start_race(2)
	_betting.points.set_balance("100", 50)
	watch_signals(_chaos)
	_say("100", "#boost user0")
	assert_eq(get_signal_parameters(_chaos, "effect_rejected", 0)[1], "insufficient")
	assert_eq(_balance("100"), 50)


func test_chaos_and_bets_share_one_balance() -> void:
	_join(2)
	_say("100", "#bet user0 900")
	_flow.start_race()
	_flow.tick(3.0)
	_say("100", "#boost user1")
	assert_eq(_balance("100"), 0, "1000 - 900 staked, and 100 boost cost")
	assert_same(_chaos.points, _betting.points)


func test_chaos_state_resets_between_rounds() -> void:
	_start_race(2)
	_say("100", "#boost user0")
	_finish_marbles([0, 1])
	_flow.tick(5.5)
	_start_race(2)
	watch_signals(_chaos)
	_say("100", "#boost user0")
	assert_signal_emit_count(_chaos, "effect_applied", 1)


func test_boost_after_race_over_is_closed() -> void:
	_start_race(2)
	_finish_marbles([0, 1])
	watch_signals(_chaos)
	_say("100", "#boost user0")
	assert_eq(get_signal_parameters(_chaos, "effect_rejected", 0)[1], "closed")


func test_own_fish_boost_and_curse_rejected_without_charge() -> void:
	_start_race(2)
	watch_signals(_chaos)
	_say("0", "#boost user0")
	_say("0", "#curse user0")
	assert_eq(get_signal_parameters(_chaos, "effect_rejected", 0)[1], "self_boost")
	assert_eq(get_signal_parameters(_chaos, "effect_rejected", 1)[1], "self_curse")
	assert_signal_emit_count(_chaos, "effect_applied", 0)
	assert_eq(_balance("0"), 1000)
	assert_false(_marble(0).is_cursed())


func test_own_fish_rejections_have_their_own_notice_text() -> void:
	assert_eq(ChatReplies.CHAOS_REJECTIONS["self_boost"], "you can't boost your own fish")
	assert_eq(ChatReplies.CHAOS_REJECTIONS["self_curse"], "you can't curse your own fish")
