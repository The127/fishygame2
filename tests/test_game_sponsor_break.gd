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
