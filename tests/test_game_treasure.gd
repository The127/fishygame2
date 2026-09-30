extends GameTestBase
## Game scene: treasures pay at the end of the race and show in the result line and #stats.


func _stats() -> ViewerStats:
	return _betting.points.stats


func _treasure_to(id: int, value: int = 25) -> void:
	_race.treasure_collected.emit(id, Treasure.Kind.PEARL, value)


func test_treasures_pay_the_viewer_when_the_race_ends() -> void:
	_start_race(2)
	var before: int = _betting.points.get_balance("0")
	_treasure_to(0)
	_treasure_to(0, 50)
	assert_eq(_betting.points.get_balance("0"), before, "paid at the end, not on pickup")
	_finish_marbles([1, 0])
	assert_eq(_betting.points.get_balance("0"), before + 75)
	assert_eq(_stats().get_counter("0", "treasures"), 2)
	assert_eq(_stats().get_counter("0", "treasure_points"), 75)
	assert_eq(_stats().get_counter("1", "treasures"), 0)


func test_a_stopped_round_pays_no_treasure() -> void:
	_start_race(2)
	var before: int = _betting.points.get_balance("0")
	_treasure_to(0)
	_flow.stop()
	assert_eq(_betting.points.get_balance("0"), before)
	assert_eq(_stats().get_counter("0", "treasures"), 0)


func test_result_line_names_the_treasure_finders() -> void:
	_start_race(2)
	_treasure_to(1, 50)
	_treasure_to(0, 25)
	_finish_marbles([0, 1])
	assert_true(
		_game._haul_text == "" or _game._haul_text.contains("+"), "cleared after the podium"
	)
	assert_eq(
		_game._result_text("A", [] as Array[Dictionary], [], "@b +50, @a +25"),
		"A won. Treasure: @b +50, @a +25"
	)
	assert_eq(
		_game._result_text("A", [] as Array[Dictionary], ["x"], "@b +50"),
		"A won. Treasure: @b +50. DNF: x"
	)


func test_stats_reply_mentions_treasures() -> void:
	_stats().record_treasure("7", 3, 75)
	assert_true(StatsText.chat_text(_betting.points, "7").contains("3 treasures (+75)"))
