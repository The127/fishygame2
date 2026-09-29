extends GutTest

var _flow: GameFlow


func before_each() -> void:
	_flow = GameFlow.new()
	_flow.max_players = 3
	add_child_autofree(_flow)


func test_default_lobby_never_auto_starts() -> void:
	var flow := GameFlow.new()
	add_child_autofree(flow)
	assert_eq(flow.lobby_seconds, 0.0)
	flow.open_lobby()
	flow.add_debug_players(1)
	flow.tick(100000.0)
	assert_eq(flow.state, GameFlow.State.LOBBY)


func test_add_debug_players_distinct_and_capped() -> void:
	_flow.open_lobby()
	assert_eq(_flow.add_debug_players(2), 2)
	assert_eq(_flow.add_debug_players(5), 1, "capped at max_players")
	var ids: Dictionary = {}
	for c: Contestant in _flow.get_contestants():
		ids[c.user_id] = true
	assert_eq(ids.size(), 3)


func test_add_debug_players_only_in_lobby() -> void:
	assert_eq(_flow.add_debug_players(1), 0)


func test_debug_names_have_no_spaces() -> void:
	_flow.open_lobby()
	_flow.add_debug_players(2)
	for c: Contestant in _flow.get_contestants():
		assert_false(c.display_name.contains(" "), c.display_name)
