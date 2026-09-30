extends GutTest
## Pool-style bet payouts and free picks.

var _betting: Betting
var _chat: Node
var _source: DebugChatSource
var _alice: Contestant
var _bob: Contestant


func before_each() -> void:
	_betting = Betting.new()
	_betting.points = PointsStore.new("", 1000)
	add_child_autofree(_betting)
	_chat = load("res://scripts/chat/chat.gd").new()
	add_child_autofree(_chat)
	_source = DebugChatSource.new()
	_chat.set_source(_source)
	_chat.command_received.connect(_betting.handle_command)
	_alice = Contestant.create("a", "Alice")
	_bob = Contestant.create("b", "Bob")
	_open_round([_alice, _bob])


func _open_round(contestants: Array[Contestant]) -> void:
	_betting.on_state_changed(GameFlow.State.LOBBY, GameFlow.State.IDLE)
	for contestant: Contestant in contestants:
		_betting.add_contestant(contestant)


func _bet(user_id: String, name_text: String, text: String) -> void:
	_source.inject(user_id, name_text, text)


func _podium(winner: Contestant, finished: bool = true) -> Array[Dictionary]:
	return [
		{
			"place": 1,
			"user_id": winner.user_id,
			"name": winner.display_name,
			"finished": finished,
			"time": 10.0,
		}
	]


func _balance(user_id: String) -> int:
	return _betting.points.get_balance(user_id)


func test_pool_is_split_by_stake_among_winning_bettors() -> void:
	_bet("v1", "V1", "#bet Alice 100")
	_bet("v2", "V2", "#bet Alice 300")
	_bet("v3", "V3", "#bet Bob 600")
	_betting.on_state_changed(GameFlow.State.RACING, GameFlow.State.COUNTDOWN)
	_betting.on_podium_ready(_podium(_alice))
	# Pool 1000, doubled 2000, shared 1:3.
	assert_eq(_balance("v1"), 900 + 500)
	assert_eq(_balance("v2"), 700 + 1500)
	assert_eq(_balance("v3"), 400)


func test_stakes_are_lost_when_nobody_bet_on_the_winner() -> void:
	_bet("v1", "V1", "#bet Bob 100")
	_betting.on_state_changed(GameFlow.State.RACING, GameFlow.State.COUNTDOWN)
	watch_signals(_betting)
	_betting.on_podium_ready(_podium(_alice))
	assert_eq(_balance("v1"), 900)
	assert_eq(_betting.points.stake_of("v1"), 0)
	assert_eq(get_signal_parameters(_betting, "payouts_settled", 0)[0][0]["payout"], 0)


func test_viewer_who_never_raced_can_bet_and_gets_the_starting_balance() -> void:
	assert_false(_betting.points.has_entry("newcomer"))
	_bet("newcomer", "New", "#bet Alice 250")
	assert_true(_betting.has_bet("newcomer"))
	assert_eq(_balance("newcomer"), 750)


func test_pick_is_free_and_pays_the_reward_when_right() -> void:
	watch_signals(_betting)
	_bet("v1", "V1", "#pick alice")
	_bet("v2", "V2", "#pick @Bob")
	assert_signal_emit_count(_betting, "pick_placed", 2)
	assert_eq(_balance("v1"), 1000, "a pick costs nothing")
	assert_true(_betting.has_pick("v1"))
	_betting.on_state_changed(GameFlow.State.RACING, GameFlow.State.COUNTDOWN)
	_betting.on_podium_ready(_podium(_alice))
	assert_eq(_balance("v1"), 1000 + _betting.pick_reward)
	assert_eq(_balance("v2"), 1000)
	var results: Array = get_signal_parameters(_betting, "payouts_settled", 0)[0]
	assert_eq(results.size(), 1, "wrong picks are not listed")
	assert_eq(results[0]["kind"], "pick")
	assert_false(_betting.has_pick("v1"), "picks are cleared after settling")


func test_pick_works_alongside_a_bet_and_for_new_viewers() -> void:
	_betting.pick_reward = 70
	_bet("v1", "V1", "#bet Bob 100")
	_bet("v1", "V1", "#pick Alice")
	_bet("newcomer", "New", "#pick Alice")
	_betting.on_state_changed(GameFlow.State.RACING, GameFlow.State.COUNTDOWN)
	_betting.on_podium_ready(_podium(_alice))
	assert_eq(_balance("v1"), 900 + 70, "lost bet, won pick")
	assert_eq(_balance("newcomer"), 1070)


func test_pick_rejections() -> void:
	watch_signals(_betting)
	_bet("v1", "V1", "#pick")
	_bet("v1", "V1", "#pick Nobody")
	_bet("v1", "V1", "#pick Alice")
	_bet("v1", "V1", "#pick Bob")
	var reasons: Array[String] = []
	for i: int in 3:
		reasons.append(str(get_signal_parameters(_betting, "pick_rejected", i)[1]))
	assert_eq(reasons, ["usage", "unknown_fish", "already_picked"])
	_betting.on_state_changed(GameFlow.State.RACING, GameFlow.State.COUNTDOWN)
	_bet("v2", "V2", "#pick Alice")
	assert_eq(str(get_signal_parameters(_betting, "pick_rejected", 3)[1]), "closed")


func test_picks_are_dropped_on_abort_and_new_lobby() -> void:
	_bet("v1", "V1", "#pick Alice")
	_betting.on_state_changed(GameFlow.State.IDLE, GameFlow.State.LOBBY)
	assert_false(_betting.has_pick("v1"))
	_open_round([_alice, _bob])
	_bet("v1", "V1", "#pick Alice")
	_open_round([_alice, _bob])
	assert_false(_betting.has_pick("v1"))


func test_zero_reward_pays_nothing() -> void:
	_betting.pick_reward = 0
	_bet("v1", "V1", "#pick Alice")
	_betting.on_state_changed(GameFlow.State.RACING, GameFlow.State.COUNTDOWN)
	_betting.on_podium_ready(_podium(_alice))
	assert_eq(_balance("v1"), 1000)


func test_summary_counts_picks() -> void:
	_bet("v1", "V1", "#bet Alice 100")
	_bet("v3", "V3", "#pick Alice")
	assert_eq(_betting.summary(), "1 bets, 100 points wagered, 1 picks")
