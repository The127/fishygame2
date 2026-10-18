extends GameTestBase
## Game scene: cardboard cutouts race as extra marbles but are nobody when points are settled.


func _configure(settings: GameSettings) -> void:
	settings.cardboard_fish = true
	settings.cardboard_fill = GameSettings.CARDBOARD_FIVE
	settings.max_players = 20
	settings.win_reward = 100
	settings.second_reward = 50


func test_one_viewer_races_with_four_cutouts() -> void:
	_start_race(1)
	assert_eq(_race.get_marbles().size(), 5)
	var cutouts: int = 0
	for marble: Marble in _race.get_marbles():
		if marble.cardboard:
			cutouts += 1
			assert_true(marble.id >= 1, "cutouts race after the roster")
	assert_eq(cutouts, 4)
	assert_false(_marble(0).cardboard)


func test_a_winning_cutout_is_shown_but_the_viewer_is_paid() -> void:
	_join(1)
	_say("100", "#bet user0 100")
	_flow.start_race()
	_flow.tick(3.0)
	_finish_marbles([2, 0, 1, 3, 4])
	assert_eq(_flow.state, GameFlow.State.PODIUM)
	assert_eq(_betting.points.get_wins("0"), 1, "scoring sees the viewer as the winner")
	assert_eq(_balance("0"), 1000 + 100)
	assert_eq(_balance("100"), 900 + 200)
	assert_eq(_betting.points.get_balance(""), 1000, "nobody was paid for a cutout")
	var podium_view: PodiumView = _game.find_children("*", "PodiumView", true, false)[0]
	assert_eq(podium_view.find_children("*", "CardboardFish", true, false).size(), 2)


func test_three_viewers_race_without_cutouts() -> void:
	_start_race(3)
	assert_eq(_race.get_marbles().size(), 3)


func test_off_setting_keeps_the_field_to_viewers() -> void:
	_game.settings.cardboard_fish = false
	_start_race(1)
	assert_eq(_race.get_marbles().size(), 1)
