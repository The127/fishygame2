extends GameTestBase
## Game scene: "#left", "#right" and "#grab" work the claw of a race on the Claw Machine.


func _claw() -> ClawMachine:
	return _current_track().get_node("ClawMachine") as ClawMachine


func _start_claw(count: int = 2) -> void:
	_panel.map_selected.emit("claw")
	_start_race(count)


func test_chat_steers_and_drops_the_claw_during_a_race() -> void:
	_start_claw()
	_say("7", "#right")
	_say("8", "#left")
	_say("99", "#grab")
	assert_eq(_claw().presses(0), 1)
	assert_eq(_claw().presses(1), 1)
	assert_eq(_claw().presses(2), 1, "viewers who did not join can press too")


func test_the_tally_shows_on_the_overlay_and_hides_afterwards() -> void:
	var overlay: Overlay = _game.get_node("Overlay") as Overlay
	_start_claw()
	assert_true(overlay._tally_panel.visible)
	_say("7", "#grab")
	assert_string_contains(overlay._tally.text, "#grab 1")
	assert_string_contains(overlay._tally.text, "User7")
	_panel.stop_pressed.emit()
	assert_false(overlay._tally_panel.visible)


func test_presses_in_the_lobby_do_nothing() -> void:
	_panel.map_selected.emit("claw")
	_say("7", "#right")
	_say("7", "#grab")
	assert_eq(_claw().presses(1), 0)
	assert_eq(_claw().presses(2), 0)


func test_grab_on_other_maps_is_ignored() -> void:
	_panel.map_selected.emit("pinball")
	_start_race(2)
	_say("7", "#grab")
	assert_eq(_source.sent.size(), 0, "no chat reply")


func test_the_help_lists_the_claw_commands() -> void:
	assert_string_contains(HelpText.CHAT_REPLY, "#grab")
	assert_string_contains("\n".join(HelpText.LINES), "#grab")
