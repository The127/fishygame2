extends GutTest


func test_spinner_turns_at_its_speed() -> void:
	var spinner: Spinner = autofree(Spinner.new())
	spinner.speed = 2.0
	spinner._physics_process(0.5)
	assert_almost_eq(spinner.rotation, 1.0, 0.0001)


func test_wreck_map_has_a_moving_obstacle() -> void:
	var track: Track = TrackCatalog.instantiate("wreck")
	add_child_autofree(track)
	assert_eq(track.find_children("*", "Spinner", false, false).size(), 1)
