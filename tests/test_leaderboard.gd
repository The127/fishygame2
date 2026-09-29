extends GutTest
## Leaderboard text and panel.


func _rows(count: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for i: int in count:
		rows.append({"user_id": str(i), "name": "N%d" % i, "points": 1000 - i, "wins": i})
	return rows


func test_chat_text_lists_rows_in_order() -> void:
	assert_eq(Leaderboard.chat_text(_rows(3)), "Top 3: 1. N0 1000 | 2. N1 999 | 3. N2 998")


func test_chat_text_when_empty() -> void:
	assert_string_contains(Leaderboard.chat_text([] as Array[Dictionary]), "No scores yet")


func test_panel_shows_rows_and_reports_empty() -> void:
	var panel := LeaderboardPanel.new()
	add_child_autofree(panel)
	assert_false(panel.set_rows([] as Array[Dictionary], [] as Array[Dictionary]))
	assert_true(panel.set_rows(_rows(8), [] as Array[Dictionary]))
	var column: VBoxContainer = panel.get_child(0) as VBoxContainer
	await wait_process_frames(1)
	assert_eq(column.get_child_count(), 1 + LeaderboardPanel.ROWS, "title plus capped rows")
