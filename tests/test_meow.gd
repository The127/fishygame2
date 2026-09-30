extends GutTest
## Meow rules: only the caller's own fish, only while racing, with a viewer cooldown.

var _meow: Meow
var _requests: Array[int] = []


func before_each() -> void:
	_requests.clear()
	_meow = Meow.new()
	add_child_autofree(_meow)
	_meow.meow_requested.connect(func(id: int) -> void: _requests.append(id))
	_meow.on_state_changed(GameFlow.State.LOBBY, GameFlow.State.IDLE)
	_meow.add_contestant(Contestant.create("a", "Alice"))
	_meow.add_contestant(Contestant.create("b", "Bob"))
	_meow.on_state_changed(GameFlow.State.RACING, GameFlow.State.COUNTDOWN)


func _msg(user_id: String) -> ChatMessage:
	return ChatMessage.create(user_id, user_id, user_id, "#meow")


func test_meow_targets_the_callers_own_fish() -> void:
	assert_true(_meow.meow(_msg("b")))
	assert_eq(_requests, [1] as Array[int])


func test_command_handler_only_reacts_to_meow() -> void:
	_meow.handle_command(_msg("a"), "boost", PackedStringArray())
	assert_eq(_requests.size(), 0)
	_meow.handle_command(_msg("a"), "meow", PackedStringArray())
	assert_eq(_requests, [0] as Array[int])


func test_viewer_without_a_fish_is_ignored() -> void:
	assert_false(_meow.meow(_msg("nobody")))
	assert_eq(_requests.size(), 0)


func test_ignored_outside_a_race() -> void:
	_meow.on_state_changed(GameFlow.State.LOBBY, GameFlow.State.RACING)
	assert_false(_meow.meow(_msg("a")))
	_meow.on_state_changed(GameFlow.State.RACING, GameFlow.State.COUNTDOWN)
	_meow.on_race_finished([] as Array[Dictionary])
	assert_false(_meow.meow(_msg("a")))


func test_viewer_cooldown_is_per_viewer() -> void:
	assert_true(_meow.meow(_msg("a")))
	assert_false(_meow.meow(_msg("a")))
	assert_true(_meow.meow(_msg("b")))
	_meow.tick(_meow.viewer_cooldown + 0.1)
	assert_true(_meow.meow(_msg("a")))
	assert_eq(_requests, [0, 1, 0] as Array[int])


func test_cooldown_resets_with_the_next_race() -> void:
	assert_true(_meow.meow(_msg("a")))
	_meow.on_race_finished([] as Array[Dictionary])
	_meow.on_state_changed(GameFlow.State.LOBBY, GameFlow.State.PODIUM)
	_meow.add_contestant(Contestant.create("a", "Alice"))
	_meow.on_state_changed(GameFlow.State.RACING, GameFlow.State.COUNTDOWN)
	assert_true(_meow.meow(_msg("a")))
