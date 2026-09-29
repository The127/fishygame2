extends GameTestBase
## The game reads GameSettings when its scene starts.


func _configure(settings: GameSettings) -> void:
	settings.min_players = 2
	settings.countdown_seconds = 5
	settings.starting_balance = 400
	settings.min_bet = 50
	settings.max_bet = 200
	settings.boost_cost = 30
	settings.curse_cost = 60
	settings.viewer_cooldown = 9
	settings.fish_lockout = 2
	settings.default_map = "pachinko"


func test_flow_reads_the_settings() -> void:
	assert_eq(_flow.min_players, 2)
	assert_eq(_flow.max_players, 4)
	assert_eq(_flow.countdown_seconds, 5)


func test_betting_reads_the_settings() -> void:
	assert_eq(_betting.min_bet, 50)
	assert_eq(_betting.max_bet, 200)
	assert_eq(_balance("new_viewer"), 400)


func test_chaos_reads_the_settings() -> void:
	assert_eq(_chaos.boost_cost, 30)
	assert_eq(_chaos.curse_cost, 60)
	assert_eq(_chaos.viewer_cooldown, 9.0)
	assert_eq(_chaos.fish_lockout, 2.0)


func test_default_map_is_used_for_the_first_lobby() -> void:
	assert_eq(_game._map_id, "pachinko")


func test_bets_outside_the_limits_are_rejected() -> void:
	_join(2)
	var rejected: Array[String] = []
	_betting.bet_rejected.connect(
		func(_m: ChatMessage, reason: String) -> void: rejected.append(reason)
	)
	_say("0", "#bet User1 10")
	_say("0", "#bet User1 500")
	assert_eq(rejected, ["below_min", "above_max"])
	assert_eq(_balance("0"), 400, "nothing was taken")
	_say("0", "#bet User1 200")
	assert_eq(_balance("0"), 200)


func test_bet_all_is_capped_at_the_max_bet() -> void:
	_join(2)
	_say("0", "#bet User1 all")
	assert_eq(_balance("0"), 200, "400 balance, 200 max bet")


func test_bet_all_below_the_minimum_reads_as_not_enough_points() -> void:
	_join(2)
	_betting.points.set_balance("0", 20)
	var rejected: Array[String] = []
	_betting.bet_rejected.connect(
		func(_m: ChatMessage, reason: String) -> void: rejected.append(reason)
	)
	_say("0", "#bet User1 all")
	assert_eq(rejected, ["insufficient"])


func test_chat_replies_can_be_turned_off() -> void:
	_join(4)
	_say("9", "#join")
	assert_eq(_source.sent.size(), 1, "the lobby is full reply goes out")
	_game.settings.chat_replies = false
	_say("8", "#join")
	assert_eq(_source.sent.size(), 1, "no reply while replies are off")
