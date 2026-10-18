extends GameTestBase
## Game scene: "#up", "#down", "#left" and "#right" steer the gravity of a race on Gravity Flip.


func _flipper() -> GravityFlipper:
	return _current_track().get_node("Flipper") as GravityFlipper


func _start_gravity(count: int = 2) -> void:
	_panel.map_selected.emit("gravity")
	_start_race(count)


func test_chat_votes_for_a_side_during_a_race() -> void:
	_start_gravity()
	_say("7", "#up")
	_say("8", "#up")
	_say("9", "#right")
	var counts: PackedInt32Array = _flipper().vote_counts()
	assert_eq(counts[GravityFlipper.Pull.UP], 2)
	assert_eq(counts[GravityFlipper.Pull.RIGHT], 1)


func test_every_command_maps_to_its_side() -> void:
	_start_gravity()
	_say("1", "#down")
	_say("2", "#up")
	_say("3", "#right")
	_say("4", "#left")
	var counts: PackedInt32Array = _flipper().vote_counts()
	for side: int in 4:
		assert_eq(counts[side], 1, GravityFlipper.COMMANDS[side])


func test_viewers_who_did_not_join_can_vote() -> void:
	_start_gravity()
	_say("99", "#left")
	assert_eq(_flipper().vote_counts()[GravityFlipper.Pull.LEFT], 1)


func test_the_tally_shows_on_the_overlay_and_hides_afterwards() -> void:
	var overlay: Overlay = _game.get_node("Overlay") as Overlay
	_start_gravity()
	assert_true(overlay._tally_panel.visible)
	_say("7", "#up")
	assert_string_contains(overlay._tally.text, "[#up 1]")
	_panel.stop_pressed.emit()
	assert_false(overlay._tally_panel.visible)


func test_votes_in_the_lobby_do_nothing() -> void:
	_panel.map_selected.emit("gravity")
	_say("7", "#up")
	assert_eq(_flipper().vote_counts()[GravityFlipper.Pull.UP], 0)


func test_votes_on_other_maps_are_ignored() -> void:
	_panel.map_selected.emit("zigzag")
	_start_race(2)
	_say("7", "#up")
	assert_true(_current_track().find_children("*", "GravityFlipper", true, false).is_empty())
	assert_eq(_source.sent.size(), 0, "no chat reply either")


func test_the_help_lists_the_gravity_commands() -> void:
	assert_string_contains(HelpText.CHAT_REPLY, "#up")
	assert_lt(HelpText.CHAT_REPLY.length(), 500)
	assert_string_contains(HelpText.sheet_text("gravity"), "#up")
