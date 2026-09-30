extends GutTest
## Pool-style bet payouts.

var _betting: Betting
var _chat: Node
var _source: DebugChatSource
var _alice: Contestant
var _bob: Contestant


func before_each() -> void:
	_betting = Betting.new()
	_betting.points = PointsStore.new("", 1000)
	_betting.place_rewards = []
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
