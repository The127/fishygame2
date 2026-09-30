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


func test_joining_and_shopping_remember_the_viewer_name() -> void:
	_say("7", "#join")
	assert_eq(_betting.points.get_name("7"), "User7")
	_say("8", "#shop")
	assert_eq(_betting.points.get_name("8"), "User8")


func test_colorblind_setting_reaches_marbles_the_podium_and_the_shop() -> void:
	_game.settings.colorblind = true
	_game._apply_settings()
	assert_true(_shop.colorblind)
	_say("1", "#join")
	_say("0", "#join")
	_say("1", "#color blue")
	assert_true(_flow.start_race())
	_flow.tick(float(_flow.countdown_seconds))
	var marble: Marble = _marble(0)
	assert_eq(marble.color, FishPalette.color_of(3, true))
	assert_eq(marble.pattern, FishPalette.pattern_of(3, true))
	var podiums: Array = []
	_flow.podium_ready.connect(func(podium: Array[Dictionary]) -> void: podiums.append(podium))
	_finish_marbles([0, 1])
	assert_true(podiums[0][0].has("pattern"))


func test_bought_hat_is_worn_in_the_race_and_on_the_podium() -> void:
	_say("0", "#join")
	_say("1", "#join")
	_say("1", "#hat pirate")
	assert_eq(_balance("1"), 1000 - _shop.hat_price)
	assert_eq(_shop.hat_price, _game.settings.hat_price)
	assert_true(_flow.start_race())
	_flow.tick(float(_flow.countdown_seconds))
	assert_eq(_marble(1).accessory, FishAccessory.Kind.PIRATE_HAT)
	assert_eq(_marble(0).accessory, FishAccessory.Kind.NONE)


func test_first_race_gives_a_free_hat_once() -> void:
	_game.settings.welcome_hat = true
	_say("0", "#join")
	_say("1", "#join")
	assert_true(_flow.start_race())
	_flow.tick(float(_flow.countdown_seconds))
	for id: String in ["0", "1"]:
		var hat: String = _shop.store.equipped(id, ShopStore.KIND_HAT)
		assert_ne(hat, "", "viewer %s got a hat" % id)
		assert_true(_shop.store.owns(id, ShopStore.KIND_HAT, hat))
		assert_true(_shop.store.was_welcomed(id))
	assert_gt(_marble(0).accessory, 0)
	assert_eq(_balance("0"), 1000, "the hat is free")


func test_no_welcome_hat_for_a_viewer_who_already_raced_or_has_a_hat() -> void:
	_game.settings.welcome_hat = true
	_betting.points.stats.record_race("0")
	_say("1", "#hat crown")
	_say("0", "#join")
	_say("1", "#join")
	assert_true(_flow.start_race())
	_flow.tick(float(_flow.countdown_seconds))
	assert_eq(_shop.store.equipped("0", ShopStore.KIND_HAT), "")
	assert_eq(_shop.store.equipped("1", ShopStore.KIND_HAT), "crown")


func test_no_welcome_hat_when_the_setting_is_off() -> void:
	_say("0", "#join")
	_say("1", "#join")
	assert_true(_flow.start_race())
	_flow.tick(float(_flow.countdown_seconds))
	assert_eq(_shop.store.equipped("0", ShopStore.KIND_HAT), "")
