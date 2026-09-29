extends GutTest
## PointsStore leaderboard data: wins, names, ranking and migration from version 1 files.

const PATH: String = "user://test_points_leaderboard.json"


func after_each() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	for name_text: String in dir.get_files():
		if name_text.begins_with("test_points_leaderboard.json"):
			dir.remove(name_text)


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_wins_and_names_persist() -> void:
	var store := PointsStore.new(PATH, 100)
	store.add_win("1")
	store.add_win("1")
	store.set_name("1", "Ann")
	assert_true(store.save_to_disk())
	var reloaded := PointsStore.new(PATH, 100)
	assert_true(reloaded.load_from_disk())
	assert_eq(reloaded.get_wins("1"), 2)
	assert_eq(reloaded.get_name("1"), "Ann")
	assert_eq(reloaded.get_name("123456"), "Viewer 3456", "unknown viewers never show a raw id")
	assert_eq(reloaded.get_name("42"), "Viewer 42")


func test_version_1_file_migrates_without_losing_balances() -> void:
	_write(PATH, '{"version": 1, "balances": {"1": 700}, "stakes": {"1": 50}}')
	var store := PointsStore.new(PATH, 100)
	assert_true(store.load_from_disk())
	assert_eq(store.get_balance("1"), 700)
	assert_eq(store.stake_of("1"), 50)
	assert_eq(store.get_wins("1"), 0)
	store.add_win("1")
	assert_true(store.save_to_disk())
	var backup := PointsStore.new(PATH + ".bak", 100)
	assert_true(backup.load_from_disk(), "the old file stays as the backup")
	assert_eq(backup.get_balance("1"), 700)
	var reloaded := PointsStore.new(PATH, 100)
	assert_true(reloaded.load_from_disk())
	assert_eq(reloaded.get_balance("1"), 700)
	assert_eq(reloaded.get_wins("1"), 1)


func test_bad_wins_and_names_do_not_cost_balances() -> void:
	_write(PATH, '{"balances": {"1": 5}, "wins": [1], "names": {"1": 7, "2": "  Bo  "}}')
	var store := PointsStore.new(PATH, 100)
	assert_true(store.load_from_disk())
	assert_eq(store.get_balance("1"), 5)
	assert_eq(store.get_wins("1"), 0)
	assert_eq(store.get_name("1"), "Viewer 1")
	assert_eq(store.get_name("2"), "Bo")


func test_top_by_points_orders_and_limits() -> void:
	var store := PointsStore.new("", 100)
	store.set_balance("a", 300)
	store.set_balance("b", 900)
	store.set_balance("c", 300)
	store.set_name("a", "Zed")
	store.set_name("b", "Bob")
	store.set_name("c", "Amy")
	var top: Array[Dictionary] = store.top_by_points(2)
	assert_eq(top.size(), 2)
	assert_eq(top[0]["name"], "Bob")
	assert_eq(top[1]["name"], "Amy", "ties are broken by name")
	assert_eq(store.top_by_points(10).size(), 3)
	assert_eq(store.top_by_points(0).size(), 0)


func test_top_by_wins_skips_viewers_without_wins() -> void:
	var store := PointsStore.new("", 100)
	store.set_balance("a", 5000)
	store.add_win("b")
	store.add_win("c")
	store.add_win("c")
	var top: Array[Dictionary] = store.top_by_wins(5)
	assert_eq(top.size(), 2)
	assert_eq(top[0]["user_id"], "c")
	assert_eq(top[0]["wins"], 2)
	assert_eq(top[1]["user_id"], "b")


func test_winner_without_bets_is_ranked_on_points() -> void:
	var store := PointsStore.new("", 100)
	store.add_win("w")
	var top: Array[Dictionary] = store.top_by_points(5)
	assert_eq(top.size(), 1)
	assert_eq(top[0]["points"], 100)


func test_set_name_reports_changes() -> void:
	var store := PointsStore.new("", 100)
	assert_true(store.set_name("1", "Ann"))
	assert_false(store.set_name("1", " Ann "), "same name is not a change")
	assert_false(store.set_name("1", "   "), "empty names are ignored")
	assert_true(store.set_name("1", "Anna"))
	assert_eq(store.get_name("1"), "Anna")


func test_has_entry_needs_a_balance_or_win() -> void:
	var store := PointsStore.new("", 100)
	assert_false(store.has_entry("1"))
	store.set_balance("1", 5)
	store.add_win("2")
	assert_true(store.has_entry("1"))
	assert_true(store.has_entry("2"))
	store.set_name("3", "Cy")
	assert_false(store.has_entry("3"))


func test_unnamed_viewer_is_listed_with_a_placeholder() -> void:
	var store := PointsStore.new("", 100)
	store.set_balance("987654321", 900)
	var top: Array[Dictionary] = store.top_by_points(5)
	assert_eq(top[0]["name"], "Viewer 4321")
