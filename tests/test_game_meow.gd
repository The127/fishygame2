extends GameTestBase
## Game scene: the hidden #meow command.


func test_meow_shows_a_bubble_on_the_callers_fish_only() -> void:
	_start_race(2)
	var mine: int = _marble(1).get_child_count()
	var other: int = _marble(0).get_child_count()
	_say("1", "#meow")
	assert_gt(_marble(1).get_child_count(), mine, "bubble and hearts appear")
	assert_eq(_marble(0).get_child_count(), other)


func test_meow_is_silent_and_free() -> void:
	_start_race(2)
	var balance: int = _balance("1")
	_say("1", "#meow")
	assert_eq(_balance("1"), balance)


func test_meow_in_the_lobby_does_nothing() -> void:
	_join(2)
	_say("1", "#meow")
	assert_eq(_race.get_marbles().size(), 0)


func test_meow_is_not_listed_in_help() -> void:
	assert_false(HelpText.CHAT_REPLY.contains("meow"))
	for line: String in HelpText.LINES:
		assert_false(line.contains("meow"))
