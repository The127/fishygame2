extends GameTestBase
## Game scene: "#shake" quakes the seafloor of a race on Earthquake Fault.


func _fault() -> QuakeFault:
	return _current_track().get_node("Fault") as QuakeFault


func _start_fault(count: int = 2) -> void:
	_panel.map_selected.emit("fault")
	_start_race(count)


func test_chat_shakes_the_fault_during_a_race() -> void:
	_start_fault()
	for i: int in 2:
		_say(str(7 + i), "#shake")
	assert_eq(_fault().counted_presses(), 2)


func test_enough_viewers_start_a_quake() -> void:
	_start_fault()
	assert_eq(_fault().quake_count(), 0)
	for i: int in QuakeFault.NEED_MIN:
		_say(str(10 + i), "#shake")
	assert_eq(_fault().quake_count(), 1)


func test_viewers_who_did_not_join_can_shake() -> void:
	_start_fault()
	_say("99", "#shake")
	assert_eq(_fault().counted_presses(), 1)


func test_the_meter_shows_on_the_overlay_and_hides_afterwards() -> void:
	var overlay: Overlay = _game.get_node("Overlay") as Overlay
	_start_fault()
	assert_true(overlay._tally_panel.visible)
	_say("7", "#shake")
	assert_string_contains(overlay._tally.text, "1 / ")
	_panel.stop_pressed.emit()
	assert_false(overlay._tally_panel.visible)


func test_the_view_shakes_when_the_ground_does() -> void:
	_start_fault()
	for i: int in QuakeFault.NEED_MIN:
		_say(str(10 + i), "#shake")
	await wait_physics_frames(int(QuakeFault.RUMBLE_SECONDS * 60.0) + 10)
	assert_gt((_game.get_node("RaceCamera") as RaceCamera).punch_strength(), 0.0)


func test_presses_in_the_lobby_do_nothing() -> void:
	_panel.map_selected.emit("fault")
	_say("7", "#shake")
	assert_eq(_fault().counted_presses(), 0)


func test_presses_on_other_maps_are_ignored() -> void:
	_panel.map_selected.emit("zigzag")
	_start_race(2)
	_say("7", "#shake")
	assert_true(_current_track().find_children("*", "QuakeFault", true, false).is_empty())
	assert_eq(_source.sent.size(), 0, "no chat reply either")


func test_the_help_lists_the_shake_command() -> void:
	assert_string_contains(HelpText.CHAT_REPLY, "#shake")
	assert_lt(HelpText.CHAT_REPLY.length(), 500)
	assert_string_contains("\n".join(HelpText.LINES), "#shake")
