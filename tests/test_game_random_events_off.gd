extends GameTestBase
## With random events off (the default) races run exactly as before.


func test_no_event_and_the_countdown_is_untouched() -> void:
	assert_eq(_flow.countdown_seconds, 3)
	_game.forced_event = RaceEvent.LOW_GRAVITY
	_start_race(2)
	assert_eq(_race.event, RaceEvent.NOTHING)
	for marble: Marble in _race.get_marbles():
		assert_eq(marble.gravity_scale, 1.0)
