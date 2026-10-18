extends GameTestBase
## With "Auto-join chatters" off (the default) only "#join" joins.


func test_chatting_does_not_join() -> void:
	assert_false(GameSettings.new().auto_join_chatters, "off by default")
	_say("1", "hi chat")
	assert_eq(_flow.get_contestants().size(), 0)
	_say("1", "#join")
	assert_eq(_flow.get_contestants().size(), 1)
