extends GutTest
## ViewerStats counters and their storage in PointsStore (round trip, migration, bad data).

const PATH: String = "user://test_viewer_stats.json"


func after_each() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	for name_text: String in dir.get_files():
		if name_text.begins_with("test_viewer_stats.json"):
			dir.remove(name_text)


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_unknown_viewer_has_nothing() -> void:
	var stats := ViewerStats.new()
	assert_false(stats.has_stats("1"))
	assert_eq(stats.get_counter("1", "races"), 0)
	assert_eq(stats.get_bet_net("1"), 0)
	assert_eq(stats.get_best_time("1", "zigzag"), 0.0)
	assert_true(stats.get_fastest("1").is_empty())


func test_counters_count() -> void:
	var stats := ViewerStats.new()
	stats.record_race("1")
	stats.record_race("1")
	stats.record_podium("1")
	stats.record_boost("1")
	stats.record_curse("1")
	stats.record_curse("1")
	stats.record_eaten("1")
	assert_eq(stats.get_counter("1", "races"), 2)
	assert_eq(stats.get_counter("1", "podiums"), 1)
	assert_eq(stats.get_counter("1", "boosts"), 1)
	assert_eq(stats.get_counter("1", "curses"), 2)
	assert_eq(stats.get_counter("1", "eaten"), 1)
	assert_eq(stats.get_counter("2", "races"), 0, "other viewers are unaffected")


func test_bets_track_wins_losses_and_net() -> void:
	var stats := ViewerStats.new()
	stats.record_bet("1", 100, 0)
	stats.record_bet("1", 50, 200)
	assert_eq(stats.get_counter("1", "bets_won"), 1)
	assert_eq(stats.get_counter("1", "bets_lost"), 1)
	assert_eq(stats.get_bet_net("1"), 50)


func test_best_time_only_improves_per_map() -> void:
	var stats := ViewerStats.new()
	assert_true(stats.record_finish_time("1", "zigzag", 30.0))
	assert_false(stats.record_finish_time("1", "zigzag", 31.0))
	assert_true(stats.record_finish_time("1", "zigzag", 29.5))
	assert_true(stats.record_finish_time("1", "pachinko", 40.0))
	assert_eq(stats.get_best_time("1", "zigzag"), 29.5)
	assert_eq(stats.get_best_time("1", "pachinko"), 40.0)
	var fastest: Dictionary = stats.get_fastest("1")
	assert_eq(fastest["map_id"], "zigzag")
	assert_eq(fastest["time"], 29.5)


func test_invalid_times_are_ignored() -> void:
	var stats := ViewerStats.new()
	assert_false(stats.record_finish_time("1", "zigzag", 0.0))
	assert_false(stats.record_finish_time("1", "zigzag", -3.0))
	assert_false(stats.record_finish_time("1", "zigzag", INF))
	assert_false(stats.record_finish_time("1", "zigzag", NAN))
	assert_false(stats.record_finish_time("1", "", 10.0))
	assert_false(stats.has_stats("1"))


func test_stats_persist_and_reload() -> void:
	var store := PointsStore.new(PATH, 100)
	store.stats.record_race("1")
	store.stats.record_bet("1", 30, 0)
	store.stats.record_finish_time("1", "zigzag", 21.25)
	store.stats.record_eaten("2")
	assert_true(store.save_to_disk())
	var reloaded := PointsStore.new(PATH, 100)
	assert_true(reloaded.load_from_disk())
	assert_eq(reloaded.stats.get_counter("1", "races"), 1)
	assert_eq(reloaded.stats.get_counter("1", "bets_lost"), 1)
	assert_eq(reloaded.stats.get_bet_net("1"), -30)
	assert_eq(reloaded.stats.get_best_time("1", "zigzag"), 21.25)
	assert_eq(reloaded.stats.get_counter("2", "eaten"), 1)


func test_stats_survive_in_the_backup() -> void:
	var store := PointsStore.new(PATH, 100)
	store.stats.record_race("1")
	store.save_to_disk()
	store.stats.record_race("1")
	store.save_to_disk()
	var backup := PointsStore.new(PATH + ".bak", 100)
	assert_true(backup.load_from_disk())
	assert_eq(backup.stats.get_counter("1", "races"), 1)


func test_version_2_file_migrates_with_empty_stats() -> void:
	_write(
		PATH,
		'{"version": 2, "balances": {"1": 700}, "stakes": {}, "wins": {"1": 3}, "names": {"1": "Ann"}}'
	)
	var store := PointsStore.new(PATH, 100)
	assert_true(store.load_from_disk())
	assert_eq(store.get_balance("1"), 700)
	assert_eq(store.get_wins("1"), 3)
	assert_true(store.stats.is_empty())
	store.stats.record_race("1")
	assert_true(store.save_to_disk())
	var reloaded := PointsStore.new(PATH, 100)
	assert_true(reloaded.load_from_disk())
	assert_eq(reloaded.get_balance("1"), 700)
	assert_eq(reloaded.stats.get_counter("1", "races"), 1)


func test_version_1_file_loads_with_empty_stats() -> void:
	_write(PATH, '{"version": 1, "balances": {"1": 700}, "stakes": {}}')
	var store := PointsStore.new(PATH, 100)
	assert_true(store.load_from_disk())
	assert_eq(store.get_balance("1"), 700)
	assert_true(store.stats.is_empty())


func test_bad_stats_do_not_cost_balances() -> void:
	_write(PATH, '{"balances": {"1": 5}, "stats": [1, 2]}')
	var store := PointsStore.new(PATH, 100)
	assert_true(store.load_from_disk())
	assert_eq(store.get_balance("1"), 5)
	assert_true(store.stats.is_empty())


func test_damaged_rows_lose_only_themselves() -> void:
	_write(
		PATH,
		(
			'{"balances": {"1": 5}, "stats": {"1": {"races": 4, "podiums": "x", "bets_won": -2, '
			+ '"bet_net": 1e30, "best_times": {"zigzag": 12.5, "bad": "no", "neg": -1}}, '
			+ '"2": "junk", "3": {}}}'
		)
	)
	var store := PointsStore.new(PATH, 100)
	assert_true(store.load_from_disk())
	assert_eq(store.get_balance("1"), 5)
	assert_eq(store.stats.get_counter("1", "races"), 4)
	assert_eq(store.stats.get_counter("1", "podiums"), 0)
	assert_eq(store.stats.get_counter("1", "bets_won"), 0)
	assert_eq(store.stats.get_bet_net("1"), ViewerStats.MAX_VALUE)
	assert_eq(store.stats.get_best_time("1", "zigzag"), 12.5)
	assert_eq(store.stats.get_best_time("1", "bad"), 0.0)
	assert_eq(store.stats.get_best_time("1", "neg"), 0.0)
	assert_false(store.stats.has_stats("2"))
	assert_false(store.stats.has_stats("3"))


func test_huge_counter_is_clamped_not_dropped() -> void:
	_write(PATH, '{"balances": {}, "stats": {"1": {"races": 1e300, "bet_net": -1e300}}}')
	var store := PointsStore.new(PATH, 100)
	assert_true(store.load_from_disk())
	assert_eq(store.stats.get_counter("1", "races"), ViewerStats.MAX_VALUE)
	assert_eq(store.stats.get_bet_net("1"), -ViewerStats.MAX_VALUE)


func test_map_limits() -> void:
	var stats := ViewerStats.new()
	assert_false(stats.record_finish_time("1", "x".repeat(ViewerStats.MAX_MAP_ID_LENGTH + 1), 5.0))
	for i: int in ViewerStats.MAX_MAPS:
		assert_true(stats.record_finish_time("1", "map%d" % i, 5.0))
	assert_false(stats.record_finish_time("1", "one_too_many", 5.0))
	assert_true(stats.record_finish_time("1", "map0", 4.0), "known maps can still improve")


func test_reload_replaces_old_stats() -> void:
	var store := PointsStore.new(PATH, 100)
	store.stats.record_race("9")
	store.load_from_disk()
	assert_false(store.stats.has_stats("9"))


func test_find_by_name_ignores_case_and_at_sign() -> void:
	var store := PointsStore.new("", 100)
	store.set_name("7", "Ann")
	store.set_name("3", "Bob")
	assert_eq(store.find_by_name("@ann"), "7")
	assert_eq(store.find_by_name("BOB"), "3")
	assert_eq(store.find_by_name("nobody"), "")
	assert_eq(store.find_by_name("  "), "")


func test_chat_text_summarizes() -> void:
	var store := PointsStore.new("", 100)
	store.set_name("1", "Ann")
	store.add_win("1")
	store.stats.record_race("1")
	store.stats.record_race("1")
	store.stats.record_podium("1")
	store.stats.record_bet("1", 100, 0)
	store.stats.record_boost("1")
	store.stats.record_eaten("1")
	store.stats.record_finish_time("1", "not_a_map", 18.44)
	var text: String = StatsText.chat_text(store, "1")
	assert_string_starts_with(text, "Ann: 2 races, 1 win, 1 podium")
	assert_string_contains(text, "best 18.4s on not_a_map")
	assert_string_contains(text, "bets 0 won, 1 lost (-100)")
	assert_string_contains(text, "1 boost")
	assert_false(text.contains("curse"))
	assert_string_contains(text, "eaten once")


func test_chat_text_for_unknown_viewer() -> void:
	var store := PointsStore.new("", 100)
	assert_string_contains(StatsText.chat_text(store, "55"), "no stats yet")


func test_dnfs_count_and_show_in_the_chat_text() -> void:
	var store := PointsStore.new("", 1000)
	store.set_name("7", "Ann")
	store.stats.record_race("7")
	assert_false(StatsText.chat_text(store, "7").contains("DNF"))
	store.stats.record_dnf("7")
	assert_eq(store.stats.get_counter("7", "dnfs"), 1)
	assert_string_contains(StatsText.chat_text(store, "7"), "1 DNF")
	var reloaded := ViewerStats.new()
	reloaded.load_dict(store.stats.to_dict())
	assert_eq(reloaded.get_counter("7", "dnfs"), 1)
