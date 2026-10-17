extends GameTestBase
## Game scene: "#left" and "#right" fire the flippers of a race on Pinball Reef 2 too.


func _table() -> PinballTable:
	return _current_track().get_node("PinballTable") as PinballTable


func _start_pinball2(count: int = 2) -> void:
	_panel.map_selected.emit("pinball2")
	_start_race(count)


func test_chat_fires_the_flippers_during_a_race() -> void:
	_start_pinball2()
	_say("7", "#left")
	_say("8", "#right")
	assert_eq(_table().presses(PinballTable.LEFT), 1)
	assert_eq(_table().presses(PinballTable.RIGHT), 1)


func test_the_tally_shows_on_the_overlay_and_hides_afterwards() -> void:
	var overlay: Overlay = _game.get_node("Overlay") as Overlay
	_start_pinball2()
	assert_true(overlay._tally_panel.visible)
	_say("7", "#left")
	assert_string_contains(overlay._tally.text, "#left 1")
	_panel.stop_pressed.emit()
	assert_false(overlay._tally_panel.visible)


func test_a_race_arms_the_saucer_and_the_ramp_gate() -> void:
	_start_pinball2()
	var saucer: LockSaucer = _current_track().get_node("Saucer") as LockSaucer
	var gate: RampGate = _current_track().get_node("RampGate") as RampGate
	assert_true(saucer.is_armed())
	assert_eq(gate.get_targets().standing(), gate.get_targets().count())
	_panel.stop_pressed.emit()
	assert_false(saucer.is_armed())
