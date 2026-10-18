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
	# The race ends with the viewer: cutouts 1, 3 and 4 never finish and stay off the podium.
	assert_eq(podium_view.find_children("*", "CardboardFish", true, false).size(), 1)


func test_three_viewers_race_without_cutouts() -> void:
	_start_race(3)
	assert_eq(_race.get_marbles().size(), 3)


func test_off_setting_keeps_the_field_to_viewers() -> void:
	_game.settings.cardboard_fish = false
	_start_race(1)
	assert_eq(_race.get_marbles().size(), 1)


func test_the_race_ends_when_the_viewer_finishes_without_waiting_for_cutouts() -> void:
	_start_race(1)
	_finish_marbles([0])
	assert_eq(_flow.state, GameFlow.State.PODIUM)
	assert_eq(_betting.points.get_wins("0"), 1)


func test_real_fish_pass_through_cutouts() -> void:
	_start_race(1)
	var viewer: Marble = _marble(0)
	for id: int in range(1, 5):
		assert_true(_marble(id).get_collision_exceptions().has(viewer), "cutout %d" % id)
	assert_false(_marble(1).get_collision_exceptions().has(_marble(2)), "cutouts still bump")


func test_cutouts_leave_treasures_lying() -> void:
	_start_race(1)
	var treasures: RaceTreasures = _race.get("_treasures")
	if treasures.treasures.is_empty():
		pass_test("this map placed no treasure")
		return
	var treasure: Treasure = treasures.treasures[0]
	_marble(0).global_position = treasure.global_position + Vector2(5000.0, 0.0)
	_marble(1).global_position = treasure.global_position
	treasures.collect()
	assert_false(treasure.collected, "a cutout passes over it")
	_marble(0).global_position = treasure.global_position
	treasures.collect()
	assert_true(treasure.collected, "the viewer's fish takes it")
