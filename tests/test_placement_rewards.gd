extends GutTest
## Podium finishers earn points whether or not they bet.

var _betting: Betting
var _alice: Contestant
var _bob: Contestant
var _cy: Contestant
var _dee: Contestant


func before_each() -> void:
	_betting = Betting.new()
	_betting.points = PointsStore.new("", 1000)
	add_child_autofree(_betting)
	_alice = Contestant.create("a", "Alice")
	_bob = Contestant.create("b", "Bob")
	_cy = Contestant.create("c", "Cy")
	_dee = Contestant.create("d", "Dee")
	_betting.on_state_changed(GameFlow.State.LOBBY, GameFlow.State.IDLE)
	for contestant: Contestant in [_alice, _bob, _cy, _dee]:
		_betting.add_contestant(contestant)


func _entry(place: int, who: Contestant, finished: bool = true) -> Dictionary:
	return {
		"place": place,
		"user_id": who.user_id,
		"name": who.display_name,
		"finished": finished,
		"time": 10.0 + place,
	}


func _podium() -> Array[Dictionary]:
	return [_entry(1, _alice), _entry(2, _bob), _entry(3, _cy)]


func _balance(user_id: String) -> int:
	return _betting.points.get_balance(user_id)


func test_podium_places_are_paid_without_a_bet() -> void:
	_betting.on_podium_ready(_podium())
	assert_eq(_balance("a"), 1100)
	assert_eq(_balance("b"), 1050)
	assert_eq(_balance("c"), 1025)
	assert_eq(_balance("d"), 1000, "off the podium")


func test_placement_is_reported_as_a_payout() -> void:
	watch_signals(_betting)
	_betting.on_podium_ready(_podium())
	var results: Array = get_signal_parameters(_betting, "payouts_settled", 0)[0]
	assert_eq(results.size(), 3)
	assert_eq(results[0]["kind"], "place")
	assert_eq(results[0]["user_id"], "a")
	assert_eq(results[0]["payout"], 100)


func test_placement_is_saved_to_disk() -> void:
	var path: String = "user://test_placement_points.json"
	var store := PointsStore.new(path, 1000)
	_betting.points = store
	_betting.on_podium_ready(_podium())
	var reloaded := PointsStore.new(path, 1000)
	reloaded.load_from_disk()
	assert_eq(reloaded.get_balance("a"), 1100)
	assert_eq(reloaded.get_balance("b"), 1050)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".bak")


func test_placement_adds_to_a_winning_bet() -> void:
	_betting.points.set_balance("v1", 1000)
	var msg := ChatMessage.create("v1", "v1", "V1", "#bet Alice 100")
	_betting.handle_command(msg, "bet", PackedStringArray(["Alice", "100"]))
	_betting.on_podium_ready(_podium())
	assert_eq(_balance("v1"), 900 + 200)
	assert_eq(_balance("a"), 1100)


func test_dnf_and_zero_rewards_pay_nothing() -> void:
	_betting.place_rewards = [0, 50, 25]
	_betting.on_podium_ready([_entry(1, _alice), _entry(2, _bob, false)] as Array[Dictionary])
	assert_eq(_balance("a"), 1000)
	assert_eq(_balance("b"), 1000)


func test_result_line_includes_placement_and_merges_a_viewer() -> void:
	var game: Game = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Game
	var text: String = (
		game
		. _result_text(
			"Alice",
			(
				[
					{"user_id": "a", "name": "Alice", "payout": 100},
					{"user_id": "a", "name": "Alice", "payout": 300},
					{"user_id": "b", "name": "Bob", "payout": 50},
				]
				as Array[Dictionary]
			)
		)
	)
	game.free()
	assert_eq(text, "Alice won. Payouts: @Alice +400, @Bob +50")
