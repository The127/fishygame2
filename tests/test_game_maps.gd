extends GameTestBase
## Game scene: map selection.


func test_map_selection_applies_to_open_lobby() -> void:
	_panel.map_selected.emit("pachinko")
	assert_eq(_current_track().scene_file_path, "res://scenes/tracks/pachinko_track.tscn")
	_panel.map_selected.emit("zigzag")
	assert_eq(_current_track().scene_file_path, "res://scenes/tracks/test_track.tscn")


func test_map_selection_keeps_roster() -> void:
	_join(2)
	_panel.map_selected.emit("pachinko")
	assert_eq(_flow.get_contestants().size(), 2)
	assert_eq(_game.get_children().filter(func(n: Node) -> bool: return n is Track).size(), 1)


func test_map_selected_mid_race_waits_for_next_lobby() -> void:
	_panel.map_selected.emit("zigzag")
	_start_race(2)
	var track: Track = _current_track()
	_panel.map_selected.emit("pachinko")
	assert_same(_current_track(), track, "the running race keeps its track")
	_finish_marbles([0, 1])
	_flow.tick(5.5)
	assert_eq(_current_track().scene_file_path, "res://scenes/tracks/pachinko_track.tscn")


func test_race_uses_selected_map() -> void:
	_panel.map_selected.emit("pachinko")
	_start_race(2)
	assert_eq(_current_track().scene_file_path, "res://scenes/tracks/pachinko_track.tscn")
	assert_eq(_race.get_marbles().size(), 2)


func test_random_map_avoids_repeating_the_last_map() -> void:
	_panel.map_selected.emit(TrackCatalog.RANDOM_ID)
	var last: String = _current_track().scene_file_path
	for i: int in 6:
		_panel.stop_pressed.emit()
		_panel.open_lobby_pressed.emit()
		var path: String = _current_track().scene_file_path
		assert_ne(path, last, "lobby %d repeated the previous map" % i)
		last = path


func test_stop_and_reopen_keeps_map_and_clears_marbles() -> void:
	_start_race(2)
	_panel.stop_pressed.emit()
	_panel.open_lobby_pressed.emit()
	assert_eq(_flow.state, GameFlow.State.LOBBY)
	assert_eq(_race.get_marbles().size(), 0)
	assert_not_null(_current_track())
