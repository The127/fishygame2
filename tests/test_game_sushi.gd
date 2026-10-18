extends GameTestBase
## Game scene: "#chop" swings the chef's knife in a race on Sushi Bar.


func _chef() -> SushiChef:
	return _current_track().get_node("Centerline/Chef") as SushiChef


func _start_sushi(count: int = 2) -> void:
	_panel.map_selected.emit("sushi")
	_start_race(count)


func test_chat_swings_the_knife_during_a_race() -> void:
	_start_sushi()
	_say("7", "#chop")
	assert_eq(_chef().swing_count(), 1)
	assert_eq(_chef().get_phase(), SushiChef.Phase.WINDUP)


func test_viewers_who_did_not_join_can_chop() -> void:
	_start_sushi()
	_say("99", "#chop")
	assert_eq(_chef().swing_count(), 1)


func test_spam_waits_for_the_knife() -> void:
	_start_sushi()
	for i: int in 5:
		_say(str(10 + i), "#chop")
	assert_eq(_chef().swing_count(), 1)


func test_presses_in_the_lobby_do_nothing() -> void:
	_panel.map_selected.emit("sushi")
	_say("7", "#chop")
	assert_eq(_chef().swing_count(), 0)


func test_presses_on_other_maps_are_ignored() -> void:
	_panel.map_selected.emit("zigzag")
	_start_race(2)
	_say("7", "#chop")
	assert_true(_current_track().find_children("*", "SushiChef", true, false).is_empty())
	assert_eq(_source.sent.size(), 0, "no chat reply either")


func test_the_meter_shows_on_the_overlay_and_hides_afterwards() -> void:
	var overlay: Overlay = _game.get_node("Overlay") as Overlay
	_start_sushi()
	assert_true(overlay._tally_panel.visible)
	assert_string_contains(overlay._tally.text, "#chop")
	_panel.stop_pressed.emit()
	assert_false(overlay._tally_panel.visible)


func test_a_chopped_fish_is_announced_on_the_overlay_only() -> void:
	_start_sushi()
	var marble: Marble = _marble(1)
	var chef: SushiChef = _chef()
	chef.fish_chopped.emit(marble, "Ann")
	var overlay: Overlay = _game.get_node("Overlay") as Overlay
	assert_string_contains(overlay._notice.text, "chopped into sushi by Ann")
	assert_eq(_source.sent.size(), 0, "nothing is posted in chat")


func test_the_help_lists_the_chop_command() -> void:
	assert_string_contains(HelpText.CHAT_REPLY, "#chop")
	assert_lt(HelpText.CHAT_REPLY.length(), 500)
	assert_string_contains(HelpText.sheet_text("sushi"), "#chop")
