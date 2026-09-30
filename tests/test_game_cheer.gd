extends GameTestBase
## Game scene: emote cheering during a race.


func _configure(settings: GameSettings) -> void:
	settings.cheer_strength = 200
	settings.cheer_viewer_cooldown = 7
	settings.cheer_fish_cooldown = 3
	settings.cheer_max_emotes = 4


func _cheer_say(user_id: String, text: String, emote_count: int = 1) -> void:
	var emotes: Array[Dictionary] = []
	for i: int in emote_count:
		emotes.append({"id": str(i), "text": "Kappa"})
	_source.message_received.emit(
		ChatMessage.create(user_id, "user" + user_id, "User" + user_id, text, emotes)
	)


func test_cheer_reads_the_settings() -> void:
	var cheer: Cheer = _game.get_node("Cheer") as Cheer
	assert_eq(cheer.strength_percent, 200)
	assert_eq(cheer.viewer_cooldown, 7.0)
	assert_eq(cheer.fish_cooldown, 3.0)
	assert_eq(cheer.max_emotes, 4)


func test_cheer_pushes_the_marble_bursts_bubbles_and_costs_nothing() -> void:
	_start_race(2)
	var marble: Marble = _marble(1)
	var before: int = marble.get_child_count()
	var balance_before: int = _balance("0")
	_cheer_say("0", "go User1 Kappa Kappa", 2)
	assert_gt(marble.get_child_count(), before, "cheer adds a burst")
	assert_eq(_balance("0"), balance_before)
	assert_eq(_betting.points.stake_of("0"), 0, "cheering holds no stake")


func test_cheer_is_ignored_in_the_lobby() -> void:
	_join(2)
	var marbles_before: int = _race.get_marbles().size()
	_cheer_say("0", "User1 Kappa")
	assert_eq(_race.get_marbles().size(), marbles_before)


func test_cheer_does_not_touch_other_fish() -> void:
	_start_race(2)
	var other: Marble = _marble(0)
	var children: int = other.get_child_count()
	_cheer_say("0", "User1 Kappa")
	assert_eq(other.get_child_count(), children)


func test_viewer_can_cheer_their_own_fish() -> void:
	_start_race(2)
	var marble: Marble = _marble(0)
	var before: int = marble.get_child_count()
	_cheer_say("0", "go User0 Kappa")
	assert_gt(marble.get_child_count(), before, "own fish can be cheered")
