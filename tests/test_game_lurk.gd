extends GameTestBase
## "#lurk" in the game: the lurker's shadow on the map, the silent point and "#join" ending it.


func _den() -> LurkerDen:
	for child: Node in _current_track().get_children():
		if child is LurkerDen:
			return child as LurkerDen
	return null


func test_lurker_watches_from_the_map_and_earns_a_point_silently() -> void:
	_say("9", "#lurk")
	await wait_physics_frames(2)
	assert_eq(_den().shown_count(), 1)
	_start_race(2)
	_source.sent.clear()
	_finish_marbles([0, 1])
	assert_eq(_balance("9"), _betting.points.starting_balance + 1)
	for line: String in _source.sent:
		assert_false(line.contains("User9"), "nothing in chat about the lurker")


func test_join_ends_lurking() -> void:
	_say("0", "#lurk")
	await wait_physics_frames(2)
	_say("0", "#join")
	assert_eq(_den().shown_count(), 0)
	assert_false(_shop.store.is_lurking("0"))


func test_lurk_is_in_the_help() -> void:
	assert_string_contains(HelpText.CHAT_REPLY, "#lurk")
	assert_string_contains(HelpText.sheet_text(""), "#lurk")
