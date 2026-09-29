extends GutTest

var _betting: Betting
var _chat: Node
var _source: DebugChatSource
var _alice: Contestant
var _bob: Contestant


func before_each() -> void:
	_betting = Betting.new()
	_betting.points = PointsStore.new("", 1000)
	add_child_autofree(_betting)
	_chat = load("res://scripts/chat/chat.gd").new()
	add_child_autofree(_chat)
	_source = DebugChatSource.new()
	_chat.set_source(_source)
	_chat.command_received.connect(_betting.handle_command)
	_alice = Contestant.create("a", "Alice")
	_bob = Contestant.create("b", "Bob")
	_open_round([_alice, _bob])


func _open_round(contestants: Array[Contestant]) -> void:
	_betting.on_state_changed(GameFlow.State.LOBBY, GameFlow.State.IDLE)
	for contestant: Contestant in contestants:
		_betting.add_contestant(contestant)


func _bet(user_id: String, name_text: String, text: String) -> void:
	_source.inject(user_id, name_text, text)


func _podium(winner: Contestant, finished: bool = true) -> Array[Dictionary]:
	return [
		{
			"place": 1,
			"user_id": winner.user_id,
			"name": winner.display_name,
			"finished": finished,
			"time": 10.0,
		}
	]


func _balance(user_id: String) -> int:
	return _betting.points.get_balance(user_id)


func test_bet_takes_points_immediately() -> void:
	watch_signals(_betting)
	_bet("v1", "Viewer", "#bet alice 300")
	assert_eq(_balance("v1"), 700)
	assert_true(_betting.has_bet("v1"))
	assert_signal_emitted(_betting, "bet_placed")
	assert_eq(_betting.total_wagered(), 300)


func test_target_matches_case_insensitive_and_at_sign() -> void:
	_bet("v1", "V1", "#bet @BOB 10")
	_bet("v2", "V2", "#bet bOb 10")
	assert_eq(_betting.total_wagered(), 20)


func test_bet_on_name_with_spaces() -> void:
	_betting.add_contestant(Contestant.create("c", "Big Fish"))
	_bet("v1", "V1", "#bet Big Fish 40")
	_bet("v2", "V2", "#bet @big fish all")
	assert_eq(_betting.total_wagered(), 1040)


func test_bet_all_uses_whole_balance() -> void:
	_bet("v1", "Viewer", "#bet Alice all")
	assert_eq(_balance("v1"), 0)


func test_rejections() -> void:
	watch_signals(_betting)
	_bet("v1", "V", "#bet Alice")
	_bet("v1", "V", "#bet Nobody 10")
	_bet("v1", "V", "#bet Alice 0")
	_bet("v1", "V", "#bet Alice -5")
	_bet("v1", "V", "#bet Alice ten")
	_bet("v1", "V", "#bet Alice 99999999999999999999")
	_bet("v1", "V", "#bet Alice 1001")
	assert_signal_emit_count(_betting, "bet_rejected", 7)
	var reasons: Array = []
	for i: int in 7:
		reasons.append(get_signal_parameters(_betting, "bet_rejected", i)[1])
	assert_eq(
		reasons,
		[
			"usage",
			"unknown_fish",
			"invalid_amount",
			"invalid_amount",
			"invalid_amount",
			"invalid_amount",
			"insufficient",
		]
	)
	assert_eq(_balance("v1"), 1000)
	assert_false(_betting.has_bet("v1"))


func test_bet_all_with_empty_balance_rejected() -> void:
	_betting.points.set_balance("v1", 0)
	watch_signals(_betting)
	_bet("v1", "V", "#bet Alice all")
	assert_signal_emitted_with_parameters(
		_betting,
		"bet_rejected",
		[get_signal_parameters(_betting, "bet_rejected", 0)[0], "invalid_amount"]
	)


func test_one_bet_per_viewer() -> void:
	_bet("v1", "V", "#bet Alice 100")
	watch_signals(_betting)
	_bet("v1", "V", "#bet Bob 100")
	assert_signal_emit_count(_betting, "bet_rejected", 1)
	assert_eq(_balance("v1"), 900)


func test_betting_closed_before_lobby_and_after_start() -> void:
	_betting.on_state_changed(GameFlow.State.RACING, GameFlow.State.COUNTDOWN)
	watch_signals(_betting)
	_bet("v1", "V", "#bet Alice 100")
	assert_signal_emit_count(_betting, "bet_rejected", 1)
	assert_eq(_balance("v1"), 1000)


func test_betting_still_open_during_countdown() -> void:
	_betting.on_state_changed(GameFlow.State.COUNTDOWN, GameFlow.State.LOBBY)
	_bet("v1", "V", "#bet Alice 100")
	assert_true(_betting.has_bet("v1"))


func test_winning_bet_pays_amount_times_racers() -> void:
	_bet("v1", "V1", "#bet Alice 100")
	_bet("v2", "V2", "#bet Bob 100")
	_betting.on_state_changed(GameFlow.State.RACING, GameFlow.State.COUNTDOWN)
	watch_signals(_betting)
	_betting.on_podium_ready(_podium(_alice))
	assert_eq(_balance("v1"), 1100)
	assert_eq(_balance("v2"), 900)
	assert_false(_betting.has_bet("v1"))
	var results: Array = get_signal_parameters(_betting, "payouts_settled", 0)[0]
	assert_eq(results.size(), 2)
	assert_eq(results[0]["payout"], 200)
	assert_eq(results[1]["payout"], 0)


func test_no_finisher_refunds_everyone() -> void:
	_bet("v1", "V1", "#bet Alice 100")
	_betting.on_state_changed(GameFlow.State.RACING, GameFlow.State.COUNTDOWN)
	_betting.on_podium_ready(_podium(_alice, false))
	assert_eq(_balance("v1"), 1000)
	assert_eq(_betting.total_wagered(), 0)


func test_stop_refunds_bets() -> void:
	_bet("v1", "V1", "#bet Alice 100")
	_betting.on_state_changed(GameFlow.State.IDLE, GameFlow.State.LOBBY)
	assert_eq(_balance("v1"), 1000)
	assert_eq(_betting.total_wagered(), 0)


func test_new_lobby_clears_roster() -> void:
	_betting.on_state_changed(GameFlow.State.PODIUM, GameFlow.State.RACING)
	_open_round([_bob])
	watch_signals(_betting)
	_bet("v1", "V1", "#bet Alice 100")
	assert_signal_emit_count(_betting, "bet_rejected", 1)


func test_points_command_reports_balance() -> void:
	watch_signals(_betting)
	_bet("v1", "V1", "#points")
	assert_signal_emitted_with_parameters(
		_betting,
		"balance_reported",
		[get_signal_parameters(_betting, "balance_reported", 0)[0], 1000]
	)


func test_summary() -> void:
	assert_eq(_betting.summary(), "")
	_bet("v1", "V1", "#bet Alice 100")
	_bet("v2", "V2", "#bet Bob 50")
	assert_eq(_betting.summary(), "2 bets, 150 points wagered")


func test_settled_balances_persist() -> void:
	var path: String = "user://test_betting_points.json"
	_betting.points = PointsStore.new(path, 1000)
	_bet("v1", "V1", "#bet Alice 100")
	_betting.on_state_changed(GameFlow.State.RACING, GameFlow.State.COUNTDOWN)
	_betting.on_podium_ready(_podium(_alice))
	var reloaded := PointsStore.new(path, 1000)
	reloaded.load_from_disk()
	assert_eq(reloaded.get_balance("v1"), 1100)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_open_bet_is_refunded_after_reload() -> void:
	var path: String = "user://test_betting_reload.json"
	var live := Betting.new()
	live.points = PointsStore.new(path, 1000)
	add_child_autofree(live)
	live.on_state_changed(GameFlow.State.LOBBY, GameFlow.State.IDLE)
	live.add_contestant(_alice)
	var msg := ChatMessage.new()
	msg.user_id = "v1"
	msg.login = "viewer"
	assert_true(live.place_bet(msg, PackedStringArray(["alice", "300"])))
	assert_eq(live.points.get_balance("v1"), 700)
	# Simulate a browser refresh: a fresh Betting loads the same file.
	var reloaded := Betting.new()
	reloaded.points_path = path
	add_child_autofree(reloaded)
	assert_eq(reloaded.points.get_balance("v1"), 1000)
	assert_eq(reloaded.points.stake_of("v1"), 0)
	for name_text: String in DirAccess.open("user://").get_files():
		if name_text.begins_with("test_betting_reload.json"):
			DirAccess.open("user://").remove(name_text)


func test_settled_bets_leave_no_stake() -> void:
	_bet("v1", "V1", "#bet alice 100")
	_betting.on_podium_ready(_podium(_alice))
	assert_eq(_betting.points.stake_of("v1"), 0)
	assert_eq(_balance("v1"), 1100)
