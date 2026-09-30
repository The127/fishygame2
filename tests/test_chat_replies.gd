extends GutTest
## ChatReplies: confirmation wording, rejection tables, toggles and the reply cooldown.

var _replies: ChatReplies
var _lines: Array[String] = []
var _notices: Array[String] = []
var _alice: Contestant
var _bob: Contestant


func before_each() -> void:
	_lines = []
	_notices = []
	_replies = ChatReplies.new()
	_replies.settings = GameSettings.new()
	add_child_autofree(_replies)
	_replies.chat_line.connect(func(text: String) -> void: _lines.append(text))
	_replies.notice.connect(func(text: String) -> void: _notices.append(text))
	_alice = Contestant.create("a", "Alice")
	_bob = Contestant.create("b", "Bob")


func _msg(user_id: String = "a", display: String = "Alice") -> ChatMessage:
	return ChatMessage.create(user_id, display.to_lower(), display, "")


func test_viewer_name_falls_back_to_login() -> void:
	assert_eq(ChatReplies.viewer_name(_msg("a", "Alice")), "Alice")
	assert_eq(ChatReplies.viewer_name(ChatMessage.create("a", "alice", "", "")), "alice")


func test_bet_placed_confirms_and_notifies() -> void:
	_replies.bet_placed(_msg(), _bob, 50)
	_replies.batcher.flush()
	assert_eq(_lines, ["Bets: @Alice 50 on Bob"] as Array[String])
	assert_eq(_notices, ["Alice bet 50 on Bob"] as Array[String])


func test_toggle_silences_chat_but_not_the_notice() -> void:
	_replies.settings.reply_bets = false
	_replies.bet_placed(_msg(), _bob, 50)
	_replies.batcher.flush()
	assert_eq(_lines.size(), 0)
	assert_eq(_notices.size(), 1)


func test_master_switch_silences_batched_lines() -> void:
	_replies.settings.chat_replies = false
	_replies.player_joined(_alice)
	_replies.batcher.flush()
	assert_eq(_lines.size(), 0)


func test_joins_are_batched() -> void:
	_replies.player_joined(_alice)
	_replies.player_joined(_bob)
	assert_eq(_lines.size(), 0)
	_replies.batcher.flush()
	assert_eq(_lines, ["Joined: @Alice, @Bob"] as Array[String])


func test_rejections_use_the_tables_and_fall_back() -> void:
	_replies.bet_rejected(_msg(), "below_min")
	_replies.bet_rejected(_msg(), "nonsense")
	_replies.effect_rejected(_msg(), "self_boost")
	_replies.effect_rejected(_msg(), "nonsense")
	_replies.shop_rejected(_msg(), "unknown_hat")
	_replies.shop_rejected(_msg(), "nonsense")
	assert_eq(
		_notices,
		(
			[
				"Alice: bet is below the minimum",
				"Alice: bet not accepted",
				"Alice: you can't boost your own fish",
				"Alice: not accepted",
				"Alice: no such accessory, see #shop",
				"Alice: not accepted",
			]
			as Array[String]
		)
	)


func test_power_rejection_text() -> void:
	assert_eq(ChatReplies.power_rejection("cap"), "no powers left this race")
	assert_eq(ChatReplies.power_rejection("nonsense"), "power not available")


func test_effect_applied_words_boost_and_curse() -> void:
	_replies.effect_applied(_msg(), _bob, Chaos.Kind.BOOST)
	_replies.effect_applied(_msg(), _bob, Chaos.Kind.CURSE)
	_replies.batcher.flush()
	assert_eq(_lines, ["Boosted: @Alice on Bob", "Cursed: @Alice on Bob"] as Array[String])
	assert_eq(_notices, ["Alice boosted Bob!", "Alice cursed Bob!"] as Array[String])


func test_shop_equipped_distinguishes_bought_from_switched() -> void:
	_replies.shop_equipped(_msg(), "hat", "crown", 30)
	_replies.shop_equipped(_msg(), "hat", "crown", 0)
	_replies.batcher.flush()
	assert_eq(_lines, ["Shop: @Alice hat crown, @Alice hat crown"] as Array[String])
	assert_eq(_notices, ["Alice bought crown for 30", "Alice switched to crown"] as Array[String])


func test_balance_and_welcome_notices() -> void:
	_replies.balance_reported(_msg(), 120)
	_replies.welcome("Alice", "crown")
	_replies.batcher.flush()
	assert_eq(
		_notices, ["Alice has 120 points", "Welcome Alice! Here's a free crown"] as Array[String]
	)
	assert_eq(_lines, ["Welcome! @Alice (free crown)"] as Array[String])


func test_join_rejection_replies_once_per_viewer_per_cooldown() -> void:
	_replies.join_rejected(_msg("a"), "full")
	_replies.join_rejected(_msg("a"), "full")
	assert_eq(_lines, ["@Alice the lobby is full."] as Array[String])
	_replies.join_rejected(_msg("b", "Bob"), "closed")
	assert_eq(_lines.size(), 2, "another viewer has their own cooldown")


func test_join_rejection_replies_again_after_the_cooldown() -> void:
	_replies.join_rejected(_msg("a"), "full")
	_replies._last_reply_msec["a"] = Time.get_ticks_msec() - ChatReplies.REPLY_COOLDOWN_MSEC
	_replies.join_rejected(_msg("a"), "full")
	assert_eq(_lines.size(), 2)


func test_silent_join_rejections_and_master_switch() -> void:
	_replies.join_rejected(_msg(), "duplicate")
	assert_eq(_lines.size(), 0)
	_replies.settings.chat_replies = false
	_replies.join_rejected(_msg(), "full")
	assert_eq(_lines.size(), 0)
