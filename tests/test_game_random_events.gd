extends GameTestBase
## The wheel that runs over the countdown and the event a race then runs under.


func _configure(settings: GameSettings) -> void:
	settings.random_events = true


func test_countdown_leaves_time_for_the_wheel() -> void:
	assert_eq(_flow.countdown_seconds, RaceEvent.MIN_COUNTDOWN)


func test_the_race_runs_under_the_wheels_event() -> void:
	_game.forced_event = RaceEvent.LOW_GRAVITY
	_start_race(2)
	assert_eq(_race.event, RaceEvent.LOW_GRAVITY)
	for marble: Marble in _race.get_marbles():
		assert_almost_eq(
			marble.gravity_scale, RaceEvent.gravity_scale(RaceEvent.LOW_GRAVITY), 0.001
		)


func test_a_nothing_slice_changes_no_rules() -> void:
	_game.forced_event = RaceEvent.NOTHING
	_start_race(2)
	assert_eq(_race.event, RaceEvent.NOTHING)
	for marble: Marble in _race.get_marbles():
		assert_eq(marble.gravity_scale, 1.0)
	assert_eq(_current_track().modulate, Color.WHITE)


func test_lights_out_darkens_the_map_until_the_next_lobby() -> void:
	_game.forced_event = RaceEvent.LIGHTS_OUT
	_start_race(2)
	var track: Track = _current_track()
	assert_eq(track.modulate, RaceEvent.track_tint(RaceEvent.LIGHTS_OUT))
	_flow.stop()
	assert_eq(track.modulate, Color.WHITE)


func test_bouncy_changes_a_copy_of_the_material() -> void:
	_game.forced_event = RaceEvent.BOUNCY
	_start_race(2)
	var bounce: float = RaceEvent.bounce(RaceEvent.BOUNCY)
	for marble: Marble in _race.get_marbles():
		assert_almost_eq(marble.physics_material_override.bounce, bounce, 0.001)
	var plain: Marble = (load("res://scenes/marble.tscn") as PackedScene).instantiate() as Marble
	autofree(plain)
	assert_ne(plain.physics_material_override.bounce, bounce, "the scene's material is untouched")


func test_each_race_spins_again() -> void:
	_game.forced_event = RaceEvent.LOW_GRAVITY
	_start_race(2)
	_flow.stop()
	_game.forced_event = RaceEvent.NOTHING
	_flow.open_lobby()
	_start_race(2)
	assert_eq(_race.event, RaceEvent.NOTHING)
