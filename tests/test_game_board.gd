extends GameTestBase
## Game scene: "#roll" rolls the die of a race on Board Game.


func _dice() -> BoardDice:
	return (_current_track().get_node("Centerline") as SnakeBoard).get_dice()


func _start_board(count: int = 2) -> void:
	_panel.map_selected.emit("board")
	_start_race(count)


func test_chat_presses_the_die_during_a_race() -> void:
	_start_board()
	for i: int in 2:
		_say(str(7 + i), "#roll")
	assert_eq(_dice().counted_presses(), 2)


func test_enough_viewers_roll_the_die() -> void:
	_start_board()
	assert_eq(_dice().roll_count(), 0)
	for i: int in BoardDice.NEED_MIN:
		_say(str(10 + i), "#roll")
	assert_eq(_dice().roll_count(), 1)


func test_viewers_who_did_not_join_can_roll() -> void:
	_start_board()
	_say("99", "#roll")
	assert_eq(_dice().counted_presses(), 1)


func test_the_meter_shows_on_the_overlay_and_hides_afterwards() -> void:
	var overlay: Overlay = _game.get_node("Overlay") as Overlay
	_start_board()
	assert_true(overlay._tally_panel.visible)
	_say("7", "#roll")
	assert_string_contains(overlay._tally.text, "1 / ")
	_panel.stop_pressed.emit()
	assert_false(overlay._tally_panel.visible)


func test_presses_in_the_lobby_do_nothing() -> void:
	_panel.map_selected.emit("board")
	_say("7", "#roll")
	assert_eq(_dice().counted_presses(), 0)


func test_presses_on_other_maps_are_ignored_without_a_reply() -> void:
	_panel.map_selected.emit("zigzag")
	_start_race(2)
	_say("7", "#roll")
	assert_true(_current_track().find_children("*", "BoardDice", true, false).is_empty())
	assert_eq(_source.sent.size(), 0, "no chat reply either")


func test_rolling_posts_nothing_in_chat() -> void:
	_start_board()
	for i: int in BoardDice.NEED_MIN:
		_say(str(10 + i), "#roll")
	assert_eq(_source.sent.size(), 0)


func test_the_help_lists_the_roll_command() -> void:
	assert_string_contains(HelpText.CHAT_REPLY, "#roll")
	assert_lt(HelpText.CHAT_REPLY.length(), 500)
	assert_string_contains("\n".join(HelpText.LINES), "#roll")
