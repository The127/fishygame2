extends GameTestBase
## "Auto-join chatters" in the game: chatting joins through the normal join path, with its cap,
## no chat lines for rejections, and never for lurkers or ignored accounts.


func _configure(settings: GameSettings) -> void:
	settings.auto_join_chatters = true
	settings.auto_join_ignore = "userbot"


func _roster() -> Array[String]:
	var ids: Array[String] = []
	for contestant: Contestant in _flow.get_contestants():
		ids.append(contestant.user_id)
	return ids


func test_chatting_in_the_lobby_joins_the_race() -> void:
	_say("1", "hi chat")
	_say("2", "#bet 1 10")
	assert_eq(_roster(), ["1", "2"])


func test_the_cap_holds_and_rejections_stay_silent() -> void:
	for i: int in 6:
		_say(str(i), "hello")
	_say("0", "hello again")
	assert_eq(_roster(), ["0", "1", "2", "3"], "max_players is 4")
	await wait_physics_frames(2)
	for line: String in _source.sent:
		assert_false(line.contains("full"), "no lobby full reply: " + line)


func test_an_explicit_join_still_works() -> void:
	_say("1", "#join")
	assert_eq(_roster(), ["1"])


func test_lurkers_and_ignored_accounts_are_not_joined() -> void:
	_say("1", "#lurk")
	_say("1", "just watching")
	_say("Bot", "!commands")
	assert_eq(_roster(), [])
	_say("1", "#join")
	assert_eq(_roster(), ["1"], "#join ends lurking as before")


func test_recent_chatters_join_the_next_lobby() -> void:
	_start_race(2)
	_say("7", "go fish go")
	_finish_marbles([0, 1])
	_flow.tick(_flow.podium_seconds)
	assert_eq(_flow.state, GameFlow.State.LOBBY)
	assert_has(_roster(), "7")
	assert_eq(_roster().size(), 3, "the two racers chatted too, by #join")
