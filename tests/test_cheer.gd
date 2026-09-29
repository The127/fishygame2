extends GutTest
## Cheer rules: which messages count, caps, and the strength that is requested.

var _cheer: Cheer
var _requests: Array[Array] = []


func before_each() -> void:
	_requests.clear()
	_cheer = Cheer.new()
	add_child_autofree(_cheer)
	_cheer.cheer_requested.connect(
		func(id: int, strength: float) -> void: _requests.append([id, strength])
	)
	_cheer.on_state_changed(GameFlow.State.LOBBY, GameFlow.State.IDLE)
	_cheer.add_contestant(Contestant.create("a", "Alice"))
	_cheer.add_contestant(Contestant.create("b", "Bob"))
	_cheer.on_state_changed(GameFlow.State.RACING, GameFlow.State.COUNTDOWN)


func _msg(user_id: String, text: String, emote_count: int = 1) -> ChatMessage:
	var emotes: Array[Dictionary] = []
	for i: int in emote_count:
		emotes.append({"id": str(i), "text": "Kappa"})
	return ChatMessage.create(user_id, user_id, user_id, text, emotes)


func test_name_plus_emote_cheers_that_fish() -> void:
	assert_true(_cheer.handle_message(_msg("v", "go bob Kappa")))
	assert_eq(_requests, [[1, 1.0]] as Array[Array])


func test_at_mention_case_and_punctuation() -> void:
	assert_true(_cheer.handle_message(_msg("v", "GO @ALICE, Kappa")))
	assert_eq(_requests[0][0], 0)


func test_strength_grows_with_emotes_up_to_the_cap() -> void:
	_cheer.handle_message(_msg("v", "bob", 3))
	_cheer.handle_message(_msg("w", "alice", 50))
	assert_eq(_requests[0][1], 3.0)
	assert_eq(_requests[1][1], float(_cheer.max_emotes))


func test_strength_setting_scales_and_zero_turns_it_off() -> void:
	_cheer.strength_percent = 50
	_cheer.handle_message(_msg("v", "bob", 4))
	assert_eq(_requests[0][1], 2.0)
	_cheer.strength_percent = 0
	assert_false(_cheer.handle_message(_msg("w", "alice")))
	assert_eq(_requests.size(), 1)


func test_ignored_without_emote_name_or_partial_match() -> void:
	assert_false(_cheer.handle_message(_msg("v", "go bob", 0)))
	assert_false(_cheer.handle_message(_msg("v", "go somebody Kappa")))
	assert_false(_cheer.handle_message(_msg("v", "bobby Kappa")))
	assert_false(_cheer.handle_message(_msg("v", "#boost bob Kappa")))
	assert_eq(_requests.size(), 0)


func test_earliest_named_fish_wins() -> void:
	_cheer.handle_message(_msg("v", "bob and alice Kappa"))
	assert_eq(_requests[0][0], 1)


func test_ignored_outside_the_race() -> void:
	_cheer.on_state_changed(GameFlow.State.PODIUM, GameFlow.State.RACING)
	assert_false(_cheer.handle_message(_msg("v", "bob Kappa")))


func test_ignored_after_the_race_finished_signal() -> void:
	_cheer.on_race_finished([] as Array[Dictionary])
	assert_false(_cheer.handle_message(_msg("v", "bob Kappa")))


func test_finished_fish_cannot_be_cheered() -> void:
	_cheer.on_marble_finished(1, 1)
	assert_false(_cheer.handle_message(_msg("v", "bob Kappa")))


func test_viewer_cooldown() -> void:
	assert_true(_cheer.handle_message(_msg("v", "bob Kappa")))
	assert_false(_cheer.handle_message(_msg("v", "alice Kappa")))
	_cheer.tick(_cheer.viewer_cooldown)
	assert_true(_cheer.handle_message(_msg("v", "alice Kappa")))


func test_fish_cooldown_applies_across_viewers() -> void:
	assert_true(_cheer.handle_message(_msg("v", "bob Kappa")))
	assert_false(_cheer.handle_message(_msg("w", "bob Kappa")))
	assert_true(_cheer.handle_message(_msg("w", "alice Kappa")))
	_cheer.tick(_cheer.fish_cooldown)
	assert_true(_cheer.handle_message(_msg("x", "bob Kappa")))


func test_cooldowns_reset_for_a_new_race() -> void:
	_cheer.handle_message(_msg("v", "bob Kappa"))
	_cheer.on_state_changed(GameFlow.State.PODIUM, GameFlow.State.RACING)
	_cheer.on_state_changed(GameFlow.State.RACING, GameFlow.State.COUNTDOWN)
	assert_true(_cheer.handle_message(_msg("v", "bob Kappa")))


func test_cheer_settings_are_clamped() -> void:
	var settings := GameSettings.new()
	settings.set_number("cheer_max_emotes", 0)
	settings.set_number("cheer_strength", 9999)
	assert_eq(settings.cheer_max_emotes, 1)
	assert_eq(settings.cheer_strength, 500)
