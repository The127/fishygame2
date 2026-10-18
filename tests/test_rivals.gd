extends GutTest
## Rivals: "#rival <name>", and the points for finishing ahead of your rival.

var _rivals: Rivals
var _points: PointsStore


func before_each() -> void:
	_points = PointsStore.new("", 1000)
	_points.set_name("a", "Alice")
	_points.set_name("b", "Bob")
	_points.set_name("c", "Cy")
	_rivals = Rivals.new()
	_rivals.points = _points
	add_child_autofree(_rivals)


func _rival(user_id: String, text: String) -> void:
	var msg := ChatMessage.create(user_id, user_id, _points.get_name(user_id), text)
	var args: PackedStringArray = text.split(" ", false).slice(1)
	_rivals.handle_command(msg, "rival", args)


func _standing(user_id: String, place: int, finished: bool = true) -> Dictionary:
	return {
		"user_id": user_id, "name": _points.get_name(user_id), "place": place, "finished": finished
	}


func test_rival_is_set_by_name() -> void:
	watch_signals(_rivals)
	_rival("a", "#rival @bob")
	assert_eq(_points.rivals.get_rival("a"), "b")
	assert_eq(get_signal_parameters(_rivals, "rival_set", 0)[1], "Bob")


func test_unknown_name_is_rejected() -> void:
	watch_signals(_rivals)
	_rival("a", "#rival Nobody")
	assert_eq(_points.rivals.get_rival("a"), "")
	assert_eq(get_signal_parameters(_rivals, "rival_rejected", 0)[1], "unknown_viewer")


func test_cannot_be_your_own_rival() -> void:
	watch_signals(_rivals)
	_rival("a", "#rival Alice")
	assert_eq(_points.rivals.get_rival("a"), "")
	assert_eq(get_signal_parameters(_rivals, "rival_rejected", 0)[1], "self")


func test_new_rival_replaces_the_old_one() -> void:
	_rival("a", "#rival Bob")
	_rival("a", "#rival Cy")
	assert_eq(_points.rivals.get_rival("a"), "c")


func test_bare_command_reports_the_rival() -> void:
	watch_signals(_rivals)
	_rival("a", "#rival")
	assert_eq(get_signal_parameters(_rivals, "rival_reported", 0)[1], "")
	_rival("a", "#rival Bob")
	_rival("a", "#rival")
	assert_eq(get_signal_parameters(_rivals, "rival_reported", 1)[1], "Bob")


func test_finishing_ahead_of_the_rival_pays_the_reward() -> void:
	_rival("a", "#rival Bob")
	var results: Array[Dictionary] = _rivals.settle([_standing("a", 1), _standing("b", 2)])
	assert_eq(_points.get_balance("a"), 1005)
	assert_eq(_points.get_balance("b"), 1000)
	assert_eq(results.size(), 1)
	assert_eq(results[0]["kind"], "rival")
	assert_eq(results[0]["user_id"], "a")
	assert_eq(results[0]["target"], "Bob")
	assert_eq(results[0]["payout"], 5)
	assert_eq(results[0]["amount"], 0)


func test_finishing_behind_the_rival_pays_nothing() -> void:
	_rival("a", "#rival Bob")
	assert_true(_rivals.settle([_standing("b", 1), _standing("a", 2)]).is_empty())
	assert_eq(_points.get_balance("a"), 1000)


func test_beating_a_rival_who_did_not_finish_pays() -> void:
	_rival("a", "#rival Bob")
	_rivals.settle([_standing("a", 1), _standing("b", 2, false)])
	assert_eq(_points.get_balance("a"), 1005)


func test_neither_finishing_pays_nothing() -> void:
	_rival("a", "#rival Bob")
	_rivals.settle([_standing("b", 1, false), _standing("a", 2, false)])
	assert_eq(_points.get_balance("a"), 1000)


func test_rival_must_be_in_the_race() -> void:
	_rival("a", "#rival Bob")
	assert_true(_rivals.settle([_standing("a", 1), _standing("c", 2)]).is_empty())


func test_rivalry_lasts_across_races() -> void:
	_rival("a", "#rival Bob")
	_rivals.settle([_standing("a", 1), _standing("b", 2)])
	_rivals.settle([_standing("a", 2), _standing("b", 3)])
	assert_eq(_points.get_balance("a"), 1010)


func test_reward_follows_the_setting() -> void:
	_rival("a", "#rival Bob")
	_rivals.reward = 20
	_rivals.settle([_standing("a", 1), _standing("b", 2)])
	assert_eq(_points.get_balance("a"), 1020)
	_rivals.reward = 0
	assert_true(_rivals.settle([_standing("a", 1), _standing("b", 2)]).is_empty())


func test_rivalry_is_saved_with_the_points() -> void:
	var path: String = "user://test_rivals_points.json"
	var store := PointsStore.new(path, 1000)
	store.set_name("b", "Bob")
	_rivals.points = store
	var msg := ChatMessage.create("a", "a", "Alice", "#rival Bob")
	_rivals.handle_command(msg, "rival", PackedStringArray(["Bob"]))
	var reloaded := PointsStore.new(path, 1000)
	reloaded.load_from_disk()
	assert_eq(reloaded.rivals.get_rival("a"), "b")
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(path + suffix)


func test_saved_table_drops_bad_entries() -> void:
	var table := RivalTable.new()
	table.load_dict({"a": "b", "c": "c", "d": 5, "e": ""})
	assert_eq(table.to_dict(), {"a": "b"})
