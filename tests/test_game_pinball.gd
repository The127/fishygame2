extends GameTestBase
## Game scene: "#left" and "#right" fire the flippers of a race on Pinball Reef.


func _table() -> PinballTable:
	return _current_track().get_node("PinballTable") as PinballTable


func _start_pinball(count: int = 2) -> void:
	_panel.map_selected.emit("pinball")
	_start_race(count)


func test_chat_fires_the_flippers_during_a_race() -> void:
	_start_pinball()
	_say("7", "#left")
	_say("8", "#right")
	assert_eq(_table().presses(PinballTable.LEFT), 1)
	assert_eq(_table().presses(PinballTable.RIGHT), 1)


func test_viewers_who_did_not_join_can_fire() -> void:
	_start_pinball()
	_say("99", "#left")
	assert_eq(_table().presses(PinballTable.LEFT), 1)


func test_the_tally_shows_on_the_overlay_and_hides_afterwards() -> void:
	var overlay: Overlay = _game.get_node("Overlay") as Overlay
	_start_pinball()
	assert_true(overlay._tally_panel.visible)
	_say("7", "#left")
	assert_string_contains(overlay._tally.text, "#left 1")
	assert_string_contains(overlay._tally.text, "User7")
	_panel.stop_pressed.emit()
	assert_false(overlay._tally_panel.visible)


func test_presses_in_the_lobby_do_nothing() -> void:
	_panel.map_selected.emit("pinball")
	_say("7", "#left")
	assert_eq(_table().presses(PinballTable.LEFT), 0)


func test_presses_on_other_maps_are_ignored() -> void:
	_panel.map_selected.emit("zigzag")
	_start_race(2)
	_say("7", "#left")
	_say("7", "#right")
	assert_true(_current_track().find_children("*", "PinballTable", true, false).is_empty())
	assert_eq(_source.sent.size(), 0, "no chat reply either")


func test_the_help_lists_the_flipper_commands() -> void:
	assert_string_contains(HelpText.CHAT_REPLY, "#left")
	assert_string_contains(HelpText.CHAT_REPLY, "#right")
	var lines: String = "\n".join(HelpText.LINES)
	assert_string_contains(lines, "#left")
