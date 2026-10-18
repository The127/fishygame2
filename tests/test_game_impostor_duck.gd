extends GameTestBase
## Game scene: the impostor duck races with the fish but is nobody when the points are settled.


func _configure(settings: GameSettings) -> void:
	settings.win_reward = 100
	settings.second_reward = 50


func test_the_duck_lines_up_after_the_fish_and_looks_like_a_duck() -> void:
	_game.forced_duck = true
	_start_race(2)
	assert_eq(_race.get_marbles().size(), 3)
	var duck: Marble = _marble(2)
	assert_true(duck.impostor)
	assert_eq(duck.label_text, ImpostorDuck.NAME)
	assert_false(_marble(0).impostor)


func test_a_winning_duck_is_crowned_but_the_best_fish_is_paid() -> void:
	_game.forced_duck = true
	_join(2)
	_say("100", "#bet user1 100")
	_flow.start_race()
	_flow.tick(3.0)
	var shown: Array = []
	_flow.podium_ready.connect(func(podium: Array[Dictionary]) -> void: shown.append_array(podium))
	_finish_marbles([2, 1, 0])
	assert_eq(_flow.state, GameFlow.State.PODIUM)
	assert_eq(str(shown[0]["user_id"]), "1", "scoring sees user1 as the winner")
	assert_eq(_balance("1"), 1000 + 100, "the best fish gets the win reward")
	assert_eq(_balance("0"), 1000 + 50)
	assert_eq(_balance("100"), 900 + 200, "a bet on the best fish wins")
	assert_eq(_betting.points.get_balance(""), 1000, "nobody was paid for the duck")
	var podium_view: PodiumView = _game.find_children("*", "PodiumView", true, false)[0]
	var fish: Array[Node] = podium_view.find_children("*", "FishVisual", true, false)
	var impostors: int = 0
	for f: FishVisual in fish:
		if f.impostor:
			impostors += 1
			# The winner dances, so its spot on the podium is the dancer's.
			var dancer: FishDance = f.get_parent().get_parent()
			assert_eq(dancer.position.x, podium_view.step_rect(1).get_center().x, "on the top step")
	assert_eq(impostors, 1)


func test_the_duck_never_races_when_turned_off() -> void:
	_game.forced_duck = null
	_game.settings.impostor_duck = false
	_start_race(2)
	assert_eq(_race.get_marbles().size(), 2)


func test_the_duck_always_races_at_a_hundred_percent() -> void:
	_game.forced_duck = null
	_game.settings.impostor_duck = true
	_game.settings.impostor_chance = 100
	_start_race(2)
	assert_eq(_race.get_marbles().size(), 3)
