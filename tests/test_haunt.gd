extends GutTest
## The #eddy command: who may send an eddy and when.

var _haunt: Haunt
var _requests: Array[int] = []
var _sent: Array[String] = []
var _rejected: Array[String] = []
## What the fake race answers for each marble id; missing means the fish can send one.
var _blocked: Dictionary = {}


func before_each() -> void:
	_requests.clear()
	_sent.clear()
	_rejected.clear()
	_blocked.clear()
	_haunt = Haunt.new()
	add_child_autofree(_haunt)
	_haunt.blocker = func(id: int) -> String: return String(_blocked.get(id, ""))
	_haunt.eddy_requested.connect(func(id: int) -> void: _requests.append(id))
	_haunt.eddy_sent.connect(
		func(_m: ChatMessage, who: Contestant) -> void: _sent.append(who.display_name)
	)
	_haunt.eddy_rejected.connect(
		func(_m: ChatMessage, reason: String) -> void: _rejected.append(reason)
	)
	_haunt.on_state_changed(GameFlow.State.LOBBY, GameFlow.State.IDLE)
	_haunt.add_contestant(Contestant.create("a", "Alice"))
	_haunt.add_contestant(Contestant.create("b", "Bob"))
	_haunt.on_state_changed(GameFlow.State.RACING, GameFlow.State.COUNTDOWN)


func _msg(user_id: String) -> ChatMessage:
	return ChatMessage.create(user_id, user_id, user_id, "#eddy", [] as Array[Dictionary])


func test_a_viewer_with_a_cut_fish_sends_an_eddy() -> void:
	assert_true(_haunt.send_eddy(_msg("b")))
	assert_eq(_requests, [1] as Array[int])
	assert_eq(_sent, ["Bob"] as Array[String])
	assert_eq(_rejected, [] as Array[String])


func test_the_command_word_is_eddy_and_other_words_do_nothing() -> void:
	_haunt.handle_command(_msg("a"), "boost", PackedStringArray())
	assert_eq(_requests.size(), 0)
	_haunt.handle_command(_msg("a"), "eddy", PackedStringArray())
	assert_eq(_requests, [0] as Array[int])


func test_only_during_a_race() -> void:
	_haunt.on_race_finished([] as Array[Dictionary])
	assert_false(_haunt.send_eddy(_msg("a")))
	assert_eq(_rejected, ["closed"] as Array[String])


func test_a_viewer_without_a_fish_is_turned_down() -> void:
	assert_false(_haunt.send_eddy(_msg("stranger")))
	assert_eq(_rejected, ["no_fish"] as Array[String])


func test_the_race_can_refuse() -> void:
	_blocked[0] = "swimming"
	assert_false(_haunt.send_eddy(_msg("a")))
	_blocked[0] = "full"
	assert_false(_haunt.send_eddy(_msg("a")))
	assert_eq(_rejected, ["swimming", "full"] as Array[String])
	assert_eq(_requests.size(), 0)


func test_a_refused_eddy_costs_no_cooldown() -> void:
	_blocked[0] = "busy"
	_haunt.send_eddy(_msg("a"))
	_blocked.clear()
	assert_true(_haunt.send_eddy(_msg("a")))


func test_cooldown_per_viewer_and_it_runs_out() -> void:
	assert_true(_haunt.send_eddy(_msg("a")))
	assert_false(_haunt.send_eddy(_msg("a")))
	assert_eq(_rejected, ["cooldown"] as Array[String])
	assert_true(_haunt.send_eddy(_msg("b")), "another viewer is not held up")
	_haunt.tick(_haunt.viewer_cooldown + 0.1)
	assert_true(_haunt.send_eddy(_msg("a")))


func test_a_new_race_resets_the_cooldowns() -> void:
	_haunt.send_eddy(_msg("a"))
	_haunt.on_state_changed(GameFlow.State.RACING, GameFlow.State.COUNTDOWN)
	assert_true(_haunt.send_eddy(_msg("a")))
