extends GameTestBase
## The game reads GameSettings when its scene starts.


func _configure(settings: GameSettings) -> void:
	settings.min_players = 2
	settings.countdown_seconds = 5
	settings.starting_balance = 400
	settings.min_bet = 50
	settings.max_bet = 200
	settings.pick_reward = 25
	settings.boost_cost = 30
	settings.curse_cost = 60
	settings.viewer_cooldown = 9
	settings.fish_lockout = 2
	settings.default_map = "pachinko"
	settings.pad_left = 25
	settings.pad_top = 10
	settings.hazard_frequency = 4


func test_flow_reads_the_settings() -> void:
	assert_eq(_flow.min_players, 2)
	assert_eq(_flow.max_players, 4)
	assert_eq(_flow.countdown_seconds, 5)


func test_betting_reads_the_settings() -> void:
	assert_eq(_betting.min_bet, 50)
	assert_eq(_betting.max_bet, 200)
	assert_eq(_betting.pick_reward, 25)
	assert_eq(_balance("new_viewer"), 400)


func test_chaos_reads_the_settings() -> void:
	assert_eq(_chaos.boost_cost, 30)
	assert_eq(_chaos.curse_cost, 60)
	assert_eq(_chaos.viewer_cooldown, 9.0)
	assert_eq(_chaos.fish_lockout, 2.0)


func test_default_map_is_used_for_the_first_lobby() -> void:
	assert_eq(_game._map_id, "pachinko")


func test_bets_outside_the_limits_are_rejected() -> void:
	_join(2)
	var rejected: Array[String] = []
	_betting.bet_rejected.connect(
		func(_m: ChatMessage, reason: String) -> void: rejected.append(reason)
	)
	_say("0", "#bet User1 10")
	_say("0", "#bet User1 500")
	assert_eq(rejected, ["below_min", "above_max"])
	assert_eq(_balance("0"), 400, "nothing was taken")
	_say("0", "#bet User1 200")
	assert_eq(_balance("0"), 200)


func test_bet_all_is_capped_at_the_max_bet() -> void:
	_join(2)
	_say("0", "#bet User1 all")
	assert_eq(_balance("0"), 200, "400 balance, 200 max bet")


func test_bet_all_below_the_minimum_reads_as_not_enough_points() -> void:
	_join(2)
	_betting.points.set_balance("0", 20)
	var rejected: Array[String] = []
	_betting.bet_rejected.connect(
		func(_m: ChatMessage, reason: String) -> void: rejected.append(reason)
	)
	_say("0", "#bet User1 all")
	assert_eq(rejected, ["insufficient"])


func test_chat_replies_can_be_turned_off() -> void:
	_join(4)
	_say("9", "#join")
	assert_eq(_source.sent.size(), 1, "the lobby is full reply goes out")
	_game.settings.chat_replies = false
	_say("8", "#join")
	assert_eq(_source.sent.size(), 1, "no reply while replies are off")


func test_padding_shrinks_the_camera_and_overlay_area() -> void:
	var camera: RaceCamera = _game.get_node("RaceCamera") as RaceCamera
	assert_eq(camera._play_fraction, Rect2(0.25, 0.1, 0.75, 0.9))
	var overlay: Overlay = _game.get_node("Overlay") as Overlay
	assert_almost_eq(overlay._frame.anchor_left, 0.25, 0.0001)
	assert_almost_eq(overlay._frame.anchor_top, 0.1, 0.0001)
	assert_almost_eq(overlay._frame.anchor_right, 1.0, 0.0001)
	assert_almost_eq(overlay._frame.anchor_bottom, 1.0, 0.0001)


func test_hazards_are_armed_for_a_race_at_the_configured_frequency() -> void:
	_start_race(2)
	var hazard: Hazard = _current_track().get_hazards()[0]
	assert_true(hazard.is_armed())
	assert_false(hazard.get_schedule().is_empty())


func test_hazards_stay_off_when_disabled() -> void:
	_game.settings.hazards_enabled = false
	_start_race(2)
	assert_false(_current_track().get_hazards()[0].is_armed())
