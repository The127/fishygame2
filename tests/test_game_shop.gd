extends GameTestBase


func test_bought_look_is_used_in_the_race() -> void:
	_say("0", "#join")
	_say("1", "#join")
	_say("1", "#fish pike")
	_say("1", "#color navy")
	assert_eq(_balance("1"), 1000 - _shop.species_price - _shop.color_price)
	assert_true(_flow.start_race())
	_flow.tick(float(_flow.countdown_seconds))
	var marble: Marble = _marble(1)
	assert_eq(marble.species, 2)
	assert_eq(marble.color, Contestant.PALETTE[18])
	assert_ne(_marble(0).color, marble.color)


func test_look_bought_before_joining_still_applies() -> void:
	_say("5", "#color red")
	_say("5", "#join")
	_say("6", "#join")
	assert_true(_flow.start_race())
	_flow.tick(float(_flow.countdown_seconds))
	assert_eq(_marble(0).color, Contestant.PALETTE[0])
	assert_ne(
		_marble(1).color,
		Contestant.PALETTE[0],
		"the second joiner's default slot color is free again"
	)


func test_podium_shows_the_bought_species() -> void:
	_say("0", "#fish angelfish")
	_start_race(2)
	var podiums: Array = []
	_flow.podium_ready.connect(func(podium: Array[Dictionary]) -> void: podiums.append(podium))
	_finish_marbles([0, 1])
	assert_eq(podiums.size(), 1)
	assert_eq(podiums[0][0]["species"], 3)


func test_settings_prices_reach_the_shop() -> void:
	assert_eq(_shop.species_price, _game.settings.species_price)
	assert_eq(_shop.color_price, _game.settings.color_price)
