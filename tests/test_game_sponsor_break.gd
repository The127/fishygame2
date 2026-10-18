extends GameTestBase
## The game runs the sponsor break during races when the setting is on.


func test_race_start_arms_the_ad_and_a_finish_takes_it_down() -> void:
	_start_race(2)
	var ad: SponsorBreak = _game._sponsor
	assert_true(ad.is_due())
	ad.update(0.1, 0.5)
	assert_true(ad.is_showing())
	_finish_marbles([0])
	assert_false(ad.is_showing())
	assert_false(ad.visible)


func test_no_ad_when_the_setting_is_off() -> void:
	_game.settings.sponsor_break = false
	_game._apply_settings()
	_start_race(2)
	assert_false(_game._sponsor.is_due())


func test_no_ad_in_the_fake_sequel_round() -> void:
	_game.fake_sequel = false
	_start_race(2)
	_game._sponsor.stop()
	_game.fake_sequel = true
	_game._on_race_started(_flow.get_contestants())
	assert_false(_game._sponsor.is_due())


func test_leader_fraction_is_zero_before_and_rises_during_a_race() -> void:
	assert_eq(_race.leader_fraction(), 0.0)
	_start_race(2)
	var start: float = _race.leader_fraction()
	assert_between(start, 0.0, 0.2)
	_marble(0).global_position = _current_track().get_finish_position()
	assert_gt(_race.leader_fraction(), 0.8)
