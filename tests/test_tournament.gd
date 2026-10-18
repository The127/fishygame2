extends GutTest
## Tournament scoring: points add up per racer and the final podium earns a bonus.


func test_round_counts() -> void:
	assert_true(Tournament.is_valid_round_count(2))
	assert_true(Tournament.is_valid_round_count(3))
	assert_true(Tournament.is_valid_round_count(5))
	assert_false(Tournament.is_valid_round_count(4))
	assert_false(Tournament.is_valid_round_count(1))


func test_maps_play_in_order_with_repeats() -> void:
	var t := Tournament.new(["zigzag", "pachinko", "zigzag"])
	assert_eq(t.current_map(), "zigzag")
	assert_eq(t.round_number(), 1)
	t.finish_round()
	assert_eq(t.current_map(), "pachinko")
	t.finish_round()
	assert_eq(t.current_map(), "zigzag")
	assert_eq(t.round_number(), 3)
	assert_false(t.is_finished())
	t.finish_round()
	assert_true(t.is_finished())
	assert_eq(t.round_number(), 3, "stays on the last round")


func test_points_add_up_and_rank_best_first() -> void:
	var t := Tournament.new(["zigzag", "zigzag"])
	t.add_points("a", "Alice", 100)
	t.add_points("b", "Bob", 50)
	t.add_points("b", "Bob", 100)
	t.add_racer("c", "Cleo")
	var rows: Array[Dictionary] = t.standings()
	assert_eq(rows.size(), 3)
	assert_eq(rows[0]["user_id"], "b")
	assert_eq(rows[0]["points"], 150)
	assert_eq(rows[0]["place"], 1)
	assert_eq(rows[1]["user_id"], "a")
	assert_eq(rows[2]["user_id"], "c")
	assert_eq(rows[2]["points"], 0)
	assert_eq(t.standings_text(2), "@Bob 150, @Alice 100")


func test_ties_go_to_whoever_entered_first() -> void:
	var t := Tournament.new(["zigzag", "zigzag"])
	t.add_racer("late", "Late")
	t.add_points("early", "Early", 50)
	t.add_points("late", "Late", 50)
	assert_eq(t.standings()[0]["user_id"], "late")


func test_podium_bonus_is_three_times_the_placement_reward() -> void:
	var t := Tournament.new(["zigzag", "zigzag"])
	t.add_points("a", "A", 300)
	t.add_points("b", "B", 200)
	t.add_points("c", "C", 100)
	t.add_points("d", "D", 50)
	var podium: Array[Dictionary] = t.podium_bonuses([100, 50, 25])
	assert_eq(podium.size(), 3)
	assert_eq(podium[0]["bonus"], 300)
	assert_eq(podium[1]["bonus"], 150)
	assert_eq(podium[2]["bonus"], 75)
	assert_eq(podium[2]["user_id"], "c")


func test_no_bonus_without_points_or_reward() -> void:
	var t := Tournament.new(["zigzag", "zigzag"])
	t.add_points("a", "A", 100)
	t.add_racer("b", "B")
	var podium: Array[Dictionary] = t.podium_bonuses([100, 50, 25])
	assert_eq(podium.size(), 1, "a racer without points gets no bonus")
	assert_eq(t.podium_bonuses([0, 50, 25]).size(), 0, "a zero reward pays nothing")
