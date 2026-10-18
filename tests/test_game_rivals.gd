extends GameTestBase
## Game scene: "#rival" replies, the reward at the end of a race and the result line.


func _configure(settings: GameSettings) -> void:
	settings.rival_reward = 5


func test_rival_is_confirmed_in_chat() -> void:
	_join(2)
	_say("0", "#rival User1")
	_game._batcher.flush()
	assert_has(_source.sent, "Rivals: @User0 vs @User1")


func test_rival_toggle_silences_the_confirmation() -> void:
	_game.settings.reply_rivals = false
	_join(2)
	_game._batcher.flush()
	_source.sent.clear()
	_say("0", "#rival User1")
	_game._batcher.flush()
	assert_eq(_source.sent.size(), 0)


func test_beating_the_rival_pays_and_is_announced() -> void:
	_join(2)
	_say("1", "#rival User0")
	_say("0", "#rival User1")
	watch_signals(_betting)
	_start_race(0)
	_finish_marbles([1, 0] as Array[int])
	assert_eq(_flow.state, GameFlow.State.PODIUM)
	assert_eq(_balance("1"), 1005)
	assert_eq(_balance("0"), 1000)
	var results: Array = get_signal_parameters(_betting, "payouts_settled", 0)[0]
	var rival: Array = results.filter(func(r: Dictionary) -> bool: return r["kind"] == "rival")
	assert_eq(rival.size(), 1)
	assert_eq(rival[0]["user_id"], "1")
	_game._batcher.flush()
	assert_has(_source.sent, "Race over: User1 won. Rivals: @User1 beat @User0 +5")
