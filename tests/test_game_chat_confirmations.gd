extends GameTestBase
## Game scene: batched chat confirmations for joins, bets, chaos, the shop and results.

var _batcher: ChatBatcher


func before_each() -> void:
	super.before_each()
	_batcher = _game._batcher


func _configure(settings: GameSettings) -> void:
	settings.starting_balance = 1000
	settings.min_bet = 1


func test_joins_are_batched_into_one_line() -> void:
	_say("0", "#join")
	_say("1", "#join")
	assert_eq(_source.sent.size(), 0, "nothing goes out until the batch flushes")
	_batcher.flush()
	assert_eq(_source.sent, ["Joined: @User0, @User1"] as Array[String])


func test_bets_name_the_amount_and_the_fish() -> void:
	_join(2)
	_batcher.flush()
	_source.sent.clear()
	_say("0", "#bet User1 50")
	_batcher.flush()
	assert_eq(_source.sent, ["Bets: @User0 50 on User1"] as Array[String])


func test_rejected_bet_is_not_confirmed() -> void:
	_join(2)
	_batcher.flush()
	_source.sent.clear()
	_say("0", "#bet User1 999999")
	_batcher.flush()
	assert_eq(_source.sent.size(), 0)


func test_master_switch_silences_everything() -> void:
	_game.settings.chat_replies = false
	_say("0", "#join")
	_batcher.flush()
	assert_eq(_source.sent.size(), 0)


func test_each_toggle_silences_only_its_kind() -> void:
	_game.settings.reply_joins = false
	_say("0", "#join")
	_say("1", "#join")
	_batcher.flush()
	assert_eq(_source.sent.size(), 0)
	_say("0", "#bet User1 50")
	_batcher.flush()
	assert_eq(_source.sent.size(), 1, "bets are still confirmed")


func test_turning_replies_off_before_the_flush_drops_the_line() -> void:
	_say("0", "#join")
	_game.settings.chat_replies = false
	_batcher.flush()
	assert_eq(_source.sent.size(), 0)


func test_result_line_names_winner_and_top_payouts() -> void:
	var text: String = (
		_game
		. _result_text(
			"Bubbles",
			(
				[
					{"name": "a", "payout": 100},
					{"name": "b", "payout": 0},
					{"name": "c", "payout": 300},
					{"name": "d", "payout": 200},
					{"name": "e", "payout": 50},
				]
				as Array[Dictionary]
			)
		)
	)
	assert_eq(text, "Bubbles won. Payouts: @c +300, @d +200, @a +100")


func test_result_line_without_bets_is_just_the_winner() -> void:
	assert_eq(_game._result_text("Bubbles", [] as Array[Dictionary]), "Bubbles won.")


func test_podium_queues_the_result() -> void:
	_join(2)
	_batcher.flush()
	_source.sent.clear()
	_game._on_podium_ready(
		(
			[{"name": "User0", "finished": true}, {"name": "User1", "finished": true}]
			as Array[Dictionary]
		)
	)
	_batcher.flush()
	assert_eq(_source.sent, ["Race over: User0 won."] as Array[String])
